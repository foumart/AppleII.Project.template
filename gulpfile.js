const { src, dest, series } = require('gulp');
const gulp = require('gulp');
const browserSync = require('browser-sync').create();
const del = require('del');
const argv = require('yargs').argv;
const package = require('./package.json');
const exec = require('child_process').exec;

// the following data is taken directly from package.json
const title = package.name;
const id_name = `${title.replace(/\s/g, '')}_${getDateString(true)}`;
const version = package.version;

// data provided via additional params. "dir" sets the output directory
const dir = argv.dir || 'public';
const test = argv.test != undefined ? true : false;
const debug = argv.debug != undefined ? true : false;

// ======
// TASKS:
// ======

// Copy the Apple II web emulator
function app(cb) {
	var num = 0;
	
	src('../emulator/**/*', { allowEmpty: true })
		.pipe(dest(dir+'/'))
		.on("end", cb)

	/*function checkCompletion(){
		if (num <= 0) num ++;
		else cb();
	}*/
}


// Copy the source dsk image (name should be the same as project name + .DSK)
function dsk(cb) {
	src(`dsk/${title}.dsk`, { allowEmpty: true })
		.pipe(dest('public/json/disks/'))
		.on("end", cb)
}


// Copy any BIN files if needed, currently we supply the files with prepopulated source DSK.
/*function bin(cb) {
	executeJava(`java -jar ac.jar -p public/json/disks/GRIDLOCK.dsk TITLE bin 0x2000 < bin/title.A2FC`, () => {
		executeJava(`java -jar ac.jar -p public/json/disks/GRIDLOCK.dsk MOON bin 0x2000 < bin/moon.A2FC`, cb);
	});
}*/


// Transfer a text file in the tokenized BAS format to insert in the DSK
function bas(cb) {
	executeJava(`java -jar ac.jar -bas public/json/disks/${title}.dsk STARTUP bas 0x800 < src/startup.bas`, cb);
}


// Maybe we want to test on AppleWin? for example the Mouse interface does not work on the web emulator.
function appleWin(cb) {
	// run AppleWin directly (temporary solution)
	const { spawn } = require('child_process');
	const path = require('path');

	const appleWinPath = 'C:/Standalone/AppleWin/AppleWin.exe';
	const dskFilePath = `public/json/disks/${title}.dsk`;

	const appleWinProcess = spawn(appleWinPath, [dskFilePath]);

	// Optional: Handle events from the spawned process
	appleWinProcess.stdout.on('data', (data) => {
		console.log(`stdout: ${data}`);
	});

	appleWinProcess.stderr.on('data', (data) => {
		console.error(`stderr: ${data}`);
	});

	appleWinProcess.on('close', (code) => {
		console.log(`child process exited with code ${code}`);
	});
}

// execute scripts'n stuff
function executeJava(cmdCode, cb) {
	exec(cmdCode,
		function (error, stdout, stderr){console.log(JSON.stringify(stdout));
			if (stdout) console.log('stdout: ' + JSON.stringify(stdout));
			if (stderr) console.log('stderr: ' + stderr);
			if (error !== null) console.log('exec error: ' + error); else cb();
		}
	);
}


// Delete the temporary folder generated during packaging
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

	// should we watch for changes elsewhere
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
exports.default = series(clean, app, dsk, bas, watch);
exports.sync = series(clean, app, dsk, bas, reload);

/*
   Gulpfile by Noncho Savov
   https://www.FoumartGames.com
*/
