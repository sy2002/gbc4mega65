----------------------------------------------------------------------------------
-- Game Boy and Game Boy Color for MEGA65 (gbc4mega65)
--
-- Wrapper for the MiSTer core that runs exclusively in the core's clock domain
--
-- This is the actual Game Boy machine: gb.v plus the MiSTer modules speedcontrol
-- (clock enables, pause) and lcd.v (LCD capture, double buffering, color grading,
-- 59.7275 Hz video timing) plus the gbc4mega65 Memory Bank Controller (mbc.sv)
-- and the MEGA65 keyboard/joystick to Game Boy joypad adapter (keyboard.vhd).
--
-- The video output is the classic Super Game Boy screen geometry: the 160x144
-- Game Boy picture centered in a 256x224 active area with a black border, at the
-- authentic frame rate of 59.7275 Hz. The border makes the M2M on-screen-menu
-- usable on the analog output. HDMI Aspect Ratio offers either the pure
-- 160x144 picture at the original LCD's physical 10:9 aspect ratio (5x integer
-- scaling at 720p) or the complete canvas in a TV-style 4:3 region.
--
-- This machine is based on Gameboy_MiSTer
-- Powered by MiSTer2MEGA65
-- MEGA65 port done by sy2002 in 2021 - 2026 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity main is
   generic (
      G_VDNUM                 : natural                     -- amount of virtual drives
   );
   port (
      clk_main_i              : in  std_logic;              -- 33.554432 MHz Game Boy machine clock
      clk_video_i             : in  std_logic;              -- 67.108864 MHz video clock (2x main)
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- Game Boy configuration (see also gbc4mega65's OSM in config.vhd)
      gb_color_i              : in  std_logic;              -- 0 = Game Boy Classic, 1 = Game Boy Color
      gb_joy_map_i            : in  std_logic_vector(1 downto 0); -- joystick mapping, see keyboard.vhd
      gb_saturated_colors_i   : in  std_logic;              -- 1 = fully saturated GBC colors, 0 = LCD emulation

      -- Master volume from the OSM "Volume" slider (5% steps): 0..20 = 0%..100%.
      -- Applied as a perceptual, loudness-linear attenuation to the audio output
      -- below, so it affects the HDMI and the analog audio path equally.
      audio_volume_i          : in  natural range 0 to 20;

      -- 1 = the analog output runs in one of the retro 15 kHz modes (no scandoubler);
      -- needed to generate the correct overlay clock enable, see p_ce_ovl below
      video_retro15kHz_i      : in  std_logic;

      -- Cartridge state: the Game Boy is held in reset while no cartridge is loaded
      -- and during cartridge loading
      cart_loaded_i           : in  std_logic;
      cart_loading_i          : in  std_logic;

      -- Cartridge header flags, set by the QNICE firmware/hardware while loading a cartridge
      -- https://gbdev.io/pandocs/The_Cartridge_Header.html
      cart_cgb_flag_i         : in  std_logic_vector(7 downto 0);  -- header byte 0x0143
      cart_mbc_type_i         : in  std_logic_vector(7 downto 0);  -- header byte 0x0147
      cart_rom_size_i         : in  std_logic_vector(7 downto 0);  -- header byte 0x0148
      cart_ram_size_i         : in  std_logic_vector(7 downto 0);  -- header byte 0x0149

      -- Game Boy Color BIOS interface (4 KB dual clock RAM in mega65.vhd)
      gbc_bios_addr_o         : out std_logic_vector(11 downto 0);
      gbc_bios_data_i         : in  std_logic_vector(7 downto 0);

      -- Cartridge ROM interface (1 MB dual clock RAM in mega65.vhd)
      cartrom_addr_o          : out std_logic_vector(22 downto 0);
      cartrom_rd_o            : out std_logic;
      cartrom_data_i          : in  std_logic_vector(7 downto 0);

      -- Cartridge RAM interface (128 KB RAM in mega65.vhd)
      cartram_addr_o          : out std_logic_vector(16 downto 0);
      cartram_rd_o            : out std_logic;
      cartram_wr_o            : out std_logic;
      cartram_data_o          : out std_logic_vector(7 downto 0);
      cartram_data_i          : in  std_logic_vector(7 downto 0);

      -- Video output: 256x224 @ 59.7275 Hz in the clk_video_i domain
      video_ce_o              : out std_logic;
      video_ce_ovl_o          : out std_logic;
      video_red_o             : out std_logic_vector(7 downto 0);
      video_green_o           : out std_logic_vector(7 downto 0);
      video_blue_o            : out std_logic_vector(7 downto 0);
      video_vs_o              : out std_logic;
      video_hs_o              : out std_logic;
      video_hblank_o          : out std_logic;
      video_vblank_o          : out std_logic;

      -- Audio output (Signed PCM)
      audio_left_o            : out signed(15 downto 0);
      audio_right_o           : out signed(15 downto 0);

      -- M2M Keyboard interface
      kb_key_num_i            : in  integer range 0 to 79;    -- cycles through all MEGA65 keys
      kb_key_pressed_n_i      : in  std_logic;                -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks and paddles/mouse/potentiometers
      joy_1_up_n_i            : in  std_logic;
      joy_1_down_n_i          : in  std_logic;
      joy_1_left_n_i          : in  std_logic;
      joy_1_right_n_i         : in  std_logic;
      joy_1_fire_n_i          : in  std_logic;

      joy_2_up_n_i            : in  std_logic;
      joy_2_down_n_i          : in  std_logic;
      joy_2_left_n_i          : in  std_logic;
      joy_2_right_n_i         : in  std_logic;
      joy_2_fire_n_i          : in  std_logic;

      pot1_x_i                : in  std_logic_vector(7 downto 0);
      pot1_y_i                : in  std_logic_vector(7 downto 0);
      pot2_x_i                : in  std_logic_vector(7 downto 0);
      pot2_y_i                : in  std_logic_vector(7 downto 0)
   );
end entity main;

architecture synthesis of main is

   -- Game Boy reset: QNICE/framework reset, or no cartridge loaded yet, or a cartridge
   -- is currently being loaded (the original gbc4mega65 held the Game Boy in reset in
   -- exactly these situations)
   signal main_gb_reset          : std_logic;

   -- speed control
   signal main_sc_ce             : std_logic;
   signal main_sc_ce_2x          : std_logic;
   signal main_hdma_on           : std_logic;

   -- cartridge bus of gb.v
   signal main_cart_addr         : std_logic_vector(15 downto 0);
   signal main_cart_rd           : std_logic;
   signal main_cart_wr           : std_logic;
   signal main_cart_do           : std_logic_vector(7 downto 0);
   signal main_cart_di           : std_logic_vector(7 downto 0);

   -- current cartridge is a dedicated Game Boy Color game
   signal main_isGBC_game        : std_logic;

   -- LCD interface between gb.v and lcd_wrapper.v
   signal main_lcd_clkena        : std_logic;
   signal main_lcd_data          : std_logic_vector(14 downto 0);
   signal main_lcd_mode          : std_logic_vector(1 downto 0);
   signal main_lcd_on            : std_logic;
   signal main_lcd_vsync         : std_logic;

   -- joypad: p54 selects matrix entry and data contains either
   -- the direction keys or the other buttons
   signal main_joypad_p54        : std_logic_vector(1 downto 0);
   signal main_joypad_data       : std_logic_vector(3 downto 0);

   -- joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
   -- (both MEGA65 joystick ports are merged; the framework already debounced them)
   signal main_m65_joystick      : std_logic_vector(4 downto 0);

   -- audio: gbc_snd delivers 16-bit UNSIGNED audio that is not centered around 0x8000
   signal main_audio_l           : std_logic_vector(15 downto 0);
   signal main_audio_r           : std_logic_vector(15 downto 0);

   -- Master-volume LUT (used by audio_volume_proc): perceptual, loudness-linear
   -- attenuation for the OSM "Volume" slider. Each 5% step is a 5 percentage-point
   -- change in *perceived* loudness, so 50% sounds half as loud as 100% (-10 dB),
   -- 25% a quarter (-20 dB), and so on. The amplitude gain therefore follows
   -- (percent/100)^1.661, stored here as unsigned Q15 (0x8000 = gain 1.0).
   -- Index 0 = 0% (mute) .. index 20 = 100% (bit-transparent).
   type vol_lut_t is array (0 to 20) of unsigned(15 downto 0);
   constant C_VOL_LUT : vol_lut_t := (
      x"0000", x"00E2", x"02CB", x"057B", x"08D6", x"0CCD", x"1154", x"1662",
      x"1BF1", x"21FB", x"287A", x"2F6C", x"36CB", x"3E96", x"46C8", x"4F60",
      x"585C", x"61B8", x"6B73", x"758C", x"8000");

   -- video clock domain
   signal video_ce_pix           : std_logic;
   signal video_ce_pix_dly       : std_logic_vector(6 downto 0) := (others => '0');
   signal video_retro15kHz       : std_logic_vector(1 downto 0) := (others => '0');

   -- overlay grid for the scandoubled (Standard VGA) mode: locked to the scandoubled
   -- output line, see the comment at p_ce_ovl below. One lcd.v line is 4256 video
   -- clocks, so one scandoubled output line is half of that.
   constant C_SD_LINE            : natural := 4256 / 2;
   signal video_sd_cnt           : natural range 0 to C_SD_LINE - 1 := 0;
   signal video_sd_phase         : natural range 0 to 4 := 0;
   signal video_hblank_dly       : std_logic := '1';

   -- constants necessary due to Verilog in VHDL embedding
   -- otherwise, when wiring constants directly to the entity, then Vivado throws an error
   constant c_fast_boot          : std_logic := '0';
   constant c_joystick           : std_logic_vector(7 downto 0) := x"FF";
   constant c_dummy_0            : std_logic := '0';
   constant c_dummy_2bit_0       : std_logic_vector(1 downto 0) := (others => '0');
   constant c_dummy_8bit_0       : std_logic_vector(7 downto 0) := (others => '0');
   constant c_dummy_64bit_0      : std_logic_vector(63 downto 0) := (others => '0');
   constant c_dummy_129bit_0     : std_logic_vector(128 downto 0) := (others => '0');

begin

   -- Hold the Game Boy in reset while the framework requests it, while no cartridge is
   -- loaded, and while a cartridge is being loaded. Releasing the reset after a
   -- successful load (re)starts the boot ROM with the freshly loaded cartridge.
   main_gb_reset <= reset_soft_i or reset_hard_i or cart_loading_i or (not cart_loaded_i);

   -- Cartridge header: CGB flag values 0x80 (GBC enhanced) and 0xC0 (GBC only) mark a
   -- dedicated Game Boy Color game
   main_isGBC_game <= '1' when cart_cgb_flag_i = x"80" or cart_cgb_flag_i = x"C0" else '0';

   -- The actual machine (GB/GBC core)
   gameboy : entity work.gb
      port map (
         reset                   => main_gb_reset,          -- input

         clk_sys                 => clk_main_i,             -- input
         ce                      => main_sc_ce,             -- input
         ce_2x                   => main_sc_ce_2x,          -- input

         fast_boot               => c_fast_boot,            -- input
         joystick                => c_joystick,             -- input (unused inside gb.v)
         isGBC                   => gb_color_i,             -- input
         isGBC_game              => main_isGBC_game,        -- input

         -- Cartridge interface: Connects with the Memory Bank Controller (MBC)
         cart_addr               => main_cart_addr,         -- output
         cart_rd                 => main_cart_rd,           -- output
         cart_wr                 => main_cart_wr,           -- output
         cart_di                 => main_cart_di,           -- input
         cart_do                 => main_cart_do,           -- output

         -- Game Boy BIOS interface
         gbc_bios_addr           => gbc_bios_addr_o,        -- output
         gbc_bios_do             => gbc_bios_data_i,        -- input

         -- audio: unsigned value that can be sampled
         audio_l                 => main_audio_l,           -- output
         audio_r                 => main_audio_r,           -- output

         -- lcd interface
         lcd_clkena              => main_lcd_clkena,        -- output
         lcd_data                => main_lcd_data,          -- output
         lcd_mode                => main_lcd_mode,          -- output
         lcd_on                  => main_lcd_on,            -- output
         lcd_vsync               => main_lcd_vsync,         -- output

         joy_p54                 => main_joypad_p54,        -- output
         joy_din                 => main_joypad_data,       -- input

         speed                   => open,   --GBC           -- output
         HDMA_on                 => main_hdma_on,           -- output

         -- cheating/game code engine: not supported on MEGA65
         gg_reset                => main_gb_reset,          -- input
         gg_en                   => c_dummy_0,              -- input
         gg_code                 => c_dummy_129bit_0,       -- input
         gg_available            => open,                   -- output

         -- serial port: not supported on MEGA65
         sc_int_clock2           => open,                   -- output
         serial_clk_in           => c_dummy_0,              -- input
         serial_clk_out          => open,                   -- output
         serial_data_in          => c_dummy_0,              -- input
         serial_data_out         => open,                   -- output

         -- MiSTer's save states & rewind feature: not supported on MEGA65
         cart_ram_size           => c_dummy_8bit_0,         -- input
         save_state              => c_dummy_0,              -- input
         load_state              => c_dummy_0,              -- input
         savestate_number        => c_dummy_2bit_0,         -- input
         sleep_savestate         => open,                   -- output
         state_loaded            => open,                   -- output
         SaveStateExt_Din        => open,                   -- output
         SaveStateExt_Adr        => open,                   -- output
         SaveStateExt_wren       => open,                   -- output
         SaveStateExt_rst        => open,                   -- output
         SaveStateExt_Dout       => c_dummy_64bit_0,        -- input
         SaveStateExt_load       => open,                   -- output
         Savestate_CRAMAddr      => open,                   -- output
         Savestate_CRAMRWrEn     => open,                   -- output
         Savestate_CRAMWriteData => open,                   -- output
         Savestate_CRAMReadData  => c_dummy_8bit_0,         -- input
         SAVE_out_Din            => open,                   -- output
         SAVE_out_Dout           => c_dummy_64bit_0,        -- input
         SAVE_out_Adr            => open,                   -- output
         SAVE_out_rnw            => open,                   -- output
         SAVE_out_ena            => open,                   -- output
         SAVE_out_done           => c_dummy_0,              -- input
         rewind_on               => c_dummy_0,              -- input
         rewind_active           => c_dummy_0               -- input
      ); -- gameboy : entity work.gb

   -- Speed control is mainly a clock divider and it also manages pause/resume
   gb_clk_ctrl : entity work.speedcontrol
      port map (
         clk_sys                 => clk_main_i,
         pause                   => pause_i,
         speedup                 => '0',
         cart_act                => main_cart_rd or main_cart_wr,
         HDMA_on                 => main_hdma_on,
         ce                      => main_sc_ce,
         ce_2x                   => main_sc_ce_2x,
         refresh                 => open,
         ff_on                   => open
      ); -- gb_clk_ctrl

   -- Memory Bank Controller (MBC)
   gb_mbc : entity work.mbc
      port map (
         -- Game Boy's clock and reset
         clk_sys                 => clk_main_i,             -- input
         ce_cpu2x                => main_sc_ce_2x,          -- input
         reset                   => main_gb_reset,          -- input

         -- Game Boy's cartridge interface
         cart_addr               => main_cart_addr,         -- input
         cart_rd                 => main_cart_rd,           -- input
         cart_wr                 => main_cart_wr,           -- input
         cart_do                 => main_cart_do,           -- input
         cart_di                 => main_cart_di,           -- output

         -- Cartridge ROM interface
         rom_addr                => cartrom_addr_o,         -- output
         rom_rd                  => cartrom_rd_o,           -- output
         rom_data                => cartrom_data_i,         -- input

         -- Cartridge RAM interface
         ram_addr                => cartram_addr_o,         -- output
         ram_rd                  => cartram_rd_o,           -- output
         ram_wr                  => cartram_wr_o,           -- output
         ram_do                  => cartram_data_i,         -- input
         ram_di                  => cartram_data_o,         -- output

         -- Cartridge flags
         cart_mbc_type           => cart_mbc_type_i,        -- input
         cart_rom_size           => cart_rom_size_i,        -- input
         cart_ram_size           => cart_ram_size_i         -- input
      ); -- gb_mbc : entity work.mbc

   -- MiSTer's lcd.v (via lcd_wrapper.v): LCD capture, double buffering, DMG grayscale,
   -- GBC color grading and the 59.7275 Hz video timing generator; produces the 256x224
   -- active area with the Game Boy picture centered (SGB screen geometry, black border)
   i_lcd : entity work.lcd_wrapper
      port map (
         clk_sys                 => clk_main_i,
         ce                      => main_sc_ce,
         lcd_clkena              => main_lcd_clkena,
         lcd_vsync               => main_lcd_vsync,
         lcd_data                => main_lcd_data,
         lcd_mode                => main_lcd_mode,
         lcd_on                  => main_lcd_on,

         isGBC                   => gb_color_i,
         originalcolors          => gb_saturated_colors_i,

         clk_vid                 => clk_video_i,
         ce_pix                  => video_ce_pix,
         hs                      => video_hs_o,
         vs                      => video_vs_o,
         hbl                     => video_hblank_o,
         vbl                     => video_vblank_o,
         r                       => video_red_o,
         g                       => video_green_o,
         b                       => video_blue_o
      ); -- i_lcd

   -- video_ce_o: the core's native pixel clock enable (~6.71 MHz on the 67.1 MHz video clock)
   video_ce_o <= video_ce_pix;

   -- video_ce_ovl_o: pixel clock enable for the on-screen-menu overlay and for sampling
   -- the core's output on the analog output (the framework re-registers the video
   -- INCLUDING hsync/vsync on this enable in vga_recover_counters). The rate must be
   -- chosen such that the VGA_DX = 512 overlay ticks (globals.vhd) span exactly the
   -- visible picture, and the PHASE must be locked to the pixel grid of the video
   -- that is being sampled:
   --
   --   * Retro 15 kHz modes (no scandoubler): the video pixels change on lcd.v's
   --     1-of-10 pixel enable, so the overlay grid is built from phase-locked taps
   --     of that enable - 2x the native pixel rate (~13.42 MHz); the framework
   --     doubles the overlay rows in these modes.
   --   * Standard VGA (scandoubler on, the default): MiSTer's scandoubler locks its
   --     output pixels (5 clocks each) and its 2x-rate hsync to a free-running
   --     half-line counter that restarts at the falling edge of the INPUT hblank -
   --     4256/2 = 2128 clocks per output line. 2128 is not a multiple of 10, so a
   --     grid derived from lcd.v's pixel enable beats against the scandoubled video:
   --     the sampling phase rotates from output line to output line, which displaces
   --     alternating lines horizontally (visible as a comb/ripple pattern) and, much
   --     worse, quantizes the resampled hsync differently per line - the sync period
   --     then alternates by +/-40 ns and analog displays lose their lock/calibration
   --     (verified in simulation against video_mixer.sv with lcd.v-exact timing).
   --     Therefore this mode uses its own grid, locked to the same reference as the
   --     scandoubler output: a half-line counter restarted at the hblank falling
   --     edge, with 2 ticks per 5-clock output pixel -> 512 ticks per visible line.
   p_ce_ovl : process (clk_video_i)
   begin
      if rising_edge(clk_video_i) then
         video_ce_pix_dly <= video_ce_pix_dly(5 downto 0) & video_ce_pix;

         -- synchronize the quasi-static menu selection into the video clock domain
         video_retro15kHz <= video_retro15kHz(0) & video_retro15kHz_i;

         -- half-line counter locked to the scandoubler's output line schedule
         video_hblank_dly <= video_hblank_o;
         if (video_hblank_dly = '1' and video_hblank_o = '0') or video_sd_cnt = C_SD_LINE - 1 then
            video_sd_cnt   <= 0;
            video_sd_phase <= 0;
         else
            video_sd_cnt <= video_sd_cnt + 1;
            if video_sd_phase = 4 then
               video_sd_phase <= 0;
            else
               video_sd_phase <= video_sd_phase + 1;
            end if;
         end if;
      end if;
   end process;

   video_ce_ovl_o <= video_ce_pix or video_ce_pix_dly(4)
                        when video_retro15kHz(1) = '1' else          -- 2x: retro 15 kHz
                     '1' when video_sd_phase = 1 or video_sd_phase = 3 else -- scandoubled
                     '0';

   -- Convert the Game Boy's unsigned audio to M2M's signed PCM format and apply the
   -- OSM master-volume attenuation in one registered step.
   --
   -- Conversion: gbc_snd's output is unsigned and NOT centered around 0x8000 (the center
   -- drifts with the number of active voices), so we use a logical shift right by one -
   -- silence stays at level 0 and the maximum stays in the positive range. Do not use an
   -- arithmetic shift or a plain "minus 0x8000" conversion here: both lead to loud
   -- crackling (verified in the original gbc4mega65 with Dig Dug and Super Mario Land 1).
   --
   -- Volume: multiply the converted sample by the Q15 gain from C_VOL_LUT (audio_volume_i
   -- selects the slider step). The gain is always <= 1.0 so the result can never clip, and
   -- at 100% (0x8000) the multiply is bit-transparent (audio identical to the pre-volume
   -- core). Registered on clk_main_i so Vivado maps the products to pipelined DSP48
   -- slices; the one-cycle latency (~30 ns) is inaudible. This is the single point that
   -- feeds both the HDMI and the analog audio path, so the slider works on both outputs.
   audio_volume_proc : process (clk_main_i)
      variable conv_l : signed(15 downto 0);
      variable conv_r : signed(15 downto 0);
      variable gain   : signed(16 downto 0);
      variable prod_l : signed(32 downto 0);
      variable prod_r : signed(32 downto 0);
   begin
      if rising_edge(clk_main_i) then
         conv_l        := signed("0" & main_audio_l(15 downto 1));
         conv_r        := signed("0" & main_audio_r(15 downto 1));
         gain          := signed('0' & std_logic_vector(C_VOL_LUT(audio_volume_i)));
         prod_l        := conv_l * gain;         -- signed(16) * signed(17) = signed(33)
         prod_r        := conv_r * gain;
         audio_left_o  <= prod_l(30 downto 15);  -- arithmetic >>15: back to signed(16)
         audio_right_o <= prod_r(30 downto 15);
      end if;
   end process audio_volume_proc;

   -- joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
   -- both MEGA65 joystick ports work in parallel (exactly like the original gbc4mega65)
   main_m65_joystick <= (joy_1_fire_n_i  and joy_2_fire_n_i)  &
                        (joy_1_up_n_i    and joy_2_up_n_i)    &
                        (joy_1_down_n_i  and joy_2_down_n_i)  &
                        (joy_1_left_n_i  and joy_2_left_n_i)  &
                        (joy_1_right_n_i and joy_2_right_n_i);

   -- MEGA65 keyboard and joystick to Game Boy joypad adapter
   i_keyboard : entity work.keyboard
      port map (
         clk_main_i              => clk_main_i,

         -- Interface to the MEGA65 keyboard
         key_num_i               => kb_key_num_i,
         key_pressed_n_i         => kb_key_pressed_n_i,

         -- MEGA65 joysticks (both ports merged) and the joystick mapping mode
         joystick_i              => main_m65_joystick,
         joy_map_i               => gb_joy_map_i,

         -- Game Boy joypad interface
         joy_p54_i               => main_joypad_p54,
         joy_din_o               => main_joypad_data
      ); -- i_keyboard

end architecture synthesis;
