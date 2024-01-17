## BASIC Project setup for Apple II with automatic build and live-reload.

### Depends on AppleCommander-ac-1.9.0.jar to build DSK images.

1. Download from https://github.com/AppleCommander/AppleCommander/releases/tag/1.9.0
2. Add to the root folder of your repo as **ac.jar**

### Uses Apple2js emulator by whscullin to run an Apple II on the web browser.

1. You can get the latest version of the emulator from https://github.com/whscullin/apple2js
2. Or you can use my own adaptation from https://foumartgames.com/extensions/AppleII/emulator.zip

### Installation and Build

1. Run **npm install** to install dependencies.
2. Build the project with the built-in **npm start** or **npm build**

#### What does a build do:

1. Cleans (or creates) the public/ folder and prepares it for a new build.
2. Copies the emulator/ to the public/ folder.
3. Copies the source DSK image from dsk/ as well (disk image should have the same name as project).
4. Converts the src/startup.bas working file into the tokenized format needed for Apple II and writes it on disk.
5. Starts or Syncs the Apple II emulator on localhost, configured to load the disk and run the project startup.

### Development
1. Use Live reload - the web Emulator will restart with any change you perform within the src/ folder.
2. Explore the current demo - a BASIC example of a double hi-res picture loading and plotting on top via FDRAW binary subroutines.

Enjoy!

PS. The plotting only works if there is mouse interface available on the system, BASIC seems very slow for any mouse imput handling - mouse interactions should be written in Assembly. The plotting is currently only done on the first PAGE - to be updated.. About the assembly mouse scripting - check the binary demo TRACK.
