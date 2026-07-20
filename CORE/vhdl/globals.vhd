----------------------------------------------------------------------------------
-- Game Boy and Game Boy Color for MEGA65 (gbc4mega65)
--
-- Global constants
--
-- This machine is based on Gameboy_MiSTer
-- Powered by MiSTer2MEGA65
-- MEGA65 port done by sy2002 in 2021 - 2026 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

library work;
use work.qnice_tools.all;
use work.video_modes_pkg.all;

package globals is

----------------------------------------------------------------------------------------------------------
-- QNICE Firmware
----------------------------------------------------------------------------------------------------------

-- QNICE Firmware: Use the regular QNICE "operating system" called "Monitor" while developing and
-- debugging the firmware/ROM itself. If you are using the M2M ROM (the "Shell") as provided by the
-- framework, then always use the release version of the M2M firmware: QNICE_FIRMWARE_M2M
--
-- Hint: You need to run QNICE/tools/make-toolchain.sh to obtain "monitor.rom" and
-- you need to run CORE/m2m-rom/make_rom.sh to obtain the .rom file
constant QNICE_FIRMWARE_MONITOR   : string  := "../../../M2M/QNICE/monitor/monitor.rom";    -- debug/development
constant QNICE_FIRMWARE_M2M       : string  := "../../../CORE/m2m-rom/m2m-rom.rom";         -- release

-- Select firmware here
constant QNICE_FIRMWARE           : string  := QNICE_FIRMWARE_M2M;

----------------------------------------------------------------------------------------------------------
-- Clock Speed(s)
--
-- Important: Make sure that you use very exact numbers - down to the actual Hertz - because some cores
-- rely on these exact numbers. By default M2M supports one core clock speed. In case you need more,
-- then add all the clocks speeds here by adding more constants.
----------------------------------------------------------------------------------------------------------

-- The MiSTer Game Boy machine expects 8x the clock speed of the original Game Boy:
-- 8 x 4.194304 MHz = 33.554432 MHz. This is the exact frequency that clk.vhd generates
-- on the native leg of the clock generator: 100 MHz x 56.375 / 6 / 28 = 33.556548 MHz
-- (+63 ppm vs. the ideal value; the HDMI flicker-free feature dithers to a slightly
-- higher average frequency while it is active, see clk.vhd).
constant CORE_CLK_SPEED       : natural := 33_556_548;

-- lcd.v runs at exactly twice the machine clock on both clock-generator legs.
-- This is the native-leg reference frequency used by static video profiles.
constant VIDEO_CLK_SPEED      : natural := 2 * CORE_CLK_SPEED;

-- System clock speed (crystal that is driving the FPGA) and QNICE clock speed
-- !!! Do not touch !!!
constant BOARD_CLK_SPEED      : natural := 100_000_000;
constant QNICE_CLK_SPEED      : natural := 50_000_000;   -- a change here has dependencies in qnice_globals.vhd

----------------------------------------------------------------------------------------------------------
-- Video Mode
----------------------------------------------------------------------------------------------------------

-- Rendering constants (in pixels)
--    VGA_*   size of the core's target output post scandoubler
--
-- The Game Boy outputs its 160x144 picture centered in a 256x224 active area (the classic
-- Super Game Boy screen geometry with a black border, see main.vhd), so the post-scandoubler
-- output is 512x448. This is also the raster for the on-screen-menu: 32x28 characters.
constant VGA_DX               : natural := 512;
constant VGA_DY               : natural := 448;

-- The native scandoubled raster is close enough to CEA 480p that some analog
-- VGA monitors select their fixed consumer-video processing path. Preserve all
-- source edge positions and the raster period, but present VESA-like sync pulse
-- widths and negative polarity so Standard mode is classified as PC VGA.
constant VGA_STD_SYNC         : vga_sync_reshaper_cfg_t :=
   make_vga_sync_reshaper_cfg(C_VGA_SYNC_DMT_640X480_60, VIDEO_CLK_SPEED);

