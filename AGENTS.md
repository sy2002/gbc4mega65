# gbc4mega65 — Project Guide for Coding Agents

This is the cold-start brief for coding agents working on **gbc4mega65** (Game Boy and
Game Boy Color for MEGA65). Read it first: it covers what this repo is, how it is laid
out, the port's design decisions, the build/test flow and the pitfalls. This file
replaces the MiSTer2MEGA65 framework's own `AGENTS.md` (which describes framework
internals and would mislead you here).

---

## 1. What is this project?

A port of the **MiSTer Game Boy / Game Boy Color core** to the **MEGA65**, built on the
**MiSTer2MEGA65 (M2M) framework V2.0.1**. Historical note: the original 2021 version of
this core (git branch `master`, V0.8) predates M2M and inspired its creation — this core
is the "mother of M2M". The `develop` branch contains the modern port: same proven Game
Boy machine, new framework.

- Authors: sy2002 + MJoergen (see `AUTHORS` for full credits incl. MiSTer/MiST/T80/SameBoy)
- License: GPL v3. Version: `CORE_VERSION` in `CORE/vhdl/config.vhd` (single source of truth)
- Boards: MEGA65 R3/R3A, R4, R5, R6 (R2 support was dropped with V1.0)
- The user-facing documentation website is generated from `README.md` + `doc/*.md`
  (see `doc/make_doc.md`)

### Deliberate deviations from a standard M2M port

1. **No MiSTer submodule.** `CORE/GameBoy` is a verbatim copy of the old `master:rtl`
   folder (Gameboy_MiSTer snapshot of January 2021) — the known-to-work core of the
   V0.8 release. Do not "upgrade" it casually; see `doc/m2m/exceptions.md`.
2. **The cartridge lives in BRAM** (1 MB maximum, checked by the firmware *before*
   loading). No HyperRAM usage by the core at all.
3. **`M2M/` is based on the official V2.0.1 release** (git remote `upstream` =
   sy2002/MiSTer2MEGA65, merge of tag `V2.0.1`) with the Game Boy crop plus focused
   V2.1/AExp backports. Every changed framework file is documented in
   `doc/m2m/exceptions.md`; treat `M2M/` as read-only otherwise.

---

## 2. Repository layout

```
/
├── README.md            end-user manual + documentation website home page
├── AUTHORS  VERSIONS.md LICENSE
├── AGENTS.md  CLAUDE.md this guide (CLAUDE.md just imports AGENTS.md)
├── make_release.py      generic M2M release packager (config: CORE/release.toml + CORE/release_hooks.py)
├── BootROMs/            Open Source SameBoy boot ROMs (.asm sources + .bin + .rom text format)
├── rom/bin2rom.sh       .bin → .rom converter (one binary octet string per line; ROM_PRELOAD format)
├── doc/                 *.md doc pages, gbc*.jpg screenshots, make_doc.py + theme/ (website),
│   └── m2m/exceptions.md   the authoritative list of deviations from upstream MiSTer/M2M
├── M2M/                 MiSTer2MEGA65 V2.0.1 + documented backports (M2M/QNICE = submodule)
└── CORE/
    ├── GameBoy/         vendored MiSTer core (gb.v, video.v = the PPU, lcd.v, T80/, ...)
    ├── vhdl/            the port: clk.vhd, main.vhd, mega65.vhd, config.vhd, globals.vhd,
    │                    keyboard.vhd, mbc.sv (from old MEGA65/Verilog), lcd_wrapper.v
    ├── m2m-rom/         QNICE firmware: m2m-rom.asm + make_rom.sh + video_filters/ blobs
    ├── CORE-R{3,4,5,6}.xpr  one Vivado project per board (keep all four in sync!)
    ├── CORE.xdc         core constraints (flicker-free clocks — see §6 pitfalls)
    └── release.toml / release_hooks.py   make_release.py policy
```

---

## 3. Architecture of the port

### Clocks (`CORE/vhdl/clk.vhd`)

Two MMCM "legs", switched glitch-free by two `BUFGMUX_CTRL` (C64MEGA65/AExp pattern):

| Leg | main_clk (gb.v, 8× GB clock) | video_clk (lcd.v, 2× main) | frame rate |
| --- | --- | --- | --- |
| native | 33.556548 MHz (+63 ppm) | 67.113095 MHz | 59.7313 Hz |
| fast   | 33.733974 MHz | 67.467949 MHz | 60.0473 Hz |

