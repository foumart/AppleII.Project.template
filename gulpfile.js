const { src, dest, series } = require('gulp');
const gulp = require('gulp');
const browserSync = require('browser-sync').create();
const del = require('del');
const argv = require('yargs').argv;
const package = require('./package.json');
const exec = require('child_process').exec;
const fs = require("fs");

// the following data is taken directly from package.json
const title = package.name;
const id_name = `${title.replace(/\s/g, '')}_${getDateString(true)}`;
const version = package.version;

// data provided via additional params. "dir" sets the output directory
const dir = argv.dir || 'public';
const tmp = 'tmp';
const tmpdrive = 'tmpdrive';
const test = argv.test != undefined ? true : false;
const debug = argv.debug != undefined ? true : false;
const verbose = argv.verbose != undefined ? true : false;
const address = "6000";// default address (in HEX) at where to load binary files

const appleCommander = "C:/Standalone/AppleWin/ac.jar";
//const appleWin = "C:/Standalone/AppleWin/AppleWin.exe";// used externally
const asmgen = "asmgen.py";
const merlin = "C:/Standalone/AppleWin/Merlin32.exe";
const retroassembler = "C:/Standalone/AppleWin/retroassembler/retroassembler.exe";


// temporary vars used during build
const bas = [];// holds bas file names found in src/
const bin = [];// holds bin file names found in src/
const drv = [];// holds bin file names found in src/
const asm = [];// holds asm file names precompiled from assets/
const txt = [];// holds txt file names found in src/
const bascallbacks = [];// holds if the corresponding basic file compilation process is complete or not
const bincallbacks = [];// holds if the corresponding binary file compilation process is complete or not
const drvcallbacks = [];// holds if the corresponding driver file compilation process is complete or not
const asmcallbacks = [];// holds if the corresponding asm files compilation process is complete or not
const txtcallbacks = [];// holds if the corresponding text file compilation process is complete or not
let currentfile;
let allfiles;

// ======
// TASKS:
// ======

// Copy the Apple II web emulator
function app(cb) {
	var emulatorPath = 'emulator/';
	fs.access(emulatorPath, fs.constants.F_OK, (err) => {
		if (err) {
			throw new Error("Please copy the emulator!");
		} else {
			src('emulator/**/*', { allowEmpty: true })
				.pipe(dest(dir+'/'))
				.on("end", cb)
		}
	});
}

// Copy the source dsk image (name should be the same as project name + .DSK)
function dsk(cb) {
	src(`dsk/${title}.dsk`, { allowEmpty: true })
		.pipe(dest(dir+'/json/disks/'))
		.on("end", cb)
}

// Copy the source folder to allow manipulation in place and easier cleaning afterwards
function raw(cb) {
	if (!fs.existsSync(`${dir}/${tmpdrive}/`)) {
		fs.mkdirSync(`${dir}/${tmpdrive}/`, { recursive: true });
	}
	src(`src/*`, { allowEmpty: true })
		.pipe(dest(`${dir}/${tmp}/`))
		.on("end", cb)
}

function assets(cb) {
	const files = fs.readdirSync('assets');
	currentfile = 0;
	allfiles = files.length - 1;
	if (allfiles >= 0) compileDriverFile(files, cb);
	else cb();
}

function compileDriverFile(files, cb) {
	let file = files[currentfile]; console.log("assets/->"+file);
	let name = file.substring(0, file.length-4);
	asm.push(name);
	asmcallbacks.push(false);
	executePython(`${asmgen} -v -a merlin -p 65C02 -o ${dir}/${tmpdrive}/${name} assets/${file}`, e => {
		executePython(`${asmgen} -v -a merlin -p 65C02 assets/${file}`, (pythonoutput) => {
			asmcallbacks[bin.indexOf(file)] = true;
			let add = `param_x = $10
param_y = $10
scratch_addr = $6000
scratch_col = $20
`;
			let post = `
	PUT ${name}-hgrcols-7x2.S
	PUT ${name}-hgrrows.S
`;
			fs.writeFile(`${dir}/${tmpdrive}/${name}.s`, add + pythonoutput + post, function(err) {
				if (err) throw err;
				cb();
			});
		});
	});
}