--    FONT_*  size of one OSM character
-- The OSM canvas keeps its 16x16 logical cell (FONT_DX/DY), but the glyphs are
-- stored as a native 8x8 strike: vga_osm.vhd expands them to 2x2 blocks at 100%
-- OSM scaling and renders the smaller cell sizes with sharpened bilinear
-- coverage (the AExp OSM Scaling renderer, see doc/m2m/exceptions.md).
constant FONT_FILE            : string  := "../font/Anikki-8x8-m2m.rom";
constant FONT_DX              : natural := 16;
constant FONT_DY              : natural := 16;

-- Constants for the OSM screen memory
constant CHARS_DX             : natural := VGA_DX / FONT_DX;
constant CHARS_DY             : natural := VGA_DY / FONT_DY;
constant CHAR_MEM_SIZE        : natural := CHARS_DX * CHARS_DY;
constant VRAM_ADDR_WIDTH      : natural := f_log2(CHAR_MEM_SIZE);

----------------------------------------------------------------------------------------------------------
-- HyperRAM memory map (in units of 4kW)
--
-- The Game Boy core does not use HyperRAM: the cartridge stays in BRAM (1 MB maximum).
----------------------------------------------------------------------------------------------------------

constant C_HMAP_M2M           : std_logic_vector(15 downto 0) := x"0000";     -- Reserved for the M2M framework

----------------------------------------------------------------------------------------------------------
-- QNICE devices of the Game Boy core
--
-- Device numbers need to be >= 0x0100
----------------------------------------------------------------------------------------------------------

-- Cartridge ROM: 1 MB BRAM, filled by the Shell when the user loads a *.gb / *.gbc file.
-- The device implements the CRT/ROM control and status register protocol at 4k window 0xFFFF
-- (see M2M/rom/sysdef.asm, CRTROM_CSR_*) and snoops the cartridge header bytes while the
-- Shell streams the file (see mega65.vhd).
constant C_DEV_GB_CART        : std_logic_vector(15 downto 0) := x"0100";

-- Game Boy Color BIOS: 4 KB BRAM, preloaded at synthesis with the Open Source SameBoy
-- boot ROM (BootROMs/cgb_boot.rom) and optionally overwritten at boot time from the
-- SD card (see C_CRTROMS_AUTO below)
constant C_DEV_GB_BIOS        : std_logic_vector(15 downto 0) := x"0101";

----------------------------------------------------------------------------------------------------------
-- Virtual Drive Management System
--
-- The Game Boy core does not use virtual drives.
----------------------------------------------------------------------------------------------------------

type vd_buf_array is array(natural range <>) of std_logic_vector;
constant C_VDNUM              : natural := 0;
constant C_VD_DEVICE          : std_logic_vector(15 downto 0) := x"EEEE";
constant C_VD_BUFFER          : vd_buf_array := (x"EEEE", x"EEEE");

----------------------------------------------------------------------------------------------------------
-- System for handling simulated cartridges and ROM loaders
----------------------------------------------------------------------------------------------------------

type crtrom_buf_array is array(natural range<>) of std_logic_vector;
constant ENDSTR : character := character'val(0);

-- Cartridges and ROMs can be stored into QNICE devices, HyperRAM and SDRAM
constant C_CRTROMTYPE_DEVICE     : std_logic_vector(15 downto 0) := x"0000";
constant C_CRTROMTYPE_HYPERRAM   : std_logic_vector(15 downto 0) := x"0001";
constant C_CRTROMTYPE_SDRAM      : std_logic_vector(15 downto 0) := x"0002";           -- @TODO/RESERVED for future R4 boards

-- Types of automatically loaded ROMs:
-- If a mandatory file is missing, then the core outputs the missing file and goes fatal
constant C_CRTROMTYPE_MANDATORY  : std_logic_vector(15 downto 0) := x"0003";
constant C_CRTROMTYPE_OPTIONAL   : std_logic_vector(15 downto 0) := x"0004";

