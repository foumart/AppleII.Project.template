## Development setup for Apple II with emulator live-reload on localhost.

### Depends on `AppleCommander-ac-1.9.0.jar` to build DSK images.

1. Download Apple Commander from https://github.com/AppleCommander/AppleCommander/releases/tag/1.9.0
2. Update the _**appleCommander**_ linkage in _**gulpfile.js**_ (line 21)

### Uses `Merlin 32` to compile Assembler scripts.

1. Download **Merlin 32** from https://brutaldeluxe.fr/products/crossdevtools/merlin/index.html
2. Update the _**merlin**_ linkage in _**gulpfile.js**_ (line 22)

### Relies on `Apple2jse` emulator to run Apple //e in the web browser.

1. Download the `Apple2js` emulator: https://foumartgames.com/extensions/AppleII/emulator.zip
2. Extract the archive into _**emulator/**_ folder in the root of your project.

- Links:
  - Will Scullin's **Apple2js** emulator at github: https://github.com/whscullin/apple2js.
  - My custom **fork**: https://github.com/foumart/apple2js providing additional graphical options


## Installation and Build

1. Run `npm install` to install build dependencies.
2. Build the project with `npm run build` (release) or `npm run dev` (debug).
3. Optionally test on AppleWin with `npm run aw`.

### Build Process: `npm run build`

1. Prepares a `public/` folder.
2. Copies the `emulator/`.
3. Copies the source DSK image from `dsk/` into `public/emulator/json/disks/`*¹.
4. Compiles all source files (.bas, .s and .txt) into the needed format for Apple II (BAS, BIN, TXT) and writes them to disk.
5. Starts the Apple II emulator in the browser and loads the project *².
6. Runs a Watch process (Browser-sync) for automatic reload.

##
   
  *¹ Disk image gets the same name as project name. A ProDOS disk with all assets should be prepared beforehand.

  *² At load the emulator will boot the disk automatically and should try to run a basic STARTUP file right away.

##

### Workflow:

 - Once the project is built, a Watch process will make sure to reload the project with any change you perform within the `src/` folder. Keep in mind that the build process may fail if the `public` directory is opened in another app, like AppleWin.
 - The generated disk will be in `public/json/disks/`.

##

#### Older versions:
https://www.foumartgames.com/extensions/a2-project/#json/disks/a2-project.dsk (version 0.1)
https://www.foumartgames.com/extensions/AppleIIe/#../AppleII/json/disks/a2-project.dsk (version 0.2 - including experimental mouse scripts)
