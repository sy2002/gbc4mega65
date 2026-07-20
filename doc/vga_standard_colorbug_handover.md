# Handover: VGA "Standard" mode pink-cast color bug

Internal debugging handover for the next coding-agent instance. This is **not**
a user-facing page and is deliberately not linked from `README.md`, so
`make_doc.py` will not pull it into the documentation website.

Date of handover: 2026-07-20. Branch: `develop`.

---

## 1. One-paragraph summary

On the MEGA65 **analog output in "VGA: Standard" mode** (the scandoubled
31.5 kHz variant — note that the connector is called "VGA" but the signal is
just the analog RGB output), the whole picture has a **pink/magenta cast**:
Super Mario and other games render pink, and the OSM "Game Boy for MEGA65"
headline (which should be yellow-family) renders pink. Everything else is
**correct**: both retro 15 kHz analog modes, all HDMI modes, and the OSM at
every scaling step. An earlier fix in this same area removed a separate
"ripple / wiggly vertical lines" artifact and improved the colors from
"totally wrong" to "pink cast" — so we are making progress but are not done.

---

## 2. What currently works vs. what does not

| Output | State |
| --- | --- |
| HDMI (all 4 modes, menu + game) | correct |
| VGA "15 kHz with HS/VS" | correct (verified on hardware, BenQ) |
| VGA "15 kHz with CSYNC" | correct (verified on hardware, BenQ) |
| OSM scaling (100% .. 50%) | correct on all outputs |
| **VGA "Standard" (scandoubled 31.5 kHz)** | **pink cast on game AND OSM** |

The reference photos live in the user's `~/Downloads`:
`gbc-15kHz-csync-correct.jpeg`, `gbc-15kHz-hsvs-correct.jpeg` (both good),
and `gbc-standard-colorbug.jpeg` (the pink OSM). An earlier, worse state is
`mario.jpeg` (violet Mario logo with ripples — that ripple part is fixed now).

---

## 3. Git state and what is already committed

Baseline before this line of work: commit `6d3e4a6` ("V1.0").

Two commits are already on `develop`:

- `5d167fc` "Fix VGA Standard, restore splash, port OSM Scaling from AExp"
- `f5de412` "Fixes QNICE OSM heap size"

**Still uncommitted:** the four `CORE/CORE-R{3,4,5,6}.xpr` files carry the
implementation-strategy switch to `Performance_ExplorePostRoutePhysOpt`. They
are modified in the working tree but not committed. Commit them before any
release build, or the release will not reproduce the tested bitstreams.

All four boards build clean (timing met, zero unmatched constraints). The
bug is purely cosmetic in one analog mode; the rest of V1.0 is release-ready.

---

## 4. The fix that IS already in (do not redo it)

The "ripple / wiggle" artifact and part of the color error came from the
overlay/resampling clock-enable phase. This is fixed in
`CORE/vhdl/main.vhd`, signal `video_ce_ovl_o` (search for `C_SD_LINE`,
`video_sd_phase`, `video_sd_cnt`).

Why it was wrong: the framework's analog path re-registers the whole video
stream **including hsync/vsync** on `video_ce_ovl_o` (in
`M2M/vhdl/av_pipeline/vga_recover_counters.vhd`). The old grid was
phase-locked to `lcd.v`'s **input** pixel enable (10 video-clocks per pixel).
But MiSTer's scandoubler locks its **output** pixels and its doubled hsync to
a half-line counter of `4256/2 = 2128` video-clocks, and 2128 is not a
multiple of 10. The two grids beat: the sampling phase rotated line-to-line,
which displaced alternating lines horizontally (the ripple) and quantized the
re-registered hsync differently per line (its period alternated by about
`+/-40 ns`, which analog monitors dislike).

The fix builds the Standard-mode `video_ce_ovl_o` from its own half-line
counter locked to the **same reference the scandoubler uses** (restart at the
hblank falling edge, 2 ticks per 5-clock output pixel, wrap at 2128 = giving
exactly 512 OSM ticks per visible line). The 15 kHz branch and the HDMI path
were left byte-identical.

