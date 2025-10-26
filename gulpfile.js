const { src, dest, series } = require('gulp');
const gulp = require('gulp');
const browserSync = require('browser-sync').create();
const path = require('path');
const del = require('del');
const fs = require("fs-extra");
const exec = require('child_process').exec;
const execFile = require('child_process').execFile;
const { spawn } = require('child_process');
const argv = require('yargs').argv;
const package = require('./package.json');

// the following data is taken directly from package.json
const title = package.name;
const version = package.version;
const author = package.author.name

// data provided via additional params. "dir" sets the output directory
const dir = argv.dir || 'public';
const debug = !!argv.debug;

const appleWin = "C:/Standalone/AppleWin/Applewin.exe";
const appleCommander = "C:/Standalone/AppleWin/ac.jar";
const merlin = "C:/Standalone/AppleWin/Merlin32.exe";

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
			if (err) return reject(new Error("Please copy the emulator!"));

			src('emulator/**/*', { allowEmpty: true, encoding: false })
				.pipe(dest(dir))
				.on('end', resolve)
				.on('error', reject);
		});
	});
}

// Copy the source dsk image (name should be the same as project name + .dsk)
async function dsk() {
	await fs.copy(`dsk/${title}.dsk`, `public/json/disks/${title}.dsk`, { overwrite: true });
}

// Copy the source folder to allow manipulation in place and easier cleaning afterwards
function copy(cb) {
	return src(`src/*`, { allowEmpty: true })
		.pipe(dest('public/tmp/'))
		.on("end", cb);
}

async function empty(callback) {
	await del(`public/tmp`, { force: true });
	callback();
}

// Copy any BIN files if needed (images automation?), currently we supply the files with prepopulated source DSK.
/*function bin(cb) {
	await executeJavaAsync(`java -jar ${appleCommander} -p public/json/disks/${title}.dsk TITLE bin 0x2000 < bin/title.A2FC`);
	await executeJavaAsync(`java -jar ${appleCommander} -p public/json/disks/${title}.dsk MOON bin 0x2000 < bin/moon.A2FC`);
	cb?.();
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
	if (debug) console.log("->" + file);
	let name = file.substring(0, file.length - 4).toUpperCase();
	if (file.toLowerCase().indexOf('.bas') > -1) {
		// Compile a basic text file (.bas) into the tokenized BAS format and insert into the DSK
		// =======================================================================================

		// Remove all REM comments in the basic file
		let basic = await fs.promises.readFile("public/tmp/" + file, 'utf8');
		let regex = /^(?:\d+\s+)?REM.*|(:\s*)?REM.*|^\d+\s*$/gm;
		basic = `0 REM ${title} by ${author}\r\n${basic.replace(regex, "")}`;
		// Switch on debug mode (if applicable)
		if (debug) basic = basic.replace("DEBUG% = 0", "DEBUG% = 1");
		// Update version number (if present)
		basic = basic.replaceAll("{version}", "ver " + version);
		// Overwrite the file in tmp/
		await fs.promises.writeFile("public/tmp/" + file, basic);

		bas.push(file);
		bascallbacks.push(false);
		await new Promise((resolve) => {
			executeJava(`java -jar ${appleCommander} -bas public/json/disks/${title}.dsk ${name} bas 0x800 < public/tmp/${file}`,
				() => {
					console.log(`Compiled BASIC file: ${name}`);
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
			index = data.indexOf("$", index);
			if (index !== -1) {
				index++;
				while (_address.length < 4 && index < data.length) {
					let ch = data[index].toUpperCase();
					if ("0123456789ABCDEF".includes(ch)) {
						_address += ch;
					} else if (_address.length > 0) {
						break;
					}
					index++;
				}
			}
			if (debug) {
				// Switch on debug mode (if applicable)
				data = data.replace("BUILD_DEBUG = 0", "BUILD_DEBUG = 1");
			}
		}

		await new Promise((resolve) => {
			const args = ['/', `public/tmp/${file}`];
			if (debug) args.unshift('-V');
			const merlinProcess = execFile(merlin, args);
			if (debug) merlinProcess.stdout.on('data', (data) => console.log(data));
			merlinProcess.stderr.on('data', (data) => { console.error(`Merlin 32 error: ${data}`); });
			merlinProcess.on('close', (code) => {
				console.log(`Compiled BINARY file: ${name} at $${_address}`);
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
	if (file.toLowerCase().indexOf('.txt') > -1) {
		// Compile a pure text file (.txt) and insert into the DSK
		// ========================================================
		txt.push(file);
		txtcallbacks.push(false);
		await new Promise((resolve) => {
			executeJava(`java -jar ${appleCommander} -ptx public/json/disks/${title}.dsk ${name} txt < public/tmp/${name}.txt`,
				() => {
					console.log(`Compiled TXT file: ${name}`);
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
	check = [bascallbacks, bincallbacks, txtcallbacks].every(arr => arr.every(x => x));
	if (check) {
		console.log(`Compilation complete. http://localhost:8080/json/disks/${title}.dsk`);
		if (!debug) del(`public/tmp`, {force:true});
	}
	return check;
}

// Do we want to test on AppleWin? for example the Vaporlock effect does not work on the web emulator.
async function launchAppleWin(cb) {
	const appleWinPath = path.resolve(appleWin);
	const diskPath = path.resolve(`public/json/disks/${title}.dsk`);

	console.log(`Launching AppleWin with disk: ${diskPath}`);

	const appleWinProcess = spawn(appleWinPath, ['-d1', diskPath], {
		stdio: ['ignore', 'pipe', 'pipe'],
		detached: false,
	});

	appleWinProcess.stdout.on('data', (data) => console.log(`AppleWin stdout: ${data}`));
	appleWinProcess.stderr.on('data', (data) => console.error(`AppleWin stderr: ${data}`));

	appleWinProcess.on('error', (err) => {
		console.error(`Failed to start AppleWin: ${err.message}`);
		if (cb) cb(err);
	});

	appleWinProcess.on('close', (code) => {
		console.log(`AppleWin exited with code ${code}`);
		if (cb) cb(null, code);
	});
}

// Execute java scripts
function executeJava(cmdCode, cb) {
	return new Promise((resolve, reject) => {
		exec(cmdCode, (error, stdout, stderr) => {
			if (stdout) console.log(cmdCode + ' stdout: ' + JSON.stringify(stdout));
			if (stderr) console.log(cmdCode + ' stderr: ' + stderr);

			if (error) {
				console.log('exec error: ' + error);
				if (cb) cb(error);
				reject(error);
			} else {
				if (cb) cb();
				resolve();
			}
		});
	});
}

// Delete the public folder generated with each build
function clean(callback) {
	del(dir+'/**/*', { force: true });
	callback();
}

// Watch for changes in the source folder
function watch(callback) {
	browserSync.init({
		server: `./${dir}`,
		startPath: `#json/disks/${title}.dsk`,
		ui: false,
		port: 8080,
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

// Exports
exports.sync = series(dsk, empty, copy, files, reload);
exports.default = series(clean, emu, exports.sync);
exports.aw = series(launchAppleWin);

/*
   Gulpfile by Noncho Savov
   https://www.FoumartGames.com
*/
