----------------------------------------------------------------------------------
-- Game Boy and Game Boy Color for MEGA65 (gbc4mega65)
--
-- MEGA65 main file that contains the whole machine
--
-- This machine is based on Gameboy_MiSTer
-- Powered by MiSTer2MEGA65
-- MEGA65 port done by sy2002 in 2021 - 2026 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.globals.all;
use work.types_pkg.all;
use work.video_modes_pkg.all;

library xpm;
use xpm.vcomponents.all;

entity MEGA65_Core is
generic (
   G_BOARD : string                                         -- Which platform are we running on.
);
port (
   --------------------------------------------------------------------------------------------------------
   -- QNICE Clock Domain
   --------------------------------------------------------------------------------------------------------

   -- Get QNICE clock from the framework: for the vdrives as well as for RAMs and ROMs
   qnice_clk_i             : in  std_logic;
   qnice_rst_i             : in  std_logic;

   -- Video and audio mode control
   qnice_dvi_o             : out std_logic;              -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_video_mode_o      : out video_mode_type;        -- Defined in video_modes_pkg.vhd
   qnice_osm_cfg_scaling_o : out std_logic_vector(8 downto 0);
   qnice_scandoubler_o     : out std_logic;              -- 0 = no scandoubler, 1 = scandoubler
   qnice_audio_mute_o      : out std_logic;
   qnice_audio_filter_o    : out std_logic;
   qnice_zoom_crop_o       : out std_logic;
   qnice_hdmi_view_size_o  : out std_logic_vector(1 downto 0) := (others => '0');
   qnice_ascal_mode_o      : out std_logic_vector(1 downto 0);
   qnice_ascal_polyphase_o : out std_logic;
   qnice_ascal_triplebuf_o : out std_logic;
   qnice_retro15kHz_o      : out std_logic;              -- 0 = normal frequency, 1 = retro 15 kHz frequency
   qnice_csync_o           : out std_logic;              -- 0 = normal HS/VS, 1 = Composite Sync

   -- Flip joystick ports
   qnice_flip_joyports_o   : out std_logic;

   -- On-Screen-Menu selections
   qnice_osm_control_i     : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register
   qnice_gp_reg_i          : in  std_logic_vector(255 downto 0);

   -- Core-specific devices
   qnice_dev_id_i          : in  std_logic_vector(15 downto 0);
   qnice_dev_addr_i        : in  std_logic_vector(27 downto 0);
   qnice_dev_data_i        : in  std_logic_vector(15 downto 0);
   qnice_dev_data_o        : out std_logic_vector(15 downto 0);
   qnice_dev_ce_i          : in  std_logic;
   qnice_dev_we_i          : in  std_logic;
   qnice_dev_wait_o        : out std_logic;

   --------------------------------------------------------------------------------------------------------
   -- HyperRAM Clock Domain
   --------------------------------------------------------------------------------------------------------

   hr_clk_i                : in  std_logic;
   hr_rst_i                : in  std_logic;
   hr_core_write_o         : out std_logic;
   hr_core_read_o          : out std_logic;
   hr_core_address_o       : out std_logic_vector(31 downto 0);
   hr_core_writedata_o     : out std_logic_vector(15 downto 0);
   hr_core_byteenable_o    : out std_logic_vector( 1 downto 0);
   hr_core_burstcount_o    : out std_logic_vector( 7 downto 0);
   hr_core_readdata_i      : in  std_logic_vector(15 downto 0);
   hr_core_readdatavalid_i : in  std_logic;
   hr_core_waitrequest_i   : in  std_logic;
   hr_high_i               : in  std_logic;  -- Core is too fast
   hr_low_i                : in  std_logic;  -- Core is too slow

   --------------------------------------------------------------------------------------------------------
   -- Video Clock Domain
   --------------------------------------------------------------------------------------------------------

   video_clk_o             : out std_logic;
   video_rst_o             : out std_logic;
   video_ce_o              : out std_logic;
   video_ce_ovl_o          : out std_logic;
   video_red_o             : out std_logic_vector(7 downto 0);
   video_green_o           : out std_logic_vector(7 downto 0);
   video_blue_o            : out std_logic_vector(7 downto 0);
   video_vs_o              : out std_logic;
   video_hs_o              : out std_logic;
   video_hblank_o          : out std_logic;
   video_vblank_o          : out std_logic;

   --------------------------------------------------------------------------------------------------------
   -- Core Clock Domain
   --------------------------------------------------------------------------------------------------------

   clk_i                   : in  std_logic;              -- 100 MHz clock

   -- Share clock and reset with the framework
   main_clk_o              : out std_logic;              -- CORE's 33.554432 MHz clock
   main_rst_o              : out std_logic;              -- CORE's reset, synchronized

   -- M2M's reset manager provides 2 signals:
   --    m2m:   Reset the whole machine: Core and Framework
   --    core:  Only reset the core
   main_reset_m2m_i        : in  std_logic;
   main_reset_core_i       : in  std_logic;

   main_pause_core_i       : in  std_logic;

   -- On-Screen-Menu selections
   main_osm_control_i      : in  std_logic_vector(255 downto 0);

   -- QNICE general purpose register converted to main clock domain
   main_qnice_gp_reg_i     : in  std_logic_vector(255 downto 0);

   -- Audio output (Signed PCM)
   main_audio_left_o       : out signed(15 downto 0);
   main_audio_right_o      : out signed(15 downto 0);

   -- M2M Keyboard interface (incl. power led and drive led)
   main_kb_key_num_i       : in  integer range 0 to 79;  -- cycles through all MEGA65 keys
   main_kb_key_pressed_n_i : in  std_logic;              -- low active: debounced feedback: is kb_key_num_i pressed right now?
   main_power_led_o        : out std_logic;
   main_power_led_col_o    : out std_logic_vector(23 downto 0);
   main_drive_led_o        : out std_logic;
   main_drive_led_col_o    : out std_logic_vector(23 downto 0);

   -- Joysticks and paddles input
   main_joy_1_up_n_i       : in  std_logic;
   main_joy_1_down_n_i     : in  std_logic;
   main_joy_1_left_n_i     : in  std_logic;
   main_joy_1_right_n_i    : in  std_logic;
   main_joy_1_fire_n_i     : in  std_logic;
   main_joy_1_up_n_o       : out std_logic;
   main_joy_1_down_n_o     : out std_logic;
   main_joy_1_left_n_o     : out std_logic;
   main_joy_1_right_n_o    : out std_logic;
   main_joy_1_fire_n_o     : out std_logic;
   main_joy_2_up_n_i       : in  std_logic;
   main_joy_2_down_n_i     : in  std_logic;
   main_joy_2_left_n_i     : in  std_logic;
   main_joy_2_right_n_i    : in  std_logic;
   main_joy_2_fire_n_i     : in  std_logic;
   main_joy_2_up_n_o       : out std_logic;
   main_joy_2_down_n_o     : out std_logic;
   main_joy_2_left_n_o     : out std_logic;
   main_joy_2_right_n_o    : out std_logic;
   main_joy_2_fire_n_o     : out std_logic;

   main_pot1_x_i           : in  std_logic_vector(7 downto 0);
   main_pot1_y_i           : in  std_logic_vector(7 downto 0);
   main_pot2_x_i           : in  std_logic_vector(7 downto 0);
   main_pot2_y_i           : in  std_logic_vector(7 downto 0);
   main_rtc_i              : in  std_logic_vector(64 downto 0);

   -- CBM-488/IEC serial port
   iec_reset_n_o           : out std_logic;
   iec_atn_n_o             : out std_logic;
   iec_clk_en_o            : out std_logic;
   iec_clk_n_i             : in  std_logic;
   iec_clk_n_o             : out std_logic;
   iec_data_en_o           : out std_logic;
   iec_data_n_i            : in  std_logic;
   iec_data_n_o            : out std_logic;
   iec_srq_en_o            : out std_logic;
   iec_srq_n_i             : in  std_logic;
   iec_srq_n_o             : out std_logic;

   -- C64 Expansion Port (aka Cartridge Port)
   cart_en_o               : out std_logic;  -- Enable port, active high
   cart_phi2_o             : out std_logic;
   cart_dotclock_o         : out std_logic;
   cart_dma_i              : in  std_logic;
   cart_reset_oe_o         : out std_logic;
   cart_reset_i            : in  std_logic;
   cart_reset_o            : out std_logic;
   cart_game_oe_o          : out std_logic;
   cart_game_i             : in  std_logic;
   cart_game_o             : out std_logic;
   cart_exrom_oe_o         : out std_logic;
   cart_exrom_i            : in  std_logic;
   cart_exrom_o            : out std_logic;
   cart_nmi_oe_o           : out std_logic;
   cart_nmi_i              : in  std_logic;
   cart_nmi_o              : out std_logic;
   cart_irq_oe_o           : out std_logic;
   cart_irq_i              : in  std_logic;
   cart_irq_o              : out std_logic;
   cart_roml_oe_o          : out std_logic;
   cart_roml_i             : in  std_logic;
   cart_roml_o             : out std_logic;
   cart_romh_oe_o          : out std_logic;
   cart_romh_i             : in  std_logic;
   cart_romh_o             : out std_logic;
   cart_ctrl_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_ba_i               : in  std_logic;
   cart_rw_i               : in  std_logic;
   cart_io1_i              : in  std_logic;
   cart_io2_i              : in  std_logic;
   cart_ba_o               : out std_logic;
   cart_rw_o               : out std_logic;
   cart_io1_o              : out std_logic;
   cart_io2_o              : out std_logic;
   cart_addr_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_a_i                : in  unsigned(15 downto 0);
   cart_a_o                : out unsigned(15 downto 0);
   cart_data_oe_o          : out std_logic; -- 0 : tristate (i.e. input), 1 : output
   cart_d_i                : in  unsigned( 7 downto 0);
   cart_d_o                : out unsigned( 7 downto 0)
);
end entity MEGA65_Core;

