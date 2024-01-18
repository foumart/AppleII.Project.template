## BASIC development setup for Apple II with emulator live-reload on localhost.

### Depends on AppleCommander-ac-1.9.0.jar to build DSK images.

1. Download Apple Commander from https://github.com/AppleCommander/AppleCommander/releases/tag/1.9.0
2. Add to the root folder of your project as **ac.jar**

### Relies on Apple2js emulator to run Apple II in the web browser.

1. Download my adaptation over Will Scullin's emulator: https://foumartgames.com/extensions/AppleII/emulator.zip
2. Or get the latest emulator from whscullin github at: https://github.com/whscullin/apple2js
3. Make sure you have an emulator/ folder in the root of your project - it will be used during build..

## Installation and Build

1. Run **npm install** to install build dependencies.
2. Build the project with **npm run start** or **npm run build**

### What does a build do:

1. Cleans (or creates) a public/ folder and prepares it for a new build.
2. Copies the emulator/ to the public/ folder.
3. Copies the source DSK image from dsk/ as well (disk image have the same name as the project).
4. Converts the src/startup.bas working file into the tokenized format needed for Apple II and writes it on disk.
5. Starts or Syncs the Apple II emulator on localhost, it is configured to load the disk and run the project at boot.

#### Useful for Development:

1. Live reload - the web Emulator will restart with any change you perform within the src/ folder.
2. Ideally not only basic should be compiled by this development automatization but assembly as well - check TODO. 

#### TODO:

1. Improve the current demo - currently it is a BASIC example of loading a double hi-res picture and utilizing the mouse interface to plot on top via FDRAW binary subroutines, controlled with the mouse. It will be good to have some helper programs in the default DSK, but it is more important for the development setup to be able to handle and compile more languages, like binaey files. So far I had to write ASM directly in Merlin on the emulator in order to prepare some binaries for the demo.
2. The plotting only works if there is mouse interface available on the system, BASIC seems very slow for any mouse input handling - mouse interactions should be written in Assembly. Regarding assembly mouse scripting - check the binary demo TRACK and URL.TXT.
3. The plotting is currently only done on the first PAGE - to check how to utilize both pages and to do a benchmark on fastest sprite drawing routine.. 
