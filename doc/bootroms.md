# Boot ROMs and BIOS

The Game Boy runs a small boot ROM (also called BIOS) before it starts the
game: it initializes the hardware and shows the boot logo. The core brings
everything it needs, so no BIOS files are required:

* **Game Boy Color mode** uses the included Open Source
  [SameBoy](https://github.com/LIJI32/SameBoy) boot ROM (MIT-licensed; it
  lives in the repository folder `BootROMs/`, sources included).

* **Game Boy Classic mode** uses the boot ROM that is built into the MiSTer
  Game Boy core which this core is based on.

Note that in Game Boy Color mode all games boot through the Color BIOS -
including Game Boy Classic games, which is how they get their colorization.
The Classic boot ROM only runs in Game Boy Classic mode.

## Using an original Game Boy Color boot ROM

The Game Boy Color BIOS is the one boot ROM you can replace. For more
authenticity you can use the original one:

1. Download the original Game Boy Color boot ROM, for example from
   <https://gbdev.gg8.se/files/roms/bootroms/>. The file is called
   `cgb_boot.bin`.
2. Place it in the folder `/gbc` on your SD card.

The boot ROM is loaded automatically at every core start. If no file is
present, the core silently falls back to the embedded Open Source boot ROM.

The classic filename `cgb_bios.bin` from earlier gbc4mega65 versions also
works. Both filenames fill the same, single Game Boy Color BIOS slot -
there is no second slot for a Game Boy Classic boot ROM. If both files
exist, `cgb_bios.bin` wins.

## Good to know

* The maximum boot ROM size is 4096 bytes; larger files are truncated.
* The boot ROM used in Game Boy Classic mode is built into the bitstream
  and is not replaceable at runtime: files like `dmg_boot.bin` on the SD
  card are ignored.
* This repository ships no game ROMs and no BIOS files beyond the Open
  Source SameBoy boot ROMs and what the MiSTer Game Boy core itself
  contains.