architecture synthesis of MEGA65_Core is

---------------------------------------------------------------------------------------------
-- Clocks and active high reset signals for each clock domain
---------------------------------------------------------------------------------------------

signal main_clk               : std_logic;               -- Game Boy core clock: 33.554432 MHz
signal main_rst               : std_logic;
signal video_clk              : std_logic;               -- lcd.v video clock: 67.108864 MHz
signal video_rst              : std_logic;

---------------------------------------------------------------------------------------------
-- On-Screen-Menu bit positions: zero-based line numbers in config.vhd's OPTM_ITEMS
--
-- ALL C_MENU_* constants below are additionally scraped by CORE/m2m-rom/make_rom.sh into
-- the auto-generated osm_const.asm (as GBC_OSM_*), so the firmware never hardcodes menu
-- line numbers. Keep them single-line for the awk scraper and keep them in sync with
-- config.vhd's OPTM_ITEMS!
---------------------------------------------------------------------------------------------

constant C_MENU_GB_CLASSIC    : natural := 6;
constant C_MENU_GB_COLOR      : natural := 7;
constant C_MENU_COL_LCDEMU    : natural := 11;
constant C_MENU_COL_SATURATED : natural := 12;
constant C_MENU_JOY_STD_A     : natural := 17;
constant C_MENU_JOY_STD_B     : natural := 18;
constant C_MENU_JOY_UP_A      : natural := 19;
constant C_MENU_JOY_UP_B      : natural := 20;
constant C_MENU_ASSIST_OFF    : natural := 23;
constant C_MENU_ASSIST_SOFT   : natural := 24;
constant C_MENU_ASSIST_FULL   : natural := 25;
constant C_MENU_HDMI_720P_60  : natural := 31;
constant C_MENU_HDMI_640_60   : natural := 32;
constant C_MENU_HDMI_480_5994 : natural := 33;
constant C_MENU_HDMI_800_60   : natural := 34;
constant C_MENU_HDMI_FF       : natural := 36;
constant C_MENU_HDMI_HANDHELD_SMALL  : natural := 40;
constant C_MENU_HDMI_HANDHELD_MEDIUM : natural := 41;
constant C_MENU_HDMI_HANDHELD_FULL   : natural := 42;
constant C_MENU_HDMI_TV              : natural := 43;
constant C_MENU_HDMI_FLT_NO_FILTER     : natural := 49;
constant C_MENU_HDMI_FLT_SHARP         : natural := 50;
constant C_MENU_HDMI_FLT_BICUBIC       : natural := 51;
constant C_MENU_HDMI_FLT_SMOOTH        : natural := 52;
constant C_MENU_HDMI_FLT_LANCZOS       : natural := 53;
constant C_MENU_HDMI_FLT_SCANLINES     : natural := 54;
constant C_MENU_HDMI_FLT_CRT_SVIDEO    : natural := 55;
constant C_MENU_HDMI_FLT_CRT_COMPOSITE : natural := 56;
constant C_MENU_VGA_STD       : natural := 62;
constant C_MENU_VGA_15KHZHSVS : natural := 66;
constant C_MENU_VGA_15KHZCS   : natural := 67;
constant C_MENU_IMPROVE_AUDIO : natural := 110;

