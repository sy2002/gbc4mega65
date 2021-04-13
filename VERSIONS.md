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
