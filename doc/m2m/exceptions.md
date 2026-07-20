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

The `M2M` folder is based on the official MiSTer2MEGA65 release V2.0.1
(git tag `V2.0.1` of https://github.com/sy2002/MiSTer2MEGA65, linked as git
remote `upstream`) with the Game Boy-specific crop and the focused framework
backports documented below.

### Upstream M2M fix: restore HyperRAM placement pblock

The four-word HyperRAM receive FIFO is implemented as distributed RAM, and
`M2M/common.xdc` deliberately requires the paths from the input IDDRs to this
FIFO to stay below 2 ns. Without a physical placement constraint, unrelated
netlist changes can let the placer move the FIFO away from the fixed HyperRAM
I/O bank and violate this interface requirement.

The permanent upstream fix restores the historical HyperRAM placement pblock
in all four board constraint files, without changing the 2 ns timing
constraint or any framework interface:

```tcl
# Place HyperRAM close to I/O pins
create_pblock pblock_i_hyperram
add_cells_to_pblock pblock_i_hyperram [get_cells [list i_framework/i_hyperram]]
resize_pblock pblock_i_hyperram -add {SLICE_X0Y200:SLICE_X7Y224}
```

Affected files:

* `M2M/MEGA65-R3.xdc`
* `M2M/MEGA65-R4.xdc`
* `M2M/MEGA65-R5.xdc`
* `M2M/MEGA65-R6.xdc`

On R3, a controlled place-and-route experiment from the same optimized
checkpoint improved the `hr_rwds` WNS from -0.180 ns (six failing endpoints)
to +0.430 ns, with overall WNS +0.219 ns. The receive FIFO moved from
X10/X14, Y195-196 to X2, Y207-210 next to the HyperRAM I/O, reducing the worst
IDDR-to-FIFO routing delay from 1.474 ns to 0.864 ns.

When updating M2M: drop this local backport once the target framework release
contains the same placement constraint; otherwise re-apply it to all four
board files.

### M2M/vhdl/av_pipeline/crop.vhd: Game Boy crop window

The crop window constants (used by the "Handheld LCD (10:9)" aspect option) are
hardcoded in the framework for the C64 geometry. They were changed to the
Game Boy geometry: the input stream is the 160x144 Game Boy picture centered
in a 256x224 active area, and Handheld LCD crops the complete black border
away. The HDMI output fitting backport documented below then produces exact
5x integer scaling at 720p:

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

### OSM Scaling (adopted 1:1 from the AExp core)

The "OSM: %s" menu (9 scaling steps, 100% down to 50%) uses the AExp
implementation of the framework's OSM scaling - the stock V2.0.1 scaler had
timing closure problems, AExp replaced it with a pipelined renderer that
stores the font as a native 8x8 strike and expands it to the 16x16 logical
cell (exact 2x2 blocks at 100%, sharpened bilinear coverage for the smaller
sizes). A welcome side effect for the Game Boy core: at 100% the analog OSM
no longer contains single-column (37 ns) features in the scandoubled
Standard mode, which makes the OSM much friendlier to LCD monitors that
resample the VGA signal. The following files were taken from AExp (state of
2026-07-19) or changed accordingly:

* `M2M/vhdl/av_pipeline/vga_osm.vhd` - the new renderer (copied 1:1)
* `M2M/vhdl/av_pipeline/video_overlay.vhd` - 11-stage delay pipeline to
  match the longer renderer latency (copied 1:1)
* `M2M/vhdl/tdp_ram.vhd`, `M2M/vhdl/2port2clk_ram.vhd` - new generic
  `RAM_STYLE_SELECT` ("auto"/"block"/"distributed"), used by the new
  vga_osm for its font LUTROM (copied 1:1)
* `M2M/vhdl/av_pipeline/ascal.vhd` - `ram_style "distributed"` attributes
  on the shallow `i_dpram`/`o_dpram` CDC buffers so that rising BRAM
  pressure can never push them into block RAM (hunks applied; AExp's
  unrelated `i_interlaced` output was NOT taken)
* `M2M/font/Anikki-8x8-m2m.rom` + `.c` added, `Anikki-16x16-m2m.rom` +
  `.c` removed, `M2M/font/README.md` updated (all 1:1 from AExp);
  `FONT_FILE` in `CORE/vhdl/globals.vhd` points to the 8x8 ROM while
  `FONT_DX`/`FONT_DY` stay 16 (the logical OSM cell size)
