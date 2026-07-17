# Boot ROMs and BIOS

The core embeds the Open Source
[SameBoy](https://github.com/LIJI32/SameBoy) Game Boy and Game Boy Color
boot ROMs (MIT-licensed, located in the repository folder `BootROMs/`), so
it works with zero setup: Just start the core and play.

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
* The DMG boot ROM used in Game Boy Classic mode is built into the bitstream
  and is not replaceable at runtime.
* This repository ships no copyrighted ROMs.