-- OSM Scaling radio (AExp pattern): line 73 (100%, the default) maps to bit 0 of
-- the 9-bit slice and line 81 (50%) maps to bit 8; the framework decodes the
-- one-hot vector with first_nonzero_bit (M2M/vhdl/av_pipeline/av_pipeline.vhd)
subtype C_MENU_OSM_SCALING is natural range 81 downto 73;

-- Volume submenu (master volume slider, 5% steps): a 21-way radio group decoded
-- into main_volume (see volume_decode_proc below) and applied as a perceptual
-- attenuation in main.vhd (C_VOL_LUT). Line 87 (100%, the default) is
-- C_MENU_VOLUME'low, line 107 (0%/mute) is C_MENU_VOLUME'high. Like
-- C_MENU_OSM_SCALING this is HDL-only and is deliberately not scraped into the
-- firmware (the make_rom.sh awk scraper matches "constant C_MENU_", not subtypes).
subtype C_MENU_VOLUME is natural range 107 downto 87;

---------------------------------------------------------------------------------------------
-- main_clk (MiSTer core's clock)
---------------------------------------------------------------------------------------------

-- Game Boy configuration from the on-screen-menu
signal main_gb_joy_map        : std_logic_vector(1 downto 0);
signal main_gb_jump_assist    : std_logic_vector(1 downto 0);

-- OSM "Volume" slider step: 0 = 0%/mute .. 20 = 100% (5% each), decoded from the
-- C_MENU_VOLUME radio group and applied as an attenuation in main.vhd
signal main_volume            : natural range 0 to 20;

-- Cartridge state and header flags after clock domain crossing
signal main_cart_loaded       : std_logic;
signal main_cart_loading      : std_logic;
signal main_cart_cgb_flag     : std_logic_vector(7 downto 0);
signal main_cart_mbc_type     : std_logic_vector(7 downto 0);
signal main_cart_rom_size     : std_logic_vector(7 downto 0);
signal main_cart_ram_size     : std_logic_vector(7 downto 0);

-- Game Boy Color BIOS interface between main.vhd and the BIOS RAM
signal main_bios_addr         : std_logic_vector(11 downto 0);
signal main_bios_data         : std_logic_vector(7 downto 0);

-- Cartridge ROM interface between main.vhd (MBC) and the cartridge RAM
signal main_cartrom_addr      : std_logic_vector(22 downto 0);
signal main_cartrom_rd        : std_logic;
signal main_cartrom_data      : std_logic_vector(7 downto 0);

-- Cartridge RAM interface between main.vhd (MBC) and the cartridge RAM
signal main_cartram_addr      : std_logic_vector(16 downto 0);
signal main_cartram_rd        : std_logic;
signal main_cartram_wr        : std_logic;
signal main_cartram_data_to   : std_logic_vector(7 downto 0);
signal main_cartram_data_from : std_logic_vector(7 downto 0);

---------------------------------------------------------------------------------------------
-- qnice_clk
---------------------------------------------------------------------------------------------

-- CRT/ROM device control and status register protocol, see M2M/rom/sysdef.asm:
-- the register block is located at 4k window 0xFFFF of the device
constant C_CRTROM_CSR_WINDOW  : std_logic_vector(15 downto 0) := x"FFFF";
constant C_CRTROM_CSR_STATUS  : std_logic_vector(11 downto 0) := x"000";
constant C_CRTROM_CSR_FS_LO   : std_logic_vector(11 downto 0) := x"001";
constant C_CRTROM_CSR_FS_HI   : std_logic_vector(11 downto 0) := x"002";
constant C_CRTROM_CSR_PARSEST : std_logic_vector(11 downto 0) := x"010";
constant C_CRTROM_CSR_PARSEE1 : std_logic_vector(11 downto 0) := x"011";

constant C_CRTROM_ST_IDLE     : std_logic_vector(15 downto 0) := x"0000";
constant C_CRTROM_ST_LDNG     : std_logic_vector(15 downto 0) := x"0001";
constant C_CRTROM_ST_ERR      : std_logic_vector(15 downto 0) := x"0002";
constant C_CRTROM_ST_OK       : std_logic_vector(15 downto 0) := x"0003";

constant C_CRTROM_PT_IDLE     : std_logic_vector(15 downto 0) := x"0000";
constant C_CRTROM_PT_OK       : std_logic_vector(15 downto 0) := x"0002";

-- Cartridge header byte offsets, see https://gbdev.io/pandocs/The_Cartridge_Header.html
constant C_CART_HDR_CGB       : std_logic_vector(19 downto 0) := x"00143";
constant C_CART_HDR_SGB       : std_logic_vector(19 downto 0) := x"00146";
constant C_CART_HDR_MBC       : std_logic_vector(19 downto 0) := x"00147";
constant C_CART_HDR_ROM_SIZE  : std_logic_vector(19 downto 0) := x"00148";
constant C_CART_HDR_RAM_SIZE  : std_logic_vector(19 downto 0) := x"00149";
constant C_CART_HDR_OLDLIC    : std_logic_vector(19 downto 0) := x"0014B";

-- Cartridge device: state, registers and RAM wiring
signal qnice_cart_csr_status  : std_logic_vector(15 downto 0);
signal qnice_cart_fs_lo       : std_logic_vector(15 downto 0);
signal qnice_cart_fs_hi       : std_logic_vector(15 downto 0);
signal qnice_cart_loaded      : std_logic;
signal qnice_cart_loading     : std_logic;    -- data is being streamed into the cartridge RAM
signal qnice_cart_data_we     : std_logic;    -- write to the cartridge RAM (data windows)
signal qnice_cart_csr_we      : std_logic;    -- write to the CSR register block

-- Cartridge header flags, snooped while the Shell streams the file into the device
signal qnice_cf_cgb           : std_logic_vector(7 downto 0);
signal qnice_cf_sgb           : std_logic_vector(7 downto 0);
signal qnice_cf_mbc           : std_logic_vector(7 downto 0);
signal qnice_cf_rom_size      : std_logic_vector(7 downto 0);
signal qnice_cf_ram_size      : std_logic_vector(7 downto 0);
signal qnice_cf_oldlicensee   : std_logic_vector(7 downto 0);

-- BIOS device
signal qnice_bios_we          : std_logic;

---------------------------------------------------------------------------------------------
-- hr_clk (HyperRAM clock domain)
---------------------------------------------------------------------------------------------

-- HDMI flicker-free: the core-speed select for clk.vhd, driven by the ascal over/underflow
-- feedback (hr_high_i/hr_low_i, already in the hr_clk domain -> no CDC), and the
-- flicker-free ON/OFF menu bit synchronized from the core clock domain. Power-up = native.
signal hr_core_speed          : unsigned(1 downto 0) := "00";
signal hr_hdmi_ff             : std_logic;

begin

   -- The Game Boy core does not use HyperRAM: the cartridge stays in BRAM
   hr_core_write_o      <= '0';
   hr_core_read_o       <= '0';
   hr_core_address_o    <= (others => '0');
   hr_core_writedata_o  <= (others => '0');
   hr_core_byteenable_o <= (others => '0');
   hr_core_burstcount_o <= (others => '0');

   -- Tristate all expansion port drivers that we can directly control
   cart_ctrl_oe_o       <= '0';
   cart_addr_oe_o       <= '0';
   cart_data_oe_o       <= '0';

   -- Due to a bug in the R5/R6 boards, the cartridge port needs to be enabled for joystick port 2 to work
   cart_en_o            <= '1';

   cart_reset_oe_o      <= '0';
   cart_game_oe_o       <= '0';
   cart_exrom_oe_o      <= '0';
   cart_nmi_oe_o        <= '0';
   cart_irq_oe_o        <= '0';
   cart_roml_oe_o       <= '0';
   cart_romh_oe_o       <= '0';

   -- Default values for all signals
   cart_phi2_o          <= '0';
   cart_reset_o         <= '1';
   cart_dotclock_o      <= '0';
   cart_game_o          <= '1';
   cart_exrom_o         <= '1';
   cart_nmi_o           <= '1';
   cart_irq_o           <= '1';
   cart_roml_o          <= '0';
   cart_romh_o          <= '0';
   cart_ba_o            <= '0';
   cart_rw_o            <= '0';
   cart_io1_o           <= '0';
   cart_io2_o           <= '0';
   cart_a_o             <= (others => '0');
   cart_d_o             <= (others => '0');

   -- The IEC port is not used by the Game Boy core
   iec_reset_n_o        <= '1';
   iec_atn_n_o          <= '1';
   iec_clk_en_o         <= '0';
   iec_clk_n_o          <= '1';
   iec_data_en_o        <= '0';
   iec_data_n_o         <= '1';
   iec_srq_en_o         <= '0';
   iec_srq_n_o          <= '1';

   main_joy_1_up_n_o    <= '1';
   main_joy_1_down_n_o  <= '1';
   main_joy_1_left_n_o  <= '1';
   main_joy_1_right_n_o <= '1';
   main_joy_1_fire_n_o  <= '1';
   main_joy_2_up_n_o    <= '1';
   main_joy_2_down_n_o  <= '1';
   main_joy_2_left_n_o  <= '1';
   main_joy_2_right_n_o <= '1';
   main_joy_2_fire_n_o  <= '1';

   -- MMCME2_ADV clock generators: 33.554432 MHz main clock and 67.108864 MHz video clock,
   -- plus the HDMI flicker-free "fast" twins selected by hr_core_speed (see clk.vhd)
   clk_gen : entity work.clk
      port map (
         sys_clk_i         => clk_i,           -- expects 100 MHz
         core_speed_i      => hr_core_speed,   -- "00"=native, "01"=fast (HDMI flicker-free)
         main_clk_o        => main_clk,        -- Game Boy core clock: 33.554432 MHz
         main_rst_o        => main_rst,        -- CORE's reset, synchronized
         video_clk_o       => video_clk,       -- video clock: 67.108864 MHz
         video_rst_o       => video_rst        -- video reset, synchronized
      ); -- clk_gen

   main_clk_o  <= main_clk;
   main_rst_o  <= main_rst;
   video_clk_o <= video_clk;
   video_rst_o <= video_rst;

   ---------------------------------------------------------------------------------------------
   -- main_clk (MiSTer core's clock)
   ---------------------------------------------------------------------------------------------

   -- MEGA65's power led: By default, it is on and glows green when the MEGA65 is powered on.
   -- We switch it to blue when a long reset is detected and as long as the user keeps pressing the preset button
   main_power_led_o     <= '1';
   main_power_led_col_o <= x"0000FF" when main_reset_m2m_i else x"00FF00";

   -- The Game Boy core does not use the drive led
   main_drive_led_o     <= '0';
   main_drive_led_col_o <= x"00FF00";

   -- Joystick mapping mode: the four radio buttons of the Joystick Mode menu
   -- encoded into the 2-bit mapping code of keyboard.vhd (fall-through default
   -- is Standard, Fire=A so that an all-zero config file is safe)
   main_gb_joy_map <= "01" when main_osm_control_i(C_MENU_JOY_STD_B) = '1' else
                      "10" when main_osm_control_i(C_MENU_JOY_UP_A)  = '1' else
                      "11" when main_osm_control_i(C_MENU_JOY_UP_B)  = '1' else
                      "00";

   -- Jump & Run Improvements: the three radio buttons of the Joystick Mode submenu
   -- encoded into the 2-bit preset code of joystick_assist.vhd via main.vhd. The
   -- fall-through default is Soft - the standard selection (OPTM_G_STDSEL) - so that
   -- an all-zero config file is safe. Only effective in the Up=A and Up=B mappings
   -- (hard-gated in main.vhd).
   main_gb_jump_assist <= "00" when main_osm_control_i(C_MENU_ASSIST_OFF)  = '1' else
                          "10" when main_osm_control_i(C_MENU_ASSIST_FULL) = '1' else
                          "01";

   -- Master volume: the OSM "Volume" slider (C_MENU_VOLUME) is a 21-way radio group
   -- in 5% steps. Its lowest bit (C_MENU_VOLUME'low) is 100% and its highest bit is
   -- 0%, so translate the one-hot selection into a 0..20 step index (0 = 0%/mute,
   -- 20 = 100%). Default to 100% if nothing is (yet) selected, so an all-zero config
   -- file is safe. The perceptual attenuation itself is applied in main.vhd (C_VOL_LUT
   -- there), so it affects the HDMI and the analog audio output alike.
   volume_decode_proc : process (all)
   begin
      main_volume <= 20;                                        -- default 100%
      for b in C_MENU_VOLUME'low to C_MENU_VOLUME'high loop
         if main_osm_control_i(b) = '1' then
            main_volume <= C_MENU_VOLUME'high - b;              -- bit 87 -> 20 (100%) .. bit 107 -> 0 (0%)
         end if;
      end loop;
   end process volume_decode_proc;

   -- main.vhd contains the actual MiSTer core
   i_main : entity work.main
      generic map (
         G_VDNUM              => C_VDNUM
      )
      port map (
         clk_main_i           => main_clk,
         clk_video_i          => video_clk,
         reset_soft_i         => main_reset_core_i,
         reset_hard_i         => main_reset_m2m_i,
         pause_i              => main_pause_core_i,

         clk_main_speed_i     => CORE_CLK_SPEED,

         -- Game Boy configuration: fall-through defaults keep an all-zero config file safe:
         -- Game Boy Classic and fully saturated colors
         gb_color_i           => main_osm_control_i(C_MENU_GB_COLOR),
         gb_joy_map_i         => main_gb_joy_map,
         gb_jump_assist_i     => main_gb_jump_assist,
         gb_saturated_colors_i => not main_osm_control_i(C_MENU_COL_LCDEMU),

         -- Master volume (OSM "Volume" slider): 0..20 step index = 0%..100%
         audio_volume_i       => main_volume,

         -- the overlay clock enable depends on whether the scandoubler is active
         video_retro15kHz_i   => main_osm_control_i(C_MENU_VGA_15KHZHSVS) or
                                 main_osm_control_i(C_MENU_VGA_15KHZCS),

         -- Cartridge state and header flags
         cart_loaded_i        => main_cart_loaded,
         cart_loading_i       => main_cart_loading,
         cart_cgb_flag_i      => main_cart_cgb_flag,
         cart_mbc_type_i      => main_cart_mbc_type,
         cart_rom_size_i      => main_cart_rom_size,
         cart_ram_size_i      => main_cart_ram_size,

         -- Game Boy Color BIOS RAM
         gbc_bios_addr_o      => main_bios_addr,
         gbc_bios_data_i      => main_bios_data,

         -- Cartridge ROM interface (MBC)
         cartrom_addr_o       => main_cartrom_addr,
         cartrom_rd_o         => main_cartrom_rd,
         cartrom_data_i       => main_cartrom_data,

         -- Cartridge RAM interface (MBC)
         cartram_addr_o       => main_cartram_addr,
         cartram_rd_o         => main_cartram_rd,
         cartram_wr_o         => main_cartram_wr,
         cartram_data_o       => main_cartram_data_to,
         cartram_data_i       => main_cartram_data_from,

         -- Video output
         -- 256x224 @ 59.7275 Hz (the 160x144 Game Boy picture centered with a black
         -- border, Super Game Boy screen geometry), synchronized to video_clk
         video_ce_o           => video_ce_o,
         video_ce_ovl_o       => video_ce_ovl_o,
         video_red_o          => video_red_o,
         video_green_o        => video_green_o,
         video_blue_o         => video_blue_o,
         video_vs_o           => video_vs_o,
         video_hs_o           => video_hs_o,
         video_hblank_o       => video_hblank_o,
         video_vblank_o       => video_vblank_o,

         -- audio output (pcm format, signed values)
         audio_left_o         => main_audio_left_o,
         audio_right_o        => main_audio_right_o,

         -- M2M Keyboard interface
         kb_key_num_i         => main_kb_key_num_i,
         kb_key_pressed_n_i   => main_kb_key_pressed_n_i,

         -- MEGA65 joysticks and paddles/mouse/potentiometers
         joy_1_up_n_i         => main_joy_1_up_n_i ,
         joy_1_down_n_i       => main_joy_1_down_n_i,
         joy_1_left_n_i       => main_joy_1_left_n_i,
         joy_1_right_n_i      => main_joy_1_right_n_i,
         joy_1_fire_n_i       => main_joy_1_fire_n_i,

         joy_2_up_n_i         => main_joy_2_up_n_i,
         joy_2_down_n_i       => main_joy_2_down_n_i,
         joy_2_left_n_i       => main_joy_2_left_n_i,
         joy_2_right_n_i      => main_joy_2_right_n_i,
         joy_2_fire_n_i       => main_joy_2_fire_n_i,

         pot1_x_i             => main_pot1_x_i,
         pot1_y_i             => main_pot1_y_i,
         pot2_x_i             => main_pot2_x_i,
         pot2_y_i             => main_pot2_y_i
      ); -- i_main

   ---------------------------------------------------------------------------------------------
   -- Audio and video settings (QNICE clock domain)
   ---------------------------------------------------------------------------------------------

   -- The Game Boy is a 59.7275 Hz machine, so only 60 Hz family HDMI modes are offered.
   -- Fall-through default is 720p 60 Hz so that an all-zero config file is safe.
   qnice_video_mode_o <= C_VIDEO_SVGA_800_60   when qnice_osm_control_i(C_MENU_HDMI_800_60)   = '1' else
                         C_VIDEO_HDMI_720_5994 when qnice_osm_control_i(C_MENU_HDMI_480_5994) = '1' else
                         C_VIDEO_HDMI_640_60   when qnice_osm_control_i(C_MENU_HDMI_640_60)   = '1' else
                         C_VIDEO_HDMI_16_9_60;

   -- Use On-Screen-Menu selections to configure several audio and video settings
   -- Video and audio mode control
   qnice_dvi_o                <= '0';                                         -- 0=HDMI (with sound), 1=DVI (no sound)
   qnice_audio_mute_o         <= '0';                                         -- audio is not muted
   qnice_audio_filter_o       <= qnice_osm_control_i(C_MENU_IMPROVE_AUDIO);   -- 0 = raw audio, 1 = use filters from globals.vhd
   qnice_zoom_crop_o          <= qnice_osm_control_i(C_MENU_HDMI_HANDHELD_SMALL) or
                                 qnice_osm_control_i(C_MENU_HDMI_HANDHELD_MEDIUM) or
                                 qnice_osm_control_i(C_MENU_HDMI_HANDHELD_FULL);
   qnice_hdmi_view_size_o     <= "10" when qnice_osm_control_i(C_MENU_HDMI_HANDHELD_MEDIUM) = '1' else
                                 "00" when qnice_osm_control_i(C_MENU_HDMI_HANDHELD_FULL) = '1' else
                                 "01" when qnice_osm_control_i(C_MENU_HDMI_HANDHELD_SMALL) = '1' else
                                 "00"; -- TV-style ignores this selector; keep the neutral value

   -- VGA output modes, see also the VGA submenu in config.vhd:
   --    "Standard VGA":                      scandoubler on,  retro15kHz off, csync off
   --    "Retro 15 kHz with HSync and VSync": scandoubler off, retro15kHz on,  csync off
   --    "Retro 15 kHz with CSync":           scandoubler off, retro15kHz on,  csync on
   -- Fall-through default is Standard VGA (no 15 kHz bit set)
   qnice_scandoubler_o        <= (not qnice_osm_control_i(C_MENU_VGA_15KHZHSVS)) and
                                 (not qnice_osm_control_i(C_MENU_VGA_15KHZCS));
   qnice_retro15kHz_o         <= qnice_osm_control_i(C_MENU_VGA_15KHZHSVS) or
                                 qnice_osm_control_i(C_MENU_VGA_15KHZCS);
   qnice_csync_o              <= qnice_osm_control_i(C_MENU_VGA_15KHZCS);
   qnice_osm_cfg_scaling_o    <= qnice_osm_control_i(C_MENU_OSM_SCALING);

   -- ASCAL_USAGE = 1 (AUSE_CUSTOM) in config.vhd: the HDMI Filter menu is implemented by
   -- the QNICE firmware (LOAD_HDMI_FILTER in CORE/m2m-rom/m2m-rom.asm), which drives
   -- M2M$ASCAL_MODE and the polyphase coefficient RAM itself. These three signals are
   -- therefore ignored by the framework at runtime:
   qnice_ascal_mode_o         <= "00";
   qnice_ascal_polyphase_o    <= '0';
   qnice_ascal_triplebuf_o    <= '0';

   -- Flip joystick ports (i.e. the joystick in port 2 is used as joystick 1 and vice versa)
   -- Not needed by the Game Boy core: both joystick ports work in parallel
   qnice_flip_joyports_o      <= '0';

   ---------------------------------------------------------------------------------------------
   -- Core specific device handling (QNICE clock domain)
   --
   -- Two devices:
   --
   -- C_DEV_GB_CART (1 MB cartridge ROM): The Shell streams *.gb / *.gbc files byte by byte
   -- into the 4k windows 0x0000 .. 0x00FF and afterwards performs the CRT/ROM control and
   -- status register protocol at 4k window 0xFFFF (see HANDLE_CRTROM_M in
   -- M2M/rom/crts-and-roms.asm). While the file streams in, the device snoops the relevant
   -- cartridge header bytes. There is no dedicated hardware parser: all sanity checks happen
   -- before loading in the firmware (PREP_LOAD_IMAGE in CORE/m2m-rom/m2m-rom.asm), so the
   -- parser handshake immediately reports "OK".
   --
   -- C_DEV_GB_BIOS (4 KB Game Boy Color BIOS): Preloaded at synthesis with the Open Source
   -- SameBoy boot ROM; the Shell auto-load mechanism (C_CRTROMS_AUTO in globals.vhd)
   -- optionally overwrites it with cgb_boot.bin / cgb_bios.bin from the SD card. Auto-load
   -- does not use the CSR protocol, so the device is a plain memory window. Writes beyond
   -- the 4 KB of window 0 are ignored (over-long files are truncated, exactly like the
   -- original gbc4mega65 firmware did).
   ---------------------------------------------------------------------------------------------

   core_specific_devices : process(all)
   begin
      -- make sure that this is x"EEEE" by default and avoid a register here by having this default value
      qnice_dev_data_o     <= x"EEEE";
      qnice_dev_wait_o     <= '0';

      qnice_cart_data_we   <= '0';
      qnice_cart_csr_we    <= '0';
      qnice_bios_we        <= '0';

      case qnice_dev_id_i is

         -- 1 MB cartridge ROM incl. the CRT/ROM CSR protocol
         when C_DEV_GB_CART =>
            if qnice_dev_addr_i(27 downto 12) = C_CRTROM_CSR_WINDOW then
               -- the whole CSR window reads as zero by default so that the Shell reads
               -- an empty (zero-terminated) error string at CRTROM_CSR_ERR_STRT
               qnice_dev_data_o <= x"0000";
               case qnice_dev_addr_i(11 downto 0) is
                  when C_CRTROM_CSR_STATUS =>
                     qnice_cart_csr_we <= qnice_dev_ce_i and qnice_dev_we_i;
                     qnice_dev_data_o  <= qnice_cart_csr_status;
                  when C_CRTROM_CSR_FS_LO =>
                     qnice_cart_csr_we <= qnice_dev_ce_i and qnice_dev_we_i;
                     qnice_dev_data_o  <= qnice_cart_fs_lo;
                  when C_CRTROM_CSR_FS_HI =>
                     qnice_cart_csr_we <= qnice_dev_ce_i and qnice_dev_we_i;
                     qnice_dev_data_o  <= qnice_cart_fs_hi;
                  when C_CRTROM_CSR_PARSEST =>
                     -- no hardware parser: report OK as soon as the Shell set the status
                     -- to OK (all checks are done in the firmware before loading)
                     if qnice_cart_csr_status = C_CRTROM_ST_OK then
                        qnice_dev_data_o <= C_CRTROM_PT_OK;
                     else
                        qnice_dev_data_o <= C_CRTROM_PT_IDLE;
                     end if;
                  when C_CRTROM_CSR_PARSEE1 =>
                     qnice_dev_data_o <= x"0000";
                  when others => null;
               end case;
            elsif qnice_dev_addr_i(27 downto 20) = x"00" then
               -- data windows 0x0000 .. 0x00FF: 1 MB cartridge RAM, one byte per address.
               -- The windows are write-only from the QNICE side: the Shell only streams
               -- data in and never reads it back. Omitting the read-back keeps the huge
               -- 1 MB BRAM array out of the half-period QNICE read path (the falling-edge
               -- BRAM output would otherwise need to traverse 256 block RAMs plus the
               -- device mux within 10 ns - this exact path failed timing on R3).
               qnice_cart_data_we <= qnice_dev_ce_i and qnice_dev_we_i;
               qnice_dev_data_o   <= x"0000";
            end if;

         -- 4 KB Game Boy Color BIOS (write-only from the QNICE side, see above:
         -- the auto-loader only streams data in and never reads it back)
         when C_DEV_GB_BIOS =>
            if qnice_dev_addr_i(27 downto 12) = x"0000" then
               qnice_bios_we    <= qnice_dev_ce_i and qnice_dev_we_i;
               qnice_dev_data_o <= x"0000";
            end if;

         when others => null;
      end case;
   end process core_specific_devices;

   -- Cartridge device: CSR registers, header snooping and load state.
   -- QNICE reads/writes registers on the falling clock edge.
   qnice_cart_regs : process (qnice_clk_i)
   begin
      if falling_edge(qnice_clk_i) then
         -- CSR register writes by the Shell
         if qnice_cart_csr_we = '1' then
            case qnice_dev_addr_i(11 downto 0) is
               when C_CRTROM_CSR_STATUS =>
                  qnice_cart_csr_status <= qnice_dev_data_i;
                  -- a successful load ends the loading phase and marks the cartridge
                  -- as loaded (the Game Boy leaves the reset state and starts the game);
                  -- error/idle end the loading phase, too
                  if qnice_dev_data_i = C_CRTROM_ST_OK then
                     qnice_cart_loading <= '0';
                     qnice_cart_loaded  <= '1';
                  elsif qnice_dev_data_i /= C_CRTROM_ST_LDNG then
                     qnice_cart_loading <= '0';
                  end if;
               when C_CRTROM_CSR_FS_LO =>
                  qnice_cart_fs_lo <= qnice_dev_data_i;
               when C_CRTROM_CSR_FS_HI =>
                  qnice_cart_fs_hi <= qnice_dev_data_i;
               when others => null;
            end case;
         end if;

         -- Data streaming: as soon as the first byte of a new cartridge overwrites the
         -- BRAM, the previous cartridge is gone, so the Game Boy is held in reset from
         -- here until the Shell reports "OK". (If the firmware aborts before streaming -
         -- for example because the cartridge is too large - then nothing was overwritten
         -- and a currently running game keeps running.)
         if qnice_cart_data_we = '1' and qnice_cart_csr_status = C_CRTROM_ST_LDNG then
            qnice_cart_loading <= '1';

            -- snoop the cartridge header bytes
            case qnice_dev_addr_i(19 downto 0) is
               when C_CART_HDR_CGB      => qnice_cf_cgb         <= qnice_dev_data_i(7 downto 0);
               when C_CART_HDR_SGB      => qnice_cf_sgb         <= qnice_dev_data_i(7 downto 0);
               when C_CART_HDR_MBC      => qnice_cf_mbc         <= qnice_dev_data_i(7 downto 0);
               when C_CART_HDR_ROM_SIZE => qnice_cf_rom_size    <= qnice_dev_data_i(7 downto 0);
               when C_CART_HDR_RAM_SIZE => qnice_cf_ram_size    <= qnice_dev_data_i(7 downto 0);
               when C_CART_HDR_OLDLIC   => qnice_cf_oldlicensee <= qnice_dev_data_i(7 downto 0);
               when others => null;
            end case;
         end if;

         if qnice_rst_i = '1' then
            qnice_cart_csr_status <= C_CRTROM_ST_IDLE;
            qnice_cart_fs_lo      <= (others => '0');
            qnice_cart_fs_hi      <= (others => '0');
            qnice_cart_loaded     <= '0';
            qnice_cart_loading    <= '0';
            qnice_cf_cgb          <= (others => '0');
            qnice_cf_sgb          <= (others => '0');
            qnice_cf_mbc          <= (others => '0');
            qnice_cf_rom_size     <= (others => '0');
            qnice_cf_ram_size     <= (others => '0');
            qnice_cf_oldlicensee  <= (others => '0');
         end if;
      end if;
   end process qnice_cart_regs;

   ---------------------------------------------------------------------------------------------
   -- Dual Clocks: RAMs and ROMs
   ---------------------------------------------------------------------------------------------

   -- 1 MB cartridge ROM: the Game Boy expects that the RAM latches the address on cart_rd
   cartrom : entity work.dualport_2clk_ram
      generic map (
         ADDR_WIDTH        => 20,              -- 1 MB
         DATA_WIDTH        => 8,
         LATCH_ADDR_A      => true,
         FALLING_B         => true             -- QNICE reads/writes on the falling clock edge
      )
      port map (
         clock_a           => main_clk,
         address_a         => main_cartrom_addr(19 downto 0),
         do_latch_addr_a   => main_cartrom_rd,
         q_a               => main_cartrom_data,

         clock_b           => qnice_clk_i,
         address_b         => qnice_dev_addr_i(19 downto 0),
         data_b            => qnice_dev_data_i(7 downto 0),
         wren_b            => qnice_cart_data_we,
         q_b               => open
      ); -- cartrom

   -- 128 KB cartridge RAM
   -- Note: QNICE has no access, so battery-buffered savegames are not possible yet.
   -- This is the V1.0 status quo, exactly like the original gbc4mega65.
   cartram : entity work.dualport_2clk_ram
      generic map (
         ADDR_WIDTH        => 17,              -- 128 KB
         DATA_WIDTH        => 8
      )
      port map (
         clock_a           => main_clk,
         address_a         => main_cartram_addr,
         data_a            => main_cartram_data_to,
         wren_a            => main_cartram_wr,
         q_a               => main_cartram_data_from
      ); -- cartram

   -- 4 KB Game Boy Color BIOS, preloaded with the Open Source SameBoy boot ROM
   bios : entity work.dualport_2clk_ram
      generic map (
         ADDR_WIDTH        => 12,              -- 4 KB
         DATA_WIDTH        => 8,
         ROM_PRELOAD       => true,            -- load default ROM in case no other ROM is on the SD card
         ROM_FILE          => "../../BootROMs/cgb_boot.rom",
         FALLING_B         => true             -- QNICE reads/writes on the falling clock edge
      )
      port map (
         clock_a           => main_clk,
         address_a         => main_bios_addr,
         q_a               => main_bios_data,

         clock_b           => qnice_clk_i,
         address_b         => qnice_dev_addr_i(11 downto 0),
         data_b            => qnice_dev_data_i(7 downto 0),
         wren_b            => qnice_bios_we,
         q_b               => open
      ); -- bios

   ---------------------------------------------------------------------------------------------
   -- Clock Domain Crossings
   ---------------------------------------------------------------------------------------------

   -- Cartridge state and header flags: QNICE clock domain to core clock domain.
   -- These signals are stable while the Game Boy is running (they only change during
   -- cartridge loading, when the Game Boy is held in reset).
   i_cdc_qnice2main : xpm_cdc_array_single
      generic map (
         WIDTH => 34
      )
      port map (
         src_clk                => qnice_clk_i,
         src_in(0)              => qnice_cart_loaded,
         src_in(1)              => qnice_cart_loading,
         src_in(9 downto 2)     => qnice_cf_cgb,
         src_in(17 downto 10)   => qnice_cf_mbc,
         src_in(25 downto 18)   => qnice_cf_rom_size,
         src_in(33 downto 26)   => qnice_cf_ram_size,
         dest_clk               => main_clk,
         dest_out(0)            => main_cart_loaded,
         dest_out(1)            => main_cart_loading,
         dest_out(9 downto 2)   => main_cart_cgb_flag,
         dest_out(17 downto 10) => main_cart_mbc_type,
         dest_out(25 downto 18) => main_cart_rom_size,
         dest_out(33 downto 26) => main_cart_ram_size
      ); -- i_cdc_qnice2main

   ---------------------------------------------------------------------------------------------
   -- hr_clk (HyperRAM clock domain): HDMI flicker-free core-speed FSM
   --
   -- The ascal frame buffer feedback hr_high_i/hr_low_i dithers the core between the
   -- native (59.73 Hz) and the fast (60.05 Hz) clock leg, time-averaging the Game Boy
   -- to exactly the HDMI frame rate. See clk.vhd for the details.
   ---------------------------------------------------------------------------------------------

   p_flicker_fsm : process (hr_clk_i)
   begin
      if rising_edge(hr_clk_i) then
         if hr_low_i = '1' then      -- core too slow (write pointer lagging) ...
            hr_core_speed <= "01";   -- ... speed up: FAST twin (60.05 Hz, above 60)
         end if;
         if hr_high_i = '1' then     -- core too fast (write pointer leading) ...
            hr_core_speed <= "00";   -- ... slow down: NATIVE (59.73 Hz, below 60)
         end if;
         if hr_hdmi_ff = '0' then    -- flicker-free OFF ...
            hr_core_speed <= "00";   -- ... hold authentic native, no dither
         end if;
      end if;
   end process p_flicker_fsm;

   -- Flicker-free ON/OFF menu bit into the hr_clk domain. Toggling it live only changes the
   -- glitch-free mux select, so there is no core reset (identical to C64MEGA65's mechanism).
   i_cdc_hdmi_ff : entity work.cdc_stable
      generic map (
         G_DATA_SIZE    => 1,
         G_REGISTER_SRC => true
      )
      port map (
         src_clk_i     => main_clk,
         src_data_i(0) => main_osm_control_i(C_MENU_HDMI_FF),
         dst_clk_i     => hr_clk_i,
         dst_data_o(0) => hr_hdmi_ff
      ); -- i_cdc_hdmi_ff

end architecture synthesis;
