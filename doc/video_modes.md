# Video modes and filters

The HDMI and the VGA output of the core are simultaneously active, so you
can even use both at the same time.

## Picture geometry

The Game Boy's 160x144 LCD picture is shown centered with a black border in
a 256x224 active area - the classic Super Game Boy geometry - at the
authentic refresh rate of 59.7275 Hz.

## HDMI modes

The Game Boy runs at 59.7275 Hz, so all HDMI modes are members of the 60 Hz
family. Choose your mode in the "HDMI" submenu of the on-screen-menu:

* **16:9 720p 60 Hz** (default)
* **640x480 60 Hz** (4:3)
* **720x480 59.94 Hz** (4:3)
* **800x600 60 Hz** (4:3)

### HDMI: Flicker-free

"HDMI: Flicker-free" is switched on by default. It gently dithers the core
between a 59.73 Hz and a 60.05 Hz leg so that the average is exactly the
HDMI rate. This removes the slowly wandering tear line that otherwise
appears when a 59.7275 Hz core meets a 60 Hz display. One exception:
the 800x600 mode runs at 60.32 Hz, which is above what the faster leg can
reach, so a slow tear line can remain in this mode.

Advice: Switch "HDMI: Flicker-free" off when you primarily use a CRT on the
VGA output - the speed dithering is visible on analog.

### HDMI: Zoom-in

"HDMI: Zoom-in" is switched off by default, so you see the picture centered
in the Super-Game-Boy-style 256x224 frame. Switch it on to crop the black
border so that the 160x144 Game Boy picture fills the height of the screen:
at 720p this results in a razor-sharp 5x integer scaling - the way the
classic V0.8 release of this core displayed the picture.

## HDMI filters

The "HDMI Filter" submenu offers eight options:

* **No Filter**: nearest neighbor
* **Sharp Bilinear**
* **Bicubic**
* **Smooth**
* **Lanczos** (default)
* **Scanlines**
* **CRT (S-Video)**
* **CRT (Composite)**

The last five options (from "Smooth" on) are polyphase filters. The two CRT
options simulate
the horizontal smear of S-Video and Composite cabling combined with
scanlines.

## VGA modes

The "VGA" submenu offers three modes:

* **Standard** (default): 31 kHz scandoubled output for VGA monitors.
* **15 kHz with HS/VS**: for retro CRT monitors.
* **15 kHz with CSYNC**: for retro CRT monitors; use CSYNC for RGB/SCART
  cables.
