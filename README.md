## Development setup for Apple II with emulator live-reload on localhost.

### Depends on `AppleCommander-ac-1.9.0.jar` to build DSK images.

1. Download Apple Commander from https://github.com/AppleCommander/AppleCommander/releases/tag/1.9.0
2. Update the _**appleCommander**_ linkage in gulpfile.js

### Uses `Merlin 32` to compile Assembler scripts.

1. Download **Merlin 32** from https://brutaldeluxe.fr/products/crossdevtools/merlin/index.html
2. Update the _**merlin**_ linkage in gulpfile.js

### Relies on `Apple2jse` emulator to run Apple //e in the web browser.

1. Download the `Apple2js` emulator: https://foumartgames.com/extensions/AppleII/emulator.zip
2. Extract the archive into emulator/ folder in the root of your project.

- Links:
  - Will Scullin's **Apple2js** emulator at github: https://github.com/whscullin/apple2js.
  - My custom **fork**: https://github.com/foumart/apple2js


## Installation and Build

1. Run `npm install` to install build dependencies.
2. Build the project with `npm run start` or `npm run build`

### Build Process: `npm run build`

1. Prepares a `public/` folder.
2. Copies the `emulator/`.
3. Copies the source DSK image from `dsk/` into `public/emulator/json/disks/`*¹.
4. Converts all source files (.bas, .s, .asm) into the needed format for Apple II (BAS, BIN) and writes them to disk.
5. Starts the Apple II emulator in the browser and loads the project *².
6. Runs a Watch process for automatic reload.

### Workflow:

1. Once the project is successfully built, a Watch process will make sure to reload the project with any change you perform within the `src/` folder.
2. The generated disk will be in `public/json/disks/`.

##
   
  *¹ Disk image gets the same name as project name. A ProDOS disk with all assets should be prepared beforehand.

  *² At load the emulator will boot the disk automatically and should try to run a basic STARTUP file right away.

