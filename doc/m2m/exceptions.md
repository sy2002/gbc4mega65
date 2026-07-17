How to update gbc4mega65
========================

The following changes have been made to MiSTer, MiSTer2MEGA65 and QNICE.
As soon as you update one of these modules, make sure you are applying the
changes described here.

MiSTer core Gameboy_MiSTer (vendored in CORE/GameBoy)
-----------------------------------------------------

`CORE/GameBoy` is a verbatim copy of the `rtl` folder of the original
gbc4mega65 master branch, which itself is a snapshot of
https://github.com/MiSTer-devel/Gameboy_MiSTer as of late January 2021.
There is deliberately no submodule link: this port builds on the known-to-work
core of the gbc4mega65 V0.8 release. When updating to a newer MiSTer version,
re-apply these changes:

### Replaced MiSTer specific RAMs

Replace all `dpram` with `dualport_2clk_ram` (the M2M framework provides a pin
compatible entity in `M2M/vhdl/2port2clk_ram.vhd`). This replacement can be
done via search/replace. Affected files in `CORE/GameBoy`:

* `gb.v`
* `sprites.v` (additionally: `reg [7:0] oam_q` was changed to `wire [7:0] oam_q`)

### lcd.v needs the SystemVerilog file type

`CORE/GameBoy/lcd.v` uses SystemVerilog style unpacked array bounds
(`reg [14:0] vbuffer[65536];`). The file itself is byte-identical to MiSTer;
instead of patching it, all four Vivado projects mark the file with the file
type "SystemVerilog". Keep this property when regenerating the projects.

### lcd.v is instantiated through a wrapper

`lcd.v` has an input port named `on`, which is a reserved word in VHDL.
`CORE/vhdl/lcd_wrapper.v` renames the port and hardcodes the gbc4mega65
configuration (Super Game Boy screen geometry with a black border via
`sgb_en = 1` and `sgb_border_pix = 0`), so `lcd.v` never needs to be edited.

### Unused MiSTer files

The following files in `CORE/GameBoy` are carried along for completeness but
are not part of the Vivado projects: `sgb.v` (needs `dpram_dif` from MiSTer's
`sys` folder), `cheatcodes.sv` (its instantiation inside `gb.v` is commented
out), `sdram.sv`, `ddram.sv`, `spram.vhd` (Altera), `pll.v`, `pll.qip`,
`pll/pll_0002.*` (Altera PLL), `T80/T80.qip` (Quartus file list).

MiSTer2MEGA65
-------------

The `M2M` folder is a verbatim copy of the official MiSTer2MEGA65 release
V2.0.1 (git tag `V2.0.1` of https://github.com/sy2002/MiSTer2MEGA65, linked
as git remote `upstream`) with exactly one modified file:

### M2M/vhdl/av_pipeline/crop.vhd: Game Boy crop window

The crop window constants (used by the "HDMI: Zoom-in" menu item) are
hardcoded in the framework for the C64 geometry. They were changed to the
Game Boy geometry: the input stream is the 160x144 Game Boy picture centered
in a 256x224 active area, and zooming in crops the complete black border
away (5x integer scaling at 720p):

```vhdl
constant LEFT_BORDER_IN    : natural := 48;
constant TOP_BORDER_IN     : natural := 41;   -- 41, not 40: see the comment in crop.vhd
constant IMAGE_SIZE_X      : natural := 160;
constant IMAGE_SIZE_Y      : natural := 144;
constant LEFT_BORDER_NEW   : natural := 0;
constant RIGHT_BORDER_NEW  : natural := 0;
constant TOP_BORDER_NEW    : natural := 0;
constant BOTTOM_BORDER_NEW : natural := 0;
```

When updating M2M: re-apply this change (the file also carries an
"Updating notes" block in its header).

### Backported from M2M V2.1: M2M$LOAD_POLYPHASE

`CORE/m2m-rom/m2m-rom.asm` contains a local copy of the `M2M$LOAD_POLYPHASE`
helper (loading polyphase filter coefficients into the ascal filter RAM),
which is part of the upcoming M2M V2.1 `M2M/rom/tools.asm`. The same
backport is used by the AExp core. When updating to M2M V2.1 or later:
delete the local copy - the assembler will flag the duplicate label.

QNICE
-----

`M2M/QNICE` is the unmodified submodule at the commit pinned by the official
M2M V2.0.1 release.
