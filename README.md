Game Boy and Game Boy Color for MEGA65
======================================

Play [Game Boy](https://en.wikipedia.org/wiki/Game_Boy) and
[Game Boy Color](https://en.wikipedia.org/wiki/Game_Boy_Color) games on your
[MEGA 65](https://mega65.org/)!

[Download](bin) the bitstream and the core file for your R2 or R3 machine
from the [bin](bin) folder.

**WARNING: Alpha version 0.6 - See constraints below**

![Game Boy and Game Boy Color](doc/gb-and-gbc.jpg)

This core is based on the
[MiSTer](https://github.com/MiSTer-devel/Gameboy_MiSTer) Game Boy core which
itself is based on the
[MiST](https://github.com/mist-devel/gameboy) Game Boy core.

[sy2002](http://www.sy2002.de) ported the core to the MEGA65 in 2021.

Special thanks to [Robert Peip](https://github.com/RobertPeip)
for his invaluable support.

The core uses [QNICE-FPGA](https://github.com/sy2002/QNICE-FPGA) for
loading the Game Boy's BIOS as well as for the on-screen-menu and for
loading game roms.

Features
--------

* Game Boy and Game Boy Color support
* Super Gameboy Support - Borders, Palettes and Multiplayer (Work-in-Progress)
* Joystick support including special mappings so that you can for example play Super Mario Land via joystock (Work-in-Progress)
* Custom Palette Loading (Work-in-Progress)
* Convenient game cartridge browser which supports long filenames

Installation
------------

1. [Download](bin) the bitstream and the core file for your R2 or R3 machine
   from the [bin](bin) folder.
2. Either use MEGA65's bitstream utility or install the core file so that you
   can use MEGA65's <kbd>No Scroll</kbd> boot menu to load the core.
3. The core needs a FAT32 formatted SD card to load game roms.
4. If you put your ROMs into a folder called `/gbc`, then the core will
   display this folder on startup.
5. The core includes an Open Source Game Boy BIOS. For more authenticity,
   go to https://gbdev.gg8.se/files/roms/bootroms/ and and download
   `dmg_boot.bin` and `cgb_bios.bin` and place both in the `/gbc` folder.

Constraints of the current Alpha version 0.6
--------------------------------------------

* MEGA65 R2 machines: Maximum cartridge size: 256kB
* MEGA65 R3 machines: Maximum cartridge size: 1MB
* Only plays cartridges that do not need extra RAM in the cartridge ("Cartridge RAM")
* VGA 800x600 @ 60 Hz and audio via 3.5mm audio jack - no HDMI
* No joystick support
* No options menu, yet (no configuration possibilities such as
  "switch to Game Boy classic without color", palette switching, ...)
* In some games, there is a flickering rightmost column and/or bottom scanline

Some demo pictures
------------------

| ![gbc01](doc/gbc01.jpg)      | ![gbc02](doc/gbc02.jpg)     | ![gbc03](doc/gbc03.jpg)       | 
|:----------------------------:|:---------------------------:|:-----------------------------:| 
| *MEGA65 Core Selection*      | *Game Boy Core: Start*      | *Game Boy Core: File Browser* |
| ![gbc04](doc/gbc04.jpg)      | ![gbc05](doc/gbc05.jpg)     | ![gbc06](doc/gbc06.jpg)       | 
| *Game Boy Color Boot Screen* | *Super Mario Start Screen*  | *Super Mario Gameplay Screen* |

Clarification: These screenshots are just for illustration purposes. This repository does not
contain any copyrighted ROMs such as BIOS ROMs or game ROMs.
