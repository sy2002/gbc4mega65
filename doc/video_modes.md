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

**Important:** Switch "HDMI: Flicker-free" off when you use a VGA display
or an analog retro monitor. The dithering makes the sync frequency of the
analog output step slightly, which analog displays dislike.

### HDMI Aspect Ratio

The **Aspect Ratio** group offers three borderless Handheld LCD sizes plus the
complete television-style canvas:

* **Handheld LCD Small (10:9)** (default) is approximately as tall as the game
  content in TV-style mode. At 720p it occupies a centered 514x463 rectangle.
* **Handheld LCD Medium (10:9)** occupies 640x576 at 720p, so every Game Boy
  pixel becomes an exact 4x4 block.
* **Handheld LCD Full (10:9)** occupies 800x720 at 720p, so every Game Boy
  pixel becomes an exact 5x5 block and fills the display height.
* **TV-style (4:3)** retains the complete Super-Game-Boy-style 256x224 canvas
  and presents it as it would appear on a traditional television.

All three Handheld choices crop the black border and preserve the physical
10:9 aspect ratio of the original LCD. Their centered output sizes are:

| HDMI mode | Small | Medium | Full |
| --- | ---: | ---: | ---: |
| 1280x720 | 514x463 | 640x576 | 800x720 |
| 640x480 | 343x309 | 426x384 | 533x480 |
| 720x480 (physical 4:3) | 386x309 | 480x384 | 600x480 |
| 800x600 | 429x386 | 534x480 | 667x600 |

This setting changes only the HDMI output; all three analog VGA modes keep
their existing picture geometry.

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

* **Standard** (default): 31 kHz scandoubled output with PC-VGA sync pulses.
  The Game Boy pixels, picture geometry and authentic frame timing are unchanged.
* **15 kHz with HS/VS**: for retro CRT monitors.
* **15 kHz with CSYNC**: for retro CRT monitors; use CSYNC for RGB/SCART
  cables.

**Important:** Whenever a display is connected to the VGA output, switch
off "HDMI: Flicker-free" (see above).

## OSM Scaling

On the analog outputs the on-screen-menu covers almost the whole picture -
especially in the 15 kHz modes. The "OSM" submenu scales the menu in nine
steps from 100% down to 50% while the picture stays untouched. The menu is
rendered from a native 8x8 font, so it stays sharp at every step: 100%
shows the classic look and 50% is a pixel-perfect quarter-size menu. The
setting applies to the HDMI menu as well.
