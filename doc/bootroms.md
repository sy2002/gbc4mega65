# Boot ROMs and BIOS

The core embeds the Open Source
[SameBoy](https://github.com/LIJI32/SameBoy) Game Boy Color boot ROM (BIOS)
(MIT-licensed, located in the repository folder `BootROMs/`), so Game Boy
Color mode works with zero setup: Just start the core and play. Game Boy
Classic mode uses the boot ROM that is built into the MiSTer Game Boy core
which this core is based on.

## Using an original boot ROM

For more authenticity you can use the original Game Boy Color boot ROM:

1. Download the original Game Boy Color boot ROM, for example from
   <https://gbdev.gg8.se/files/roms/bootroms/>. The file is called
   `cgb_boot.bin`.
2. Place it in the folder `/gbc` on your SD card.

The boot ROM is loaded automatically at every core start. If no file is
present, the core silently falls back to the embedded Open Source boot ROM.

The classic filename `cgb_bios.bin` from earlier gbc4mega65 versions also
works. If both files exist, `cgb_bios.bin` wins.

## Good to know

* The maximum boot ROM size is 4096 bytes; larger files are truncated.
* The boot ROM used in Game Boy Classic mode comes from the MiSTer Game Boy
  core (it is built into the bitstream) and is not replaceable at runtime.
* This repository ships no game ROMs and no BIOS files beyond the Open
  Source SameBoy boot ROMs and what the MiSTer Game Boy core itself
  contains.
