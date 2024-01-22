## Development setup for Apple II with emulator live-reload on localhost.

### Depends on AppleCommander-ac-1.9.0.jar to build DSK images.

1. Download Apple Commander from https://github.com/AppleCommander/AppleCommander/releases/tag/1.9.0
2. Update the _appleCommander_ linkage in gulpfile.js

### Uses Merlin 32 or RetroAssembler to compile Assembler scripts.

1. Download Merlin 32 from https://brutaldeluxe.fr/products/crossdevtools/merlin/index.html
2. Update the _merlin_ linkage in gulpfile.js
3. If you want to compile raw ASM, download RetroAssembler from https://enginedesigns.net/retroassembler/
4. Update the _retroassembler_ linkage in gulpfile.js

### Relies on Apple2js emulator to run Apple II in the web browser.

1. Download my adaptation over Will Scullin's emulator: https://foumartgames.com/extensions/AppleII/emulator.zip
2. Or get the latest emulator from whscullin github at: https://github.com/whscullin/apple2js
3. Make sure you have an emulator/ folder in the root of your project - it will be copied during build..

## Installation and Build

1. Run **npm install** to install build dependencies.
2. Build the project with **npm run start** or **npm run build**

### What does a build do:

1. Cleans (or creates) a public/ folder and prepares it for a new build.
2. Copies the emulator/ to the public/ folder.
3. Copies the source DSK image from dsk/ as well (disk image have the same name as the project).
4. Converts all source files (.bas, .s, .asm) into the needed format for Apple II (BAS, BIN) and writes them on disk.
5. Starts or Syncs the Apple II emulator - it will load the disk at boot and should try to run a basic STARTUP file right away.

#### Useful for Development:

- Live reload - the web Emulator will restart with any change you perform within the src/ folder.

#### TODO:

1. Improve the current demo. Loading a Double Hi-res picture is nice, now developing a mouse cursor interface in assembly..
2. The plotting only works if there is mouse interface available on the system, BASIC seems very slow for any mouse input handling - mouse interactions should be written in Assembly - check the binary demo MOUSE.
3. The plotting is currently only done on the first PAGE - to check how to utilize both pages and to do a benchmark on fastest sprite drawing routine.. 