-- Manually loadable ROMs and cartridges as defined in config.vhd:
-- the "Cartridge:" menu item loads a Game Boy cartridge (*.gb / *.gbc) into the
-- cartridge ROM device. The firmware checks the cartridge before loading it
-- (see PREP_LOAD_IMAGE in CORE/m2m-rom/m2m-rom.asm): maximum size is 1 MB.
constant C_CRTROMS_MAN_NUM       : natural := 1;                                       -- amount of manually loadable ROMs and carts; maximum is 16
constant C_CRTROMS_MAN           : crtrom_buf_array := ( C_CRTROMTYPE_DEVICE, C_DEV_GB_CART,
                                                         x"EEEE");                     -- Always finish the array using x"EEEE"

-- Automatically loaded ROMs: These ROMs are loaded before the core starts.
--
-- The Game Boy Color BIOS is embedded in the bitstream (Open Source SameBoy boot ROM),
-- so both files are optional: for more authenticity, users can put the original
-- cgb_boot.bin into the /gbc folder of their SD card. The file name cgb_bios.bin is
-- also supported for backward compatibility with the original gbc4mega65 releases.
-- If both files are present, then cgb_bios.bin wins because it is loaded last.
constant GB_CGB_BOOT_NAME        : string := "/gbc/cgb_boot.bin" & ENDSTR;
constant GB_CGB_BIOS_NAME        : string := "/gbc/cgb_bios.bin" & ENDSTR;
constant GB_CGB_BOOT_START       : std_logic_vector(15 downto 0) := x"0000";
constant GB_CGB_BIOS_START       : std_logic_vector(15 downto 0) := std_logic_vector(to_unsigned(GB_CGB_BOOT_NAME'length, 16));

constant C_CRTROMS_AUTO_NUM      : natural := 2;                                       -- Amount of automatically loadable ROMs and carts, maximum is 16
constant C_CRTROMS_AUTO_NAMES    : string  := GB_CGB_BOOT_NAME & GB_CGB_BIOS_NAME;
constant C_CRTROMS_AUTO          : crtrom_buf_array := ( C_CRTROMTYPE_DEVICE, C_DEV_GB_BIOS, C_CRTROMTYPE_OPTIONAL, GB_CGB_BOOT_START,
                                                         C_CRTROMTYPE_DEVICE, C_DEV_GB_BIOS, C_CRTROMTYPE_OPTIONAL, GB_CGB_BIOS_START,
                                                         x"EEEE");                     -- Always finish the array using x"EEEE"

----------------------------------------------------------------------------------------------------------
-- Audio filters
--
-- If you use audio filters, then you need to copy the correct values from the MiSTer core
-- that you are porting: sys/sys_top.v
----------------------------------------------------------------------------------------------------------

-- The MiSTer Game Boy core uses the standard filter values of MiSTer's audio chain
-- (sys/sys_top.v defaults, same values that the C64 core uses)
constant audio_flt_rate : std_logic_vector(31 downto 0) := std_logic_vector(to_signed(7056000, 32));
constant audio_cx       : std_logic_vector(39 downto 0) := std_logic_vector(to_signed(4258969, 40));
constant audio_cx0      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(3, 8));
constant audio_cx1      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(2, 8));
constant audio_cx2      : std_logic_vector( 7 downto 0) := std_logic_vector(to_signed(1, 8));
constant audio_cy0      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed(-6216759, 24));
constant audio_cy1      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed( 6143386, 24));
constant audio_cy2      : std_logic_vector(23 downto 0) := std_logic_vector(to_signed(-2023767, 24));
constant audio_att      : std_logic_vector( 4 downto 0) := "00000";
constant audio_mix      : std_logic_vector( 1 downto 0) := "00"; -- 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

end package globals;
