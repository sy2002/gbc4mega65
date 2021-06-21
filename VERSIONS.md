Version 0.8 (beta) - MONTH DD, 2021
===================================

Even though this release is called "beta" it is **super stable and should play 99% (or more) of all Game Boy and Game Boy Color games**, given that the cartridge ROM size of the game is **up to 1 MB** (on a MEGA65 R3 machine, otherwise up to 256 kB).

### What is new?

* HDMI video and HDMI audio support (for MEGA65 R3 machines only)
* Migrated the core's screen resolution to the 720p @ 60Hz standard (1280x720 pixels) for better HDMI compatibility (coming from SVGA 800x600 @ 60 Hz)
* Smoother display (less flickering/artifacts) due to double-buffering
* Improved the stability and robustness of the SD card reading
WIP Smart support of both MEGA65 SD Card slots: If a card is inserted into the backside slot then this card is used, otherwise the card in the bottom/trapdoor slot is used

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
