Version 1.0 - NOT YET RELEASED (work in progress)
=================================================

The Game Boy core has been rebuilt on top of the [MiSTer2MEGA65](https://github.com/sy2002/MiSTer2MEGA65) framework V2.0.1 - the framework whose creation was originally inspired by this very core. It still plays the same games with the same great compatibility as V0.8, but it now feels and behaves like a modern MEGA65 core.

### What is new?

* Support for all current MEGA65 models: R3/R3A, R4, R5 and R6 (the R2 pre-series machines are no longer supported)
* On-screen-menu with the look and feel of the C64 and Amiga cores, including a convenient file browser for loading cartridges
* HDMI submenu with four 60 Hz display modes: 720p (default), 640x480, 720x480 (59.94 Hz) and 800x600
* HDMI Filter submenu with eight image filters, from "No Filter" via "Lanczos" (default) and "Scanlines" up to two CRT simulations
* HDMI Flicker-free: the core is gently synchronized to the HDMI frame rate, eliminating the slowly wandering tear line (on by default)
* HDMI Zoom-in: crops the black border around the Game Boy picture, resulting in a razor sharp 5x integer scaling at 720p (off by default)
* VGA submenu: Standard (31 kHz) plus two retro 15 kHz modes (with HS/VS or with CSYNC) for CRT monitors and RGB/SCART setups
* All settings are saved to the SD card and restored at the next start (put the settings file from the release ZIP into the /gbc folder)
* The maximum cartridge size is now 1 MB on all supported machines, and the core checks the cartridge before loading it
* The Game Boy Color BIOS can now be provided as cgb_boot.bin (in addition to the classic cgb_bios.bin) in the /gbc folder
* Improved audio, including an optional audio filter chain ("Audio Improvements")
* Color Mode menu: the "LCD Emulation" color grading (on by default) approximates the historical LCD screen of the Game Boy Color; "Fully Saturated" shows the raw RGB colors
* The core starts in Game Boy Color mode (switch to Game Boy Classic in the menu for the authentic grayscale look)
* Joysticks work in both ports and stay active while the on-screen-menu is open, so the game remains playable while you adjust settings

### Known limitations

* No savegames yet (i.e. no battery buffered cartridge RAM): highscores and game states are lost when the core is switched off
* Cartridges larger than 1 MB are not supported (the cartridge stays in BRAM for now)
* The Super Game Boy, the serial link cable, MiSTer save states and the cheat engine are not supported

Version 0.8 (beta) - June 27, 2021
===================================

Even though this release is called "beta" it is **super stable and should play 99% (or more) of all Game Boy and Game Boy Color games**, given that the cartridge ROM size of the game is **up to 1 MB** (on a MEGA65 R3 machine, otherwise up to 256 kB).

### What is new?

* HDMI video and HDMI audio support (for MEGA65 R3 machines only)
* Migrated the core's screen resolution to the 720p @ 60Hz standard (1280x720 pixels) for better HDMI compatibility (coming from SVGA 800x600 @ 60 Hz)
* Smoother display (less flickering/artifacts) due to double-buffering
* Improved the stability and robustness of the SD card reading
* Smart support of both MEGA65 SD Card slots: If a card is inserted into the backside ("external") slot then this card is used, otherwise the card in the bottom/trapdoor ("internal") slot is used.
  Moreover, you can switch to the internal SD card in the file browser using F1 and to the external SD card using F3.

### Why is the release still called "beta"?

* No HyperRAM: Cannot play games that have ROMs larger than 1 MB (MEGA65 R3 machine) or 256 kB (MEGA65 R2 machine)
* Flickering in rare situations due to no frame blending
* No savegames (i.e. no battery buffered cartrige RAM)

Version 0.7 (beta) - May 3, 2021
================================

Even though this release is called "beta" it is **super stable and should play 99% (or more) of all Game Boy and Game Boy Color games**, given that the cartridge ROM size of the game is **up to 1 MB** (on a MEGA65 R3 machine, otherwise up to 256 kB).

### What is new?

* Much better compatibility (games and demos) due to support for more MBCs
* Cartridge RAM support added
* Option menu works
* Joystick: Have a look at the [mapping options](https://github.com/sy2002/gbc4mega65/blob/V0.7/README.md#joystick-usage-and-mapping) to learn how to use it in games that use buttons to jump
* LCD Emulation: Option to perform [color grading](https://github.com/sy2002/gbc4mega65/blob/V0.7/README.md#color-modes) for a more realistic look
* Ability to browse larger folders
* Fixed flickering/missing content of rightmost and bottom scanline
* Improved SD card robustness

### Why is the release still called "beta"?

* No HDMI: Video/audio output is still VGA and 3.5mm audio jack
* No HyperRAM: Cannot play games that have ROMs larger than 1 MB (MEGA65 R3 machine) or 256 kB (MEGA65 R2 machine)
* Only supports MEGA65's bottom SD card slot, the rear slot is ignored
* Flickering in rare situations due to no double bufffering, no frame blending
* No savegames (i.e. no battery buffered cartrige RAM)

Version 0.6 (alpha) - March 23, 2021
====================================

* Improved Memory Bank Controller (MBC) support: MBC 1, 2, 3, 5 & 6. The core can now play hundreds of games as long as they do not need additional RAM on the game cartridge and as long as they fit into the core's ROM.
* Maximum game cartridge ROM size enlarged
  * MEGA65 R2: **256 kB**
  * MEGA65 R3: **1MB**
* Filenames that are longer than the screen width are now truncated using "..."
* Improved stability by smarter loading and by catching various error situations
* Visual feedback (blinking) while loading larger ROMs

Version 0.5 (alpha) - March 13, 2021
====================================

## Features
* Game Boy and Game Boy Color support
* VGA 800x600 @ 60 Hz and audio via 3.5mm audio jack
* All features of MiSTer's GameBoy core as of January 2021
* FAT32 file browser that support long file names

## Constraints 
* Only plays 32kB ROM files and some selected 64kB ROM files such as Super Mario Land 1, QIX and Castlevania 1
* No HDMI
* No joystick support
* No options menu, yet (no configuration possibilities such as "switch to Game Boy classic without color", palette switching, ...)
