# Building from source

gbc4mega65 is Open Source (GPL v3) and building it yourself is
straightforward.

## Getting the source

Clone the repository including its submodule:

```bash
git clone --recurse-submodules https://github.com/sy2002/gbc4mega65.git
```

If you already cloned without the submodule, run this inside the repository:

```bash
git submodule update --init --recursive
```

The only submodule is `M2M/QNICE`, the QNICE system-on-a-chip that powers
the on-screen-menu and the file browser.

## Building the QNICE toolchain

Build the QNICE toolchain once (answer all questions by pressing
<kbd>Return</kbd>):

```bash
cd M2M/QNICE/tools
./make-toolchain.sh
```

## Building the Shell firmware

Build the firmware of the Shell (the on-screen-menu and file browser):

```bash
cd CORE/m2m-rom
./make_rom.sh
```

`make_rom.sh` auto-generates files such as `osm_const.asm` before it
assembles the firmware. You rarely need to run it manually: Vivado re-runs
it automatically at synthesis via `synth_pre.tcl`.

## Building the bitstream

Open one of the four Vivado projects - `CORE/CORE-R3.xpr`,
`CORE/CORE-R4.xpr`, `CORE/CORE-R5.xpr` or `CORE/CORE-R6.xpr` - that matches
your MEGA65 model and run synthesis, implementation and bitstream
generation. You need Vivado 2019.2 or newer.

## Packaging a release

Package a release with:

```bash
python3 make_release.py <version> <output_folder>
```

The script checks the given version against `CORE_VERSION` in
`CORE/vhdl/config.vhd` and needs `coretool` or `bit2core` on the `PATH`.
Alpha and beta versions additionally need a row in the
[list of work-in-progress builds](inofficial.md).

## Architecture

`M2M/` is a verbatim copy of MiSTer2MEGA65 V2.0.1 with one documented
exception, see the [update and exception notes](m2m/exceptions.md).
`CORE/GameBoy` is the vendored MiSTer Game Boy core of the proven V0.8
release. `CORE/vhdl` wires them together: `clk.vhd` contains the
flicker-free clocks, `main.vhd` is the machine wrapper, `mega65.vhd`
implements the QNICE devices including the 1 MB cartridge BRAM, and
`config.vhd` defines the on-screen-menu. `CORE/m2m-rom` is the QNICE
firmware. The repository-root [AGENTS.md](../AGENTS.md) contains the deep
technical guide.

One discipline to keep in mind when changing the on-screen-menu: the
`C_MENU_*` constants in `mega65.vhd` must match the `OPTM_ITEMS` order in
`config.vhd`, and `make_rom.sh` scrapes them into the firmware.
