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
const test = argv.test != undefined ? true : false;
const debug = argv.debug != undefined ? true : false;
const address = "6000";// default address (in HEX) at where to load binary files

const appleCommander = "C:/Standalone/AppleWin/ac.jar";
//const appleWin = "C:/Standalone/AppleWin/AppleWin.exe";// used externally
const merlin = "C:/Standalone/AppleWin/Merlin32.exe";
const retroassembler = "C:/Standalone/AppleWin/retroassembler/retroassembler.exe";


// temporary vars used during build
const bas = [];// holds bas file names found in src/
const bin = [];// holds bin file names found in src/
const txt = [];// holds txt file names found in src/
const bascallbacks = [];// holds if the corresponding basic file compilation process is complete or not
const bincallbacks = [];// holds if the corresponding binary file compilation process is complete or not
const txtcallbacks = [];// holds if the corresponding text file compilation process is complete or not
let currentfile;
let allfiles;

// ======
// TASKS:
// ======

// Copy the Apple II js web emulator
async function emu() {
	const emulatorPath = 'emulator/';
	await new Promise((resolve, reject) => {
		fs.access(emulatorPath, fs.constants.F_OK, (err) => {
			if (err) {
				reject(new Error("Please copy the emulator!"));
			} else {
				src('emulator/**/*', { allowEmpty: true })
					.pipe(dest(dir+'/'))
					.on("end", resolve)
			}
		});
	});
}

// Copy the source dsk image (name should be the same as project name + .DSK)
function dsk(cb) {
	return src(`dsk/${title}.dsk`, { allowEmpty: true })
		.pipe(dest('public/json/disks/'))
		.on("end", cb)
}

// Copy the source folder to allow manipulation in place and easier cleaning afterwards
function copy(cb) {
	return src(`src/*`, { allowEmpty: true })
		.pipe(dest('public/tmp/'))
		.on("end", cb)
}

async function empty(callback) {
	await del(`public/tmp`, { force: true });
	callback();
}

// Copy any BIN files if needed (images automation?), currently we supply the files with prepopulated source DSK.
/*function bin(cb) {
	executeJava(`java -jar ${appleCommander} -p public/json/disks/GRIDLOCK.dsk TITLE bin 0x2000 < bin/title.A2FC`, () => {
		executeJava(`java -jar ${appleCommander} -p public/json/disks/GRIDLOCK.dsk MOON bin 0x2000 < bin/moon.A2FC`, cb);
	});
}*/

// Compile all files in src/ folder (.bas, .s, .asm)
async function files() {
	const files = await fs.promises.readdir('public/tmp/');
	currentfile = 0;
	allfiles = files.length - 1;
	await readFile(files);
}