* All four Vivado projects use the implementation strategy
  `Performance_ExplorePostRoutePhysOpt` (AExp measure against the routing
  pressure of the scaling pipeline)

When updating M2M: check whether the target release already contains the
AExp OSM Scaling renderer; if yes, drop these local copies, if no,
re-apply them.

### Backported from M2M V2.1: optional VGA Standard sync reshaper

The analog Standard-mode timing generated from `lcd.v` has an approximately
2.38 us HS pulse and six-line VS pulse. That resembles CEA 480p closely enough
that some VGA monitors select fixed consumer-video processing instead of their
adjustable PC-VGA path. M2M V2.1 commits
`f702fd8424981873938410513c53d20024a449fa` and
`b5c185a4bc3783e80504c94d63e8eee7228be892` add a generalized,
record-configured sync reshaper and its clean core-configuration interface.
The backport affects these framework files:

* `M2M/vhdl/av_pipeline/vga_sync_reshaper.vhd`
* `M2M/vhdl/av_pipeline/analog_pipeline.vhd`
* `M2M/vhdl/av_pipeline/av_pipeline.vhd`
* `M2M/vhdl/framework.vhd`
* `M2M/vhdl/av_pipeline/video_modes_pkg.vhd`

The last three are shared with the later HDMI output fitting backport and are
therefore copied exactly from commit `627446dc50b1234aa5c87a412c9c76116241601c`,
which contains both changes.

`framework.vhd` reads the core-owned `VGA_STD_SYNC` record directly from
`CORE/vhdl/globals.vhd`; the M2M V2.1 template exposes the same constant with an
OFF default. No board-top modification is needed. gbc4mega65 defines the native
`VIDEO_CLK_SPEED` as twice `CORE_CLK_SPEED`, then uses
`make_vga_sync_reshaper_cfg(C_VGA_SYNC_DMT_640X480_60, VIDEO_CLK_SPEED)`.
The helper evaluates to the hardware-proven profile: a 256-video-clock HS
pulse, a two-line VS pulse and negative polarity for both. The four Vivado
projects include the new reshaper source.

The profile replaces only pulse widths and output polarity; it does not change
RGB, active geometry, line length or frame length. The module sits after the
analog/digital split and is enabled only in scandoubled Standard mode, so HDMI,
both retro-15 kHz modes and CSYNC retain their original sync behavior.

### Backported from M2M V2.1: core-configurable HDMI output fitting

M2M V2.1 commit `627446dc50b1234aa5c87a412c9c76116241601c` adds a
core-owned `HDMI_VIEW` configuration record and generalized digital output
fitting. These framework files are copied exactly from that commit:

* `M2M/vhdl/av_pipeline/video_modes_pkg.vhd`
* `M2M/vhdl/av_pipeline/digital_pipeline.vhd`
* `M2M/vhdl/av_pipeline/av_pipeline.vhd`
* `M2M/vhdl/framework.vhd`

`CORE/vhdl/globals.vhd` configures
`make_hdmi_view_cfg(C_HDMI_FIT_4_3, C_HDMI_FIT_10_9)`. The existing crop
signal is presented as a two-choice **Aspect Ratio** radio group: TV-style
(4:3) retains the full 256x224 canvas, while Handheld LCD (10:9, the default)
selects a borderless Game Boy picture at the physical handheld aspect.
The latter produces centered output rectangles of 800x720, 533x480, 600x480
and 667x600 in the four offered HDMI modes, respectively. Both rectangle
tables are calculated at elaboration time; runtime hardware only selects a
precalculated rectangle by HDMI mode and crop bit.

This mechanism is wholly inside the digital pipeline, after the analog/HDMI
split. It cannot alter RGB, timing or geometry on VGA Standard or either 15 kHz
mode. The stock M2M default remains `C_HDMI_VIEW_LEGACY`, so cores that do not
opt into the feature retain bit-for-bit-compatible output placement.

When updating to an M2M release containing all three commits above, drop the
exact framework copies but retain the Game Boy `VIDEO_CLK_SPEED`,
`VGA_STD_SYNC` and `HDMI_VIEW` constants, the Game Boy crop constants, and the
reshaper source entries in all four Vivado projects.

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