// Copy any BIN files if needed (images automation?), currently we supply the files with prepopulated source DSK.
/*function bin(cb) {
	executeJava(`java -jar ${appleCommander} -p public/json/disks/GRIDLOCK.dsk TITLE bin 0x2000 < bin/title.A2FC`, () => {
		executeJava(`java -jar ${appleCommander} -p public/json/disks/GRIDLOCK.dsk MOON bin 0x2000 < bin/moon.A2FC`, cb);
	});
}*/

function drivers(cb) {
	if (!asm.length) {
		return cb();
	}
	let _nm = `${asm[0]}.s`;
	drv.push(_nm);
	drvcallbacks.push(false);
	currentfile = 0;
	allfiles = 0;
	compileS(`${dir}/${tmpdrive}/`, _nm, (_name, _address, _dir, _file) => {
		console.log(`Compiled ASSEMBLY driver: ${_name} at $${_address} from ${_dir}${_file}`);
		executeJava(`java -jar ${appleCommander} -p ${_dir==""?"public":dir}/json/disks/${title}.dsk ${_name} bin 0x${_address} < ${_dir}${_name}`, e => {
			drvcallbacks[drv.indexOf(_file)] = true;
			if (checkCompilation()) cb();
			else {
				cb();
			}
		});
	});
}

// Compile all files provided in src/ folder (.bas, .s, .asm)
// Assembly files should be Merlin 32 compatible
function files(cb) {
	const files = fs.readdirSync(`${dir}/${tmp}/`);
	currentfile = 0;
	allfiles = files.length - 1;
	readFile(files, cb);
}

function readFile(files, cb) {
	let file = files[currentfile];//console.log(`${dir}/${tmp}/${file}`);
	let name = file.substring(0, file.length-4).toUpperCase();
	if (file.toLowerCase().indexOf('.bas') > -1) {
		// Compile a basic text file (.bas) into the tokenized BAS format and insert into the DSK
		// =======================================================================================

		// Remove all REM comments in the basic file
		let basic = fs.readFileSync(`${dir}/${tmp}/${file}`, 'utf8');
		let regex = /^(?:\d+\s+)?REM.*|(:\s*)?REM.*|^\d+\s*$/gm;
		basic = "0 REM " + title + " by Noncho Savov\r\n" + basic.replace(regex, ""); // remove REM comments
		// Overwrite the file in raw/
		fs.writeFile(`${dir}/${tmp}/${file}`, basic, function(err) {
			if (err) throw err;
		});

		bas.push(file);
		bascallbacks.push(false);
		executeJava(`java -jar ${appleCommander} -bas public/json/disks/${title}.dsk ${name} bas 0x800 < ${dir}/${tmp}/${file}`, e => {
			console.log(`Compiled BASIC file: ${name} at $800 from ${dir}/${tmp}/${file}`);
			bascallbacks[bas.indexOf(file)] = true;
			if (checkCompilation()) cb();
			else {
				if (currentfile ++>= allfiles) cb();
				else readFile(files, cb);
			}
		});
	} else if (file.toLowerCase().indexOf('.s') > -1) {
		// Compile an assembly source text file (.s) into a BIN format with Merin 32 and insert into the DSK
		// ==================================================================================================
		bin.push(file);
		bincallbacks.push(false);
		compileS(`${dir}/${tmp}/`, file, (_name, _address, _dir, _file) => {
			console.log(`Compiled ASSEMBLY SOURCE file: ${_name} at $${_address} from ${_dir}${_file}`);
			executeJava(`java -jar ${appleCommander} -p ${_dir==""?"public":dir}/json/disks/${title}.dsk ${_name} bin 0x${_address} < ${_dir}${_name}`, e => {
				//console.log(`Transferred BINARY file: ${name} to be loaded at $${_address}`);
				bincallbacks[bin.indexOf(_file)] = true;
				if (checkCompilation()) cb();
				else {
					if (currentfile ++>= allfiles) cb();
					else readFile(files, cb);
				}
			});
		});
	} else if (file.toLowerCase().indexOf('.asm') > -1) {
		// Compile an assembly raw text file (.asm) into a BIN format with Retro Assembler and insert into the DSK
		// ========================================================================================================
		bin.push(file);
		bincallbacks.push(false);
		// Use Retro Assembler to compile
		const { spawn } = require('child_process');
		const retroAsmProcess = spawn(retroassembler, [`${dir}/${tmp}/${file}`, `${dir}/${tmp}/${name}.bin`]);
		if (debug) retroAsmProcess.stdout.on('data', (data) => console.log(data));
		retroAsmProcess.stderr.on('data', (data) => { console.error(`Retro Assembler error: ${data}`); });
		retroAsmProcess.on('close', (code) => {
			console.log(`Compiled ASSEMBLY file: ${name} at $${address} from ${dir}/${tmp}/${file}`);
			executeJava(`java -jar ${appleCommander} -p ${dir}/json/disks/${title}.dsk ${name} bin 0x${_address} < ${dir}/${tmp}/${name}.bin`, e => {
				bincallbacks[bin.indexOf(file)] = true;
				if (checkCompilation()) cb();
				else {
					if (currentfile ++>= allfiles) cb();
					else readFile(files, cb);
				}
			});
		});
	} else if (file.toLowerCase().indexOf('.txt') > -1) {
		// Compile a pure text file (.txt) and insert into the DSK
		// ========================================================
		txt.push(file);
		txtcallbacks.push(false);
		executeJava(`java -jar ${appleCommander} -ptx ${dir}/json/disks/${title}.dsk ${name} txt < ${dir}/${tmp}/${name}.txt`, e => {
			console.log(`Copied TXT file: ${name} from ${dir}/${tmp}/${file}`);
			txtcallbacks[txt.indexOf(file)] = true;
			if (checkCompilation()) cb();
			else {
				if (currentfile ++>= allfiles) cb();
				else readFile(files, cb);
			}
		});
	} else {
		console.log("File " + file + " format unknown! (" + file.substring(file.length-4) + ") ");
	}
}

