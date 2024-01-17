## BASIC Project setup for Apple II with automatic build and live-reload.

### Depends on AppleCommander-ac-1.9.0.jar to build DSK images.

1. Download from https://github.com/AppleCommander/AppleCommander/releases/tag/1.9.0
2. Add to the root folder of your repo as **ac.jar**

### Uses Apple2js emulator by whscullin to run an Apple II on the web browser.

1. You can get the latest version of the emulator from https://github.com/whscullin/apple2js
2. But it's easier to just unpack the provided emulator.zip (it's an old version, but it works)

### Installation

Once you've ready with the above setup, run **npm install** to install node.js dependencies.

After a successfull install you can build the project right away with **npm start** or **npm build**

#### What does a build do:

1. Cleans the public/ folder and prepares it for new build
2. Copies the emulator/
3. Copies the source DSK image from dsk/ folder (disk image should have the same name as project)
4. Converts the src/startup.bas working file into the tokenized format needed for Apple II and writes it on disk.
5. Starts or Syncs the Apple II emulator on the web configured to load the disk and directly run the project.

After a successfull build the live reload will restart the Emulator with any change you do with the source right away.

Enjoy!