**Verification already done (in simulation):** a cycle-exact co-simulation of
the real `lcd.v` -> real `video_mixer`/scandoubler -> stock VHDL overlay chain
(`vga_recover_counters` -> `video_overlay` -> `vga_osm`) shows the hsync period
is now exactly `21280 ns` on every line, and that **only the three legal OSM
colors appear on the digital wire**. In other words, the digital signal that
leaves the FPGA logic is provably clean. See section 7 to rebuild the harness.

---

## 5. Why the remaining pink is probably NOT a digital-logic bug

Two independent arguments point away from the FPGA logic and toward the
analog signal / the monitor:

1. **Simulation says the digital pixels are correct.** The co-sim above
   produced only legal colors, both for a synthetic pattern and for the real
   `lcd.v` output. (Caveat: the co-sim covered the overlay chain up to
   `video_overlay`'s output. It did **not** include the last stage in
   `analog_pipeline.vhd` — the `phase_shift_vga_signals` falling-edge
   re-register, the `vga_data_enable` black-out-outside-DE process, and the
   VDAC pins. That short segment is unverified. See section 8, idea D.)

2. **The cast is uniform across coarse content.** Game backgrounds are solid
   and coarse (about 74 ns per source pixel). If the cause were fine-feature
   aliasing (single-column OSM strokes beating with the monitor's ADC), the
   coarse game picture would be fine. It is not — it is uniformly pink. A
   uniform tint across all content in exactly one output mode is the classic
   signature of an **analog reception problem**: black-level (DC-restore)
   clamp failure, or the monitor mis-classifying the mode and sampling with
   the wrong pixel clock / phase / clamp gate.

A pink/purple wash over the entire picture is a well-known symptom of a VGA
LCD's **ADC black-level clamp drifting** because it cannot find a clean black
reference during the back porch. That is the current prime hypothesis.

---

## 6. Prime hypothesis and the runner-up

**Prime hypothesis — monitor black-level clamp / mode-classification failure.**
Our Standard mode is close to VESA 640x480@60 but not equal to it:

- Ours: `video_clk = 67.108864 MHz`, line = 2128 clocks -> Hfreq about
  `31.535 kHz`; 264x2 = 528 total lines; Vfreq `59.7275 Hz`; **positive**
  hsync and vsync (from `lcd.v`, `hs <= 1` during sync, passed straight
  through the scandoubler and `analog_pipeline.vhd`).
- VESA 640x480@60: `25.175 MHz`, 800x525 total, `31.469 kHz` / `59.94 Hz`,
  **negative** hsync and vsync.

Same horizontal frequency family, but different sync polarity, different total
line count, and non-VESA porch proportions inherited from `lcd.v`
(H = 160, HFP = 103, HS = 32, HBP = 130 in input-pixel units). A modern LCD
classifies the mode from Hfreq + sync polarity, then samples at its assumed
fixed pixel clock and runs its clamp gate at its assumed back-porch position.
If that assumption is even slightly off, the clamp lands on non-black and the
whole frame tints. This explains: uniform cast, game + OSM both affected,
Standard only, 15 kHz fine (a CRT / 15 kHz path does not do VESA
classification), HDMI fine (digital, no clamp).

**Runner-up — a genuine analog-level bug in the untested pipeline tail.** The
`vga_data_enable` process zeroes RGB outside `mix_vga_de`. If `mix_vga_de`
(the scandoubler DE) is misaligned so the back porch is not truly black, the
monitor clamp has nothing clean to lock to — same visible result, but the
cause would be in our RTL, not the monitor. This is worth ruling out because
it is cheap to check and, if true, is a real fix we control.

Note the two hypotheses predict the same symptom but different fixes, so the
**first job is a decisive localization test**, not a code change.

---

## 7. Decisive diagnostics to run FIRST (before touching code)

1. **Different display.** Put Standard mode on (a) a real CRT VGA monitor and
   (b) a second, different LCD, ideally one with an on-screen "mode detected"
   readout, or a VGA capture/scan-converter that reports the incoming mode.
   - Pink on the CRT too  -> the fault is in our analog signal (section 8,
     ideas C/D). The monitor clamp theory is wrong.
   - Perfect on the CRT, pink only on the LCD -> confirms the clamp /
     classification theory (section 8, ideas A/B). This is the expected
     outcome and the most informative single test.

2. **Compare against a known-good M2M core on the same monitor.** C64MEGA65
   and the Amiga core ship the identical M2M scandoubler "Standard" path and
   are known to work on LCDs. Boot C64MEGA65 in its Standard VGA mode on the
   same BenQ. If it is clean and ours is pink, the delta is the GB-specific
   `lcd.v` sync/porch geometry feeding the scandoubler (their native timing is
   more monitor-friendly). Then diff:
   - `M2M/vhdl/av_pipeline/analog_pipeline.vhd` (should be identical framework)
   - how each core drives `qnice_scandoubler_o` / `qnice_retro15kHz_o` /
     `qnice_csync_o` and the video-mode package it selects
   - the native horizontal timing each core feeds the scandoubler
   Local reference clones: `../C64MEGA65`, `../AExp`.

Do not skip step 1. It splits the entire problem in half.

---

## 8. Fix ideas, ordered by likelihood x cheapness

### A. Flip VGA sync polarity to negative in Standard mode (cheap, high info)
VESA 640x480@60 uses negative hsync/vsync; we emit positive. Some monitors
key their mode class and clamp-gate position off polarity. Inverting the
Standard-mode syncs (only Standard — leave 15 kHz and CSYNC alone) is a
small change in `analog_pipeline.vhd` / the top-level VGA output and a great
early experiment. Low risk, decisive information even if it is not the whole
cure.

### B. Make Standard-mode timing match a real VESA mode (the "correct" fix)
Adjust the scandoubled horizontal timing so the monitor classifies us as a
mode it samples correctly (front/back porch and sync-width proportions of a
real VESA 640x480@60, negative sync). The mismatch originates in `lcd.v`'s
GB-native porch geometry; we cannot edit `lcd.v` (it is the proven core), but
we can retime in the scandoubler feed or the analog pipeline. Bigger change,
but if the clamp theory holds this is the real solution. Cross-check the exact
numbers against whatever C64MEGA65 emits for its Standard mode.

### C. Verify the black level during the back porch is truly 0 and long enough
Confirm `vga_data_enable` really zeroes RGB across the entire back porch and
that the back porch duration at 31.5 kHz is enough for the monitor's DC
restore. Check `mix_vga_de` alignment out of the scandoubler versus the actual
visible window. If the porch is not clean black, that alone breaks the clamp.

### D. Extend the simulation to the pipeline tail (closes the last gap)
The existing co-sim stops at `video_overlay`. Extend it through
`analog_pipeline.vhd`'s `vga_data_enable`, `phase_shift_vga_signals` (falling
edge), and `csync`, and dump the exact bytes that reach the VDAC pins across a
full line including both porches. This converts "probably not our logic" into
"provably not our logic" (or finds a real bug). Cheap given the harness in
section 9 already exists in spirit.