function compileS(dir, file, cb) {
	let name = file.substring(0, file.length-2).toUpperCase();
	let _address;
	// Determine the starting address of the binary data
	fs.readFile(dir + file, 'utf8', (err, data) => {
		if (err) {
			console.error(err);
			return;
		}
		var index = data.indexOf("ORG");// the ASM command that states the beginning address of a machine language program
		if (index == -1) {
			_address = address;
		} else {// Getting the address after ORG nomatter how much spaces or tabs there might be
			_address = "";
			while (_address.length < 4) {
				if (parseInt(data[index + 1], 16) || parseInt(data[index + 1], 16) == 0) _address += data[index + 1];
				index ++;
			}
		}

		// Use Merlin 32 to compile
		const execFile = require('child_process').execFile;
		const merlinProcess = execFile(merlin, ['-V', '/', `${dir}${file}`, ]);
		if (debug) merlinProcess.stdout.on('data', (data) => console.log(data));
		merlinProcess.stderr.on('data', (data) => { console.error(`Merlin 32 error: ${data}`); });
		merlinProcess.on('close', (code) => {
			cb(name, _address, dir, file);
		});

		/*const execFile = require('child_process').execFile;
		const cl65Process = execFile(cl65, ['-t', 'apple2enh', `public/raw/${file}`]);
		//const cl65Process = execFile(cl65, ['-C', 'apple2enh.cfg', `public/raw/${file}`]);
		if (debug) cl65Process.stdout.on('data', (data) => console.log(data));
		cl65Process.stderr.on('data', (data) => { console.error(`cl65 error: ${data}`); });
		cl65Process.on('close', (code) => {
			console.log(`Compiled BINARY file: ${name} at $${_address} from public/raw/${file}`);
			executeJava(`java -jar ${appleCommander} -p public/json/disks/${title}.dsk ${name} bin 0x${_address} < public/raw/${name}`, e => {
				//console.log(`Transferred BINARY file: ${name} to be loaded at $${_address}`);
				bincallbacks[bin.indexOf(file)] = true;
				if (checkCompilation()) cb();
				else {
					if (currentfile ++>= allfiles) cb();
					else readFile(files, cb);
				}
			});
		});*/

	});
}

