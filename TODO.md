Roadmap / TODOs until V1.0
==========================

WIP V0.8
--------

* Heavily improved the stability of the SD card reading
* Smart support of both MEGA65 SD Card slots: If a card is inserted into the backside slot then this card is used, otherwise the card in the bottom/trapdoor slot is used

Done in V0.9 (reminder for release notes)
-----------------------------------------

TODO until V1.0
---------------

* HyperRAM support for ROMs up to 8 MB on both machine types R2 and R3
* Support OpenEmu's Classic color schemes "Grayscale" (already supported),
  "Greenscale" and "Pocket": https://github.com/OpenEmu/Gambatte-Core/blob/master/GBGameCore.mm#L574
* User scan switch scaling between certain sizes (for example original size to 5x)
* Frame blending support
* (Internal) Update documentation to explain double buffering and frame blend
* (Internal) Enhance menu system to support checked/unchecked menu items
* MBC robustness: upgrade to newest MiST version and refactor MBC
* Improve SD card robustness: Check new SD card implementation
  and if better: Use it
* More convenient download of ROM: Rename cgb_bios.bin to cgb_boot.bin
* Migrate to MiSTer2MEGA65

Post V1.0
---------

* Work on current issue list on GitHub