async function readFile(files) {
	let file = files[currentfile];
	console.log("->" + file);
	let name = file.substring(0, file.length - 4).toUpperCase();
	if (file.toLowerCase().indexOf('.bas') > -1) {
		// Compile a basic text file (.bas) into the tokenized BAS format and insert into the DSK
		// =======================================================================================

		// Remove all REM comments in the basic file
		let basic = await fs.promises.readFile("public/tmp/" + file, 'utf8');
		let regex = /^(?:\d+\s+)?REM.*|(:\s*)?REM.*|^\d+\s*$/gm;
		basic = "0 REM " + title + " by Noncho Savov\r\n" + basic.replace(regex, ""); // remove REM comments
		// Overwrite the file in tmp/
		await fs.promises.writeFile("public/tmp/" + file, basic);

		bas.push(file);
		bascallbacks.push(false);
		await new Promise((resolve) => {
			executeJava(`java -jar ${appleCommander} -bas public/json/disks/${title}.dsk ${name} bas 0x800 < public/tmp/${file}`,
				() => {
					console.log(`Compiled BASIC file: ${name} at $800 from public/tmp/${file}`);
					bascallbacks[bas.indexOf(file)] = true;
					resolve();
				});
		});
		if (checkCompilation()) return;
		if (currentfile++ >= allfiles) return;
		return await readFile(files);
	}
	if (file.toLowerCase().indexOf('.s') > -1) {
		// Compile an assembly source text file (.s) into a BIN format with Merlin 32 and insert into the DSK
		// ==================================================================================================
		name = file.substring(0, file.length - 2).toUpperCase();
		// Determine the starting address of the binary data
		let data = await fs.promises.readFile("public/tmp/" + file, 'utf8');
		let _address = "";
		var index = data.indexOf("ORG");
		if (index == -1) {
			console.log(`Skipping fragment file: ${file}`);
			if (currentfile++ >= allfiles) return;
			return await readFile(files);
		} else {
			bin.push(file);
			bincallbacks.push(false);
			_address = "";
			while (_address.length < 4) {
				if (parseInt(data[index + 1], 16) || parseInt(data[index + 1], 16) == 0) _address += data[index + 1];
				index++;
			}
		}
		const execFile = require('child_process').execFile;
		await new Promise((resolve) => {
			const merlinProcess = execFile(merlin, ['-V', '/', `public/tmp/${file}`]);
			if (debug) merlinProcess.stdout.on('data', (data) => console.log(data));
			merlinProcess.stdout.on('data', (data) => {
				console.log(`stdout: ${data}`);
			});
			merlinProcess.stderr.on('data', (data) => { console.error(`Merlin 32 error: ${data}`); });
			merlinProcess.on('close', (code) => {
				console.log(`Compiled BINARY file: ${name} at $${_address} from public/tmp/${file}`);
				executeJava(`java -jar ${appleCommander} -p public/json/disks/${title}.dsk ${name} bin 0x${_address} < public/tmp/${name}`,
					() => {
						bincallbacks[bin.indexOf(file)] = true;
						resolve();
					});
			});
			merlinProcess.on('exit', (code, signal) => {
				if (code !== 0) {
					console.error(`Merlin32 exited with code ${code} and signal ${signal}`);
				}
			});
		});
		if (checkCompilation()) return;
		if (currentfile++ >= allfiles) return;
		return await readFile(files);
	}
	if (file.toLowerCase().indexOf('.asm') > -1) {
		// Compile an assembly raw text file (.asm) into a BIN format with Retro Assembler and insert into the DSK
		// ========================================================================================================
		bin.push(file);
		bincallbacks.push(false);
		const { spawn } = require('child_process');
		await new Promise((resolve) => {
			const retroAsmProcess = spawn(retroassembler, [`public/tmp/${file}`, `public/tmp/${name}.bin`]);
			if (debug) retroAsmProcess.stdout.on('data', (data) => console.log(data));
			retroAsmProcess.stderr.on('data', (data) => { console.error(`Retro Assembler error: ${data}`); });
			retroAsmProcess.on('close', (code) => {
				console.log(`Compiled BINARY file: ${name} at $${address} from public/tmp/${file}`);
				executeJava(`java -jar ${appleCommander} -p public/json/disks/${title}.dsk ${name} bin 0x${_address} < public/tmp/${name}.bin`,
					() => {
						bincallbacks[bin.indexOf(file)] = true;
						resolve();
					});
			});
		});
		if (checkCompilation()) return;
		if (currentfile++ >= allfiles) return;
		return await readFile(files);
	}
	if (file.toLowerCase().indexOf('.txt') > -1) {
		// Compile a pure text file (.txt) and insert into the DSK
		// ========================================================
		txt.push(file);
		txtcallbacks.push(false);
		await new Promise((resolve) => {
			executeJava(`java -jar ${appleCommander} -ptx public/json/disks/${title}.dsk ${name} txt < public/tmp/${name}.txt`,
				() => {
					console.log(`Copied TXT file: ${name} from public/tmp/${file}`);
					txtcallbacks[txt.indexOf(file)] = true;
					resolve();
				});
		});
		if (checkCompilation()) return;
		if (currentfile++ >= allfiles) return;
		return await readFile(files);
	}
	console.log("File " + file + " format unknown! (" + file.substring(file.length - 4) + ") ");
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
	for (var i = 0; i < txtcallbacks.length; i ++) {
		if (!txtcallbacks[i]) check = false;
	}
	if (check) {
		//console.log(`""`);
		console.log(`Compilation complete. http://localhost:8080/json/disks/${title}.dsk`);
		//console.log(`""`);
		//del(`public/tmp`, {force:true});
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
			if (stdout) console.log(cmdCode + ' stdout: ' + JSON.stringify(stdout));
			if (stderr) console.log(cmdCode + ' stderr: ' + stderr);
			if (error !== null) console.log('exec error: ' + error); else cb();
		}
	);
}

// Delete the public folder generated with each build
function clean(callback) {
	del(dir+'/**/*', { force: true });
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
exports.sync = series(dsk, empty, copy, files, reload);//clean, app, 
exports.default = series(clean, emu, exports.sync);//, watch

/*
   Gulpfile by Noncho Savov
   https://www.FoumartGames.com
*/