// When all src files are compiled we delete the temporary folder
function checkCompilation() {
	var check = true;
	if (currentfile < allfiles) return false;
	for (var i = 0; i < bascallbacks.length; i ++) {
		if (!bascallbacks[i]) check = false;
	}
	for (var i = 0; i < bincallbacks.length; i ++) {
		if (!bincallbacks[i]) check = false;
	}
	for (var i = 0; i < asmcallbacks.length; i ++) {
		if (!asmcallbacks[i]) check = false;
	}
	for (var i = 0; i < drvcallbacks.length; i ++) {
		if (!drvcallbacks[i]) check = false;
	}
	for (var i = 0; i < txtcallbacks.length; i ++) {
		if (!txtcallbacks[i]) check = false;
	}
	if (check) {
		//console.log(`""`);
		console.log(`Compilation complete. http://localhost:8080/json/disks/${title}.dsk`);
		//console.log(`""`);
		del(`${dir}/${tmp}/`, {force:true});
		del(`${dir}/${tmpdrive}/`, {force:true});
	}
	return check;
}

// Do we want to test on AppleWin? for example the Mouse interface does not work on the web emulator.
/*function appleWin(cb) {
	// run AppleWin directly (temporary solution)
	const { spawn } = require('child_process');
	const path = require('path');
	const appleWinProcess = spawn(appleWin, [`public/json/disks/${title}.dsk`]);
	// Optional: Handle events from the spawned process
	appleWinProcess.stdout.on('data', (data) => console.log(`stdout: ${data}`));
	appleWinProcess.stderr.on('data', (data) => console.error(`stderr: ${data}`));
	appleWinProcess.on('close', (code) => console.log(`child process exited with code ${code}`));
}*/

// execute scripts'n stuff
function executeJava(cmdCode, cb) {
	exec(cmdCode,
		function (error, stdout, stderr){//console.log(JSON.stringify(stdout));
			if (verbose && stdout) console.log(cmdCode + ' stdout: ' + JSON.stringify(stdout));
			if (verbose && stderr) console.log(cmdCode + ' stderr: ' + stderr);
			if (error !== null) console.log('executeJava error: ' + error);
			else cb();
		}
	);
}

function executePython(cmdCode, cb) {
	exec(`python ${cmdCode}`,
		function (error, stdout, stderr){
			if (verbose && stdout) console.log(cmdCode + ' stdout: ' + JSON.stringify(stdout));
			if (verbose && stderr) console.log(cmdCode + ' stderr: ' + stderr);
			if (error !== null) console.log('executePython error: ' + error);
			else cb(stdout);
		}
	);
}

// Delete the public folder generated with each build
function clean(callback) {
	del(dir+'/**/*', {force:true});
	callback();
}

// Watch for changes in the source folder
function watch(callback) {
	browserSync.init({
		server: './'+dir,
		startPath: `#json/disks/${title}.dsk`,
		ui: false,
		port: 8080
	});
	
	gulp.watch('./src').on('change', () => {
		exports.sync();
	});

	// should we watch for changes elsewhere, for example if we modify an image
	/*gulp.watch('./bin').on('change', () => {
		exports.sync();
	});*/

	callback();
};

// Reload the browser sync instance, or run a new server with live reload
function reload(callback) {
	if (!browserSync.active) {
		watch(callback);
	} else {
		browserSync.reload();
		callback();
	}
}

// Helper function for timestamp and naming
function getDateString(shorter) {
	const date = new Date();
	const year = date.getFullYear();
	const month = `${date.getMonth() + 1}`.padStart(2, '0');
	const day =`${date.getDate()}`.padStart(2, '0');
	if (shorter) return `${year}${month}${day}`;
	const signiture =`${date.getHours()}`.padStart(2, '0')+`${date.getMinutes()}`.padStart(2, '0')+`${date.getSeconds()}`.padStart(2, '0');
	return `${year}${month}${day}_${signiture}`;
}

// Exports
exports.default = series(clean, app, dsk, raw, assets, drivers, files, watch);
exports.sync = series(clean, app, dsk, raw, assets, drivers, files, reload);

/*
   Gulpfile by Noncho Savov
   https://www.FoumartGames.com
*/