### E. Fallback if the physics is irreducible (document, do not fight)
If Standard mode on an LCD is fundamentally a re-sampling of a non-standard
analog mode and cannot be made perfect on all monitors, the honest fallback is
a one-line note in `doc/video_modes.md` steering LCD users to HDMI or 15 kHz,
mirroring what the docs already say about CRTs. Do not ship a hack that
distorts the signal to please one monitor. This is the last resort, only after
A-D are exhausted.

---

## 9. How to rebuild the simulation harness (it lived in a session scratchpad)

The harness is not in the repo; it was built in a temporary scratchpad and is
gone. To recreate it (Icarus Verilog + GHDL, both already used in this
project's no-hardware checks):

1. **Verilog side** (`iverilog -g2012`): instantiate the real
   `CORE/vhdl/lcd_wrapper.v` + `CORE/GameBoy/lcd.v` in the no-cartridge state
   (GB held in reset: `lcd_clkena = 0`, `lcd_on = 0`, `isGBC = 1` because
   Color is the new default so the blank layer is black), feeding the real
   `M2M/vhdl/controllers/MiSTer/video_mixer.sv` with `scandoubler = 1`. Also
   instantiate `hq2x.sv` and `video_freezer.sv`. Zero-initialise `lcd.v`'s
   flops and its 64k `vbuffer` (the sim needs deterministic BRAM). Replicate
   `main.vhd`'s `p_ce_ovl` (the hblank-locked 512-tick grid) in the testbench.
   Dump, per video clock, `{VGA_HS, VGA_VS, VGA_DE, ce_ovl, VGA_R, VGA_G,
   VGA_B}` for two frames after a few frames of lock-in.
   - Gotcha: `scandoubler.v` declares `vbo/vso/hbo` after their first use;
     iverilog needs them moved above the `Hq2x` instance (make a patched copy
     for the sim only; do not change the repo file).
2. **GHDL side** (`--std=08`): replay that dump through the stock
   `vga_recover_counters.vhd` + `video_overlay.vhd` + `vga_osm.vhd`
   (+ `ram_init.vhd`, package deps `M2M/QNICE/vhdl/tools.vhd`,
   `types_pkg.vhd`, `video_modes_pkg.vhd`). Stub the OSM VRAM with a
   1-clock-latency read returning attribute `0x0E` (yellow headline) on row 0,
   `0x8B` (inverse cyan cursor) on row 2, `0x0B` (cyan text) elsewhere, and
   character `0x41` ('A') everywhere. Log the per-clock RGB and histogram the
   colors during DE.
3. **For idea D**, continue the GHDL replay through `analog_pipeline.vhd`'s
   tail as described above.

The key past result to reproduce/trust: with the committed `main.vhd` grid,
the digital colors are clean and hsync period is a constant 21280 ns.

---

## 10. Pointers into the code

- `CORE/vhdl/main.vhd` — `video_ce_ovl_o` grid (the committed fix; `C_SD_LINE`,
  `video_sd_phase`).
- `M2M/vhdl/av_pipeline/analog_pipeline.vhd` — VGA out: `vga_data_enable`
  (blanking black-out), `phase_shift_vga_signals` (falling-edge VDAC phase),
  `vdac_syncn_o <= '0'`, `vdac_blankn_o <= '1'`, `vdac_clk_o <= video_clk_i`.
  Sync polarity is passed straight through (positive from `lcd.v`).
- `M2M/vhdl/av_pipeline/vga_recover_counters.vhd` — re-registers video + syncs
  on `video_ce_ovl_o`; this is why the grid phase matters.
- `M2M/vhdl/controllers/MiSTer/scandoubler.v` — the line-doubler; output line
  = 2128 video-clocks, output pixel = 5 clocks (`pixsz2`).
- `CORE/GameBoy/lcd.v` — native GB timing (H = 160, HFP = 103, HS = 32,
  HBP = 130, HTOTAL = 425 input pixels; 4256 video-clocks per line via the one
  stretched pixel; positive hsync/vsync). Do not edit; it is the proven core.
- `CORE/vhdl/mega65.vhd` — `qnice_scandoubler_o` / `qnice_retro15kHz_o` /
  `qnice_csync_o` selection (which mode drives which path).

## 11. What NOT to do

- Do not touch the 15 kHz branch or the HDMI path; both are confirmed good on
  hardware. The remaining fix is Standard-mode-only.
- Do not edit `CORE/GameBoy/lcd.v`.
- Do not re-derive that the digital pixels are clean; that is already
  established (section 4). Start at the analog boundary and the monitor.
- Do not ship a signal-distorting hack to satisfy one monitor before running
  the section-7 localization test.