The **HDMI flicker-free** FSM in `mega65.vhd` (hr_clk domain) dithers between the legs
using the framework's ascal feedback `hr_high_i`/`hr_low_i`, time-averaging the core to
exactly the HDMI rate. Menu bit `C_MENU_HDMI_FF` gates it; OFF forces native.
`speedcontrol.vhd` divides main_clk by 8 (`ce` = 4.19 MHz) and 4 (`ce_2x`) on the
**falling** edge — gb.v builds gated clocks from these; do not "clean that up".

### Video

`lcd.v` (MiSTer's LCD-to-video module, **revived** — the old core did not compile it) is
instantiated via `CORE/vhdl/lcd_wrapper.v` (renames the VHDL-reserved port `on`,
hardcodes `sgb_en=1` + black backdrop). Result: the 160×144 picture centered in a
**256×224 active area** (Super Game Boy screen geometry) at the authentic **59.7275 Hz**,
inside lcd.v's 425×264 timing. This canvas is what makes the M2M on-screen-menu usable:
`VGA_DX×VGA_DY = 512×448` post-scandoubler = a 32×28 character OSM raster.

- `video_ce_o` = lcd.v's `ce_pix` (~6.71 MHz); `video_ce_ovl_o` is mode-dependent so that
  `VGA_DX = 512` overlay ticks always span the visible picture: **4×** `ce_pix` with the
  scandoubler (pattern 0/2/5/7 within each 10-clock pixel) and **2×** `ce_pix` in the
  retro-15 kHz modes (the framework doubles OSM rows there). All taps are phase-locked
  delays of `ce_pix` (the per-line 16-cycle stretch sits in blanking).
- Analog **VGA: Standard** uses M2M V2.1's optional `vga_sync_reshaper`: the core-owned
  `VGA_STD_SYNC` constant in `globals.vhd` selects the 640x480@60 VESA DMT pulse preset,
  converted with `VIDEO_CLK_SPEED` to 256-video-clock HS pulses plus two-line VS pulses
  with negative polarity. It preserves RGB, every source sync leading edge and the
  complete raster period, making monitors classify the otherwise CEA-like timing as PC
  VGA. The feature is downstream of the HDMI split and runtime-bypassed in both retro-15
  kHz modes; no framework board-top customization is involved.
- GBC color grading ("LCD Emulation" vs "Fully Saturated") is lcd.v's `originalcolors`
  input; DMG grayscale is lcd.v's default (tint=0).
- "HDMI: Zoom-in" = the framework crop (`M2M/vhdl/av_pipeline/crop.vhd`, constants changed
  to the GB geometry): crops the border → 5× integer scaling at 720p, like V0.8 looked.
- HDMI modes offered: 720p60 (default), 640×480@60, 720×480@59.94, 800×600@60. Note
  800×600 runs at 60.317 Hz — above the fast leg, so flicker-free cannot fully lock there.

### Audio

`gbc_snd` outputs 16-bit **unsigned**, not centered on 0x8000. Conversion to M2M's
signed PCM is a **logical** shift right by one (`signed("0" & x(15 downto 1))`) —
NOT arithmetic, NOT minus-0x8000 (both crackle; verified in the old core).

### QNICE devices (`CORE/vhdl/mega65.vhd`, ids in `globals.vhd`)

- `C_DEV_GB_CART` (0x0100): 1 MB cartridge BRAM. Data = 4k windows 0x00–0xFF, one byte
  per 16-bit word address (the Shell's streaming format). The data windows are
  **write-only** from QNICE (reads return 0): the Shell never reads them back, and the
  read-back path (falling-edge output of 256 BRAMs through the device mux into the CPU
  within a 10 ns half period) failed timing on R3. Same for the BIOS device. CSR block at window 0xFFFF
  implements the CRT/ROM protocol (`CRTROM_CSR_*` in `M2M/rom/sysdef.asm`); there is no
  hardware parser — `PARSEST` reports OK as soon as the Shell writes status OK, because
  all checks already ran in the firmware (`PREP_LOAD_IMAGE`). While streaming, the device
  **snoops the header bytes** (0x0143/46/47/48/49/4B) into registers for `mbc.sv` and
  `isGBC_game`. Reset semantics: the Game Boy is held in reset while **no cartridge is
  loaded** or while **data is streaming** (first byte written during status=LOADING sets
  `loading`; status=OK clears it and sets `cart_loaded`). A `PREP_LOAD_IMAGE` rejection
  happens *before* any byte streams, so a running game survives it (the CSR then stays at
  LOADING by Shell design — harmless, the reset logic keys on data writes, not on status).
- `C_DEV_GB_BIOS` (0x0101): 4 KB GBC BIOS BRAM, `ROM_PRELOAD` from
  `BootROMs/cgb_boot.rom`. Auto-load entries in `globals.vhd` optionally overwrite it from
  `/gbc/cgb_boot.bin` then `/gbc/cgb_bios.bin` (both OPTIONAL; bios wins; >4 KB truncated
  because only window 0 accepts writes). **Auto-load uses no CSR handshake** — plain
  streaming (see `CRTROM_AUTOLOAD` in `M2M/rom/crts-and-roms.asm`).
- The DMG (Classic mode) boot ROM is hardcoded inside `CORE/GameBoy/boot_rom.vhd` and is
  not runtime-replaceable; the 4 KB BIOS window is only read in GBC mode.

### Firmware (`CORE/m2m-rom/m2m-rom.asm`)

Standard V2.0.1 Shell callbacks only (no framework patches):
`FILTER_FILES` (only .gb/.gbc), `PREP_LOAD_IMAGE` (size 0x150..1 MB, MBC allow-list,
ROM/RAM size codes ≤ 5 — checks run BEFORE streaming; reads the header via the file
handle and seeks back to 0), `PREP_START` + `OSM_SEL_POST` → `LOAD_HDMI_FILTER`
(8-option ascal filter dispatch; `ASCAL_USAGE=1`), `CUSTOM_MSG` (empty-folder text).
`M2M$LOAD_POLYPHASE` is a V2.1 backport (delete on framework upgrade). Menu constants
are **auto-generated**: `make_rom.sh` scrapes `C_MENU_*` (mega65.vhd) → `GBC_OSM_*` and
`OPTM_G_*` (config.vhd) → `GBC_OPTM_G_*` into `osm_const.asm` (gitignored).

---

## 4. Build & test workflow

```bash
git clone --recurse-submodules <repo>       # only submodule: M2M/QNICE
cd M2M/QNICE/tools && ./make-toolchain.sh   # one-time QNICE toolchain
cd CORE/m2m-rom && ./make_rom.sh            # Shell ROM (also auto-run by Vivado synth_pre.tcl)
# open CORE/CORE-R<n>.xpr in Vivado, run synthesis → implementation → bitstream
python3 make_release.py V1.0 <outdir>       # packaging (needs coretool or bit2core)
python3 doc/make_doc.py check|build|serve   # documentation website
```

No-hardware verification that MUST stay green after changes:

- `make_rom.sh` (assembles + ROM budget guard, max 28672 words)
- GHDL analysis of all CORE VHDL (`--std=08` for `CORE/vhdl`, `--std=02` for
  `CORE/GameBoy`) against unisim/xpm/gb/mbc/lcd_wrapper stubs — a check harness with the
  stubs is easy to rebuild: analyze M2M packages (`tools.vhd`, `types_pkg`,
  `video_modes_pkg`, `tdp_ram`, `2port2clk_ram`, `cdc_stable`) first
- `iverilog -g2012 -i` over the .v/.sv files included by the Vivado projects
  (`lcd.v` needs SystemVerilog; exclude the unused MiSTer files listed in §3)
- a menu-consistency check: `OPTM_SIZE` == #OPTM_ITEMS lines == #OPTM_GROUPS entries,
  every `C_MENU_*` index points at the intended label, main view rows == `OPTM_DY`
- `M2M/tools/make_config.sh <f> auto` must produce exactly `OPTM_SIZE` (=78) bytes

---

## 5. Conventions

- Signal naming: M2M style (`lower_snake_case`, `_i/_o/_n` suffixes, clock-domain
  prefixes `main_*`, `video_*`, `qnice_*`, `hr_*`). QNICE-shared RAMs/registers use the
  **falling** clock edge (`FALLING_B => true`, `falling_edge(qnice_clk_i)`).
- File headers credit MiSTer: "This machine is based on Gameboy_MiSTer / Powered by
  MiSTer2MEGA65 / MEGA65 port done by sy2002 in 2021 - 2026 and licensed under GPL v3".
- Git commits are authored by sy2002 with **no** `Co-Authored-By: Claude` trailer —
  AI assistance is credited once in `AUTHORS` ("Anthropic Fable 5 and Opus 4.8").
- QNICE assembly: no apostrophes in comments (C preprocessor!), args in R8..R12,
  `INCRB`/`DECRB` register-bank discipline, multi-pass assembler (include order free).
- Every deviation from upstream sources goes into `doc/m2m/exceptions.md`.
- `M2M/video_filters/README.md` and `CORE/m2m-rom/video_filters/README.md` are
  append-only, newest section on top.

---

## 6. Gotchas & do-not-touch

1. **Menu index sync**: `C_MENU_*` (mega65.vhd) are flat 0-based line indices into
   `OPTM_ITEMS` (config.vhd); inserting a line shifts everything below. `make_rom.sh`
   scrapes them for the firmware — keep the constants single-line. Changing `OPTM_SIZE`
   invalidates distributed settings files (`gbc4mega65-<version>.cfg`). Growing the
   menu also grows the OSM heap demand: check `MENU_HEAP_SIZE` in
   `CORE/m2m-rom/m2m-rom.asm` (sizing formula in the comment there; both `HEAP_SIZE`
   values must deduct it). A too-small value is a runtime FATAL
   ("Heap corruption: Hint: OPTM_HEAP", error code = words of overrun) when the OSM
   opens. Keep the reserve small: menu heap directly reduces file-browser capacity.
2. **GameBoy VHDL is VHDL-93 in the Vivado projects** (no SFType in the .xpr):
   `bus_savestates.vhd` has a record field named `default` — reserved in VHDL-2008.
   `CORE/vhdl` files are VHDL-2008. Do not flip either direction.
3. **`lcd.v` must keep the SystemVerilog file type** in all four .xpr (unpacked array
   bounds) and must only be instantiated through `lcd_wrapper.v` (port named `on`).
4. **`gbc_snd.vhd` fails GHDL** with a std_logic_unsigned overload ambiguity — a GHDL
   false positive; Vivado is fine. Skip it in analysis harnesses, don't "fix" the file.
5. **Cart ROM BRAM needs `LATCH_ADDR_A => true`** with `do_latch_addr_a => cartrom_rd`
   (gb core read timing). QNICE side is falling-edge.
6. **CORE.xdc pin-name discipline**: `set_case_analysis` on `CORE/hr_core_speed_reg[0]/Q`
   + generated clocks on `i_clk_fast/CLKOUT0/1` + `RAM_STYLE BLOCK` on
   `CORE/bios/i_tdp_ram/ram_reg*` silently no-op if instances are renamed — after
   synthesis, verify all `get_pins`/`get_cells` match, the clocks show the fast periods
   (~14.822/29.644 ns) and the BIOS sits in block RAM (as LUTRAM its async read creates
   qnice→main paths into the GB CPU that fail timing by ~9 ns).
7. **Keep all four .xpr files in sync** (same file set modulo board top, XDC, max10 on
   R3, PDM-vs-I2S audio driver).
8. **gb.v/speedcontrol use both clock edges and gated clocks** — intentional MiSTer
   design, proven in V0.8; do not refactor.
9. `hdma.v` contains a testbench module (`hdma_tb`) in the same file — harmless, never
   select it as top.
10. The old pre-M2M implementation lives on branch `master` (`MEGA65/` folder) — it is
    the reference for behavior questions, not code to be reused directly.

---

## 7. Useful pointers

- M2M framework: https://github.com/sy2002/MiSTer2MEGA65 (git remote `upstream`;
  its Wiki incl. the Ultimate Porting Guide: local clone `../MiSTer2MEGA65.wiki`)
- Reference cores: `../C64MEGA65` (M2M reference implementation), `../AExp` (Amiga;
  source of the make_doc/make_release/HDMI-filter patterns used here)
- MiSTer upstream: https://github.com/MiSTer-devel/Gameboy_MiSTer
- Game Boy hardware reference: https://gbdev.io/pandocs/
