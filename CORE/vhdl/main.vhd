----------------------------------------------------------------------------------
-- MiSTer2MEGA65 Framework
--
-- Wrapper for the MiSTer core that runs exclusively in the core's clock domanin
--
-- MiSTer2MEGA65 done by sy2002 and MJoergen in 2022 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.video_modes_pkg.all;

entity main is
   generic (
      G_VDNUM                 : natural                     -- amount of virtual drives
   );
   port (
      clk_main_i              : in  std_logic;
      reset_soft_i            : in  std_logic;
      reset_hard_i            : in  std_logic;
      pause_i                 : in  std_logic;

      -- MiSTer core main clock speed:
      -- Make sure you pass very exact numbers here, because they are used for avoiding clock drift at derived clocks
      clk_main_speed_i        : in  natural;

      -- Video output
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

signal reset                  : std_logic;

-- speed control
signal sc_ce                  : std_logic;
signal sc_ce_2x               : std_logic;

-- cartridge signals
signal ext_bus_addr           : std_logic_vector(14 downto 0);
signal ext_bus_a15            : std_logic;
signal cart_rd                : std_logic;
signal cart_wr                : std_logic;
signal cart_do                : std_logic_vector(7 downto 0);
signal cart_di                : std_logic_vector(7 downto 0);
signal cart_oe                : std_logic;
signal nCS                    : std_logic;

-- Signed audio from the Game Boy
signal gb_audio_l_signed      : std_logic_vector(15 downto 0);
signal gb_audio_r_signed      : std_logic_vector(15 downto 0);

-- ROM loading signals
signal rom_cgb_load           : std_logic;
signal rom_dmg_load           : std_logic;
signal rom_sgb_load           : std_logic;
signal rom_wr                 : std_logic;
signal rom_addr               : std_logic;
signal rom_data               : std_logic;

-- LCD interface
signal lcd_clkena             : std_logic;
signal lcd_data               : std_logic_vector(14 downto 0);
signal lcd_mode               : std_logic_vector(1 downto 0);
signal lcd_on                 : std_logic;
signal lcd_vsync              : std_logic;

-- joypad: p54 selects matrix entry and data contains either
-- the direction keys or the other buttons
signal joypad_p54             : std_logic_vector(1 downto 0);
signal joypad_data            : std_logic_vector(3 downto 0);

-- joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
signal m65_joystick           : std_logic_vector(4 downto 0);

-- @TODO research
signal speed                  : std_logic;
signal DMA_on                 : std_logic;

-- constants necessary due to Verilog in VHDL embedding
-- otherwise, when wiring constants directly to the entity, then Vivado throws an error
constant c_fast_boot          : std_logic := '0';
constant c_joystick           : std_logic_vector(7 downto 0) := X"FF";
constant c_dummy_0            : std_logic := '0';
constant c_dummy_2bit_0       : std_logic_vector(1 downto 0) := (others => '0');
constant c_dummy_8bit_0       : std_logic_vector(7 downto 0) := (others => '0');
constant c_dummy_64bit_0      : std_logic_vector(63 downto 0) := (others => '0');
constant c_dummy_129bit_0     : std_logic_vector(128 downto 0) := (others => '0');

begin

   reset          <= reset_soft_i or reset_hard_i;
   
   audio_left_o   <= signed(gb_audio_l_signed);
   audio_right_o  <= signed(gb_audio_r_signed);
  
   i_gameboy : entity work.gb
      port map
      (
         reset                   => reset,                 -- input

         clk_sys                 => clk_main_i,            -- input
         ce                      => sc_ce,                 -- input
         ce_2x                   => sc_ce_2x,              -- input

         joystick                => c_joystick,            -- input
         
         isGBC                   => c_dummy_0,             -- input     @TODO
         real_cgb_boot           => c_dummy_0,             -- input     @TODO
	      isSGB                   => c_dummy_0,             -- input     @TODO
         boot_gba_en             => c_dummy_0,             -- input     @TODO
         fast_boot_en            => c_dummy_0,             -- input     @TODO
         megaduck                => c_dummy_0,             -- input     @TODO         

         -- Cartridge interface
         ext_bus_addr            => ext_bus_addr,          -- output
         ext_bus_a15             => ext_bus_a15,           -- output
         cart_rd                 => cart_rd,               -- output
         cart_wr                 => cart_wr,               -- output
         cart_di                 => cart_di,               -- input
         cart_do                 => cart_do,               -- output
         cart_oe                 => cart_oe,               -- output
         nCS                     => nCS,                   -- output

         -- ROM loading signals
	      cgb_boot_download       => rom_cgb_load,          -- input
	      dmg_boot_download       => rom_dmg_load,          -- input
	      sgb_boot_download       => rom_sgb_load,          -- input
	      ioctl_wr                => rom_wr,                -- input
	      ioctl_addr              => rom_addr,              -- input
	      ioctl_dout              => rom_data,              -- input

         -- audio: unsigned value that can be sampled
         audio_l                 => gb_audio_l_signed,     -- output
         audio_r                 => gb_audio_r_signed,     -- output

         -- lcd interface
         lcd_clkena              => lcd_clkena,            -- output
         lcd_data                => lcd_data,              -- output
         lcd_mode                => lcd_mode,              -- output
         lcd_on                  => lcd_on,                -- output
         lcd_vsync               => lcd_vsync,             -- output

         -- Game Boy's joypad and buttons
         joy_p54                 => joypad_p54,            -- output
         joy_din                 => joypad_data,           -- input

         speed                   => speed,  --GBC          -- output    @TODO
         DMA_on                  => DMA_on,                -- output    @TODO 
         
         -- cheating/game code engine: not supported on MEGA65
         gg_reset                => reset,                 -- input
         gg_en                   => c_dummy_0,             -- input
         gg_code                 => c_dummy_129bit_0,      -- input
         gg_available            => open,                  -- output

         -- serial port: not supported on MEGA65
         sc_int_clock2           => open,                  -- output
         serial_clk_in           => c_dummy_0,             -- input
         serial_clk_out          => open,                  -- output
         serial_data_in          => c_dummy_0,             -- input
         serial_data_out         => open,                  -- output

         -- MiSTer's save states & rewind feature: not supported on MEGA65
         increaseSSHeaderCount   => c_dummy_0,             -- input
         cart_ram_size           => c_dummy_8bit_0,        -- input
         save_state              => c_dummy_0,             -- input
         load_state              => c_dummy_0,             -- input
         savestate_number        => c_dummy_2bit_0,        -- input
         sleep_savestate         => open,                  -- output
         SaveStateExt_Din        => open,                  -- output
         SaveStateExt_Adr        => open,                  -- output
         SaveStateExt_wren       => open,                  -- output
         SaveStateExt_rst        => open,                  -- output
         SaveStateExt_Dout       => c_dummy_64bit_0,       -- input
         SaveStateExt_load       => open,                  -- output
         Savestate_CRAMAddr      => open,                  -- output
         Savestate_CRAMRWrEn     => open,                  -- output
         Savestate_CRAMWriteData => open,                  -- output
         Savestate_CRAMReadData  => c_dummy_8bit_0,        -- input
         SAVE_out_Din            => open,                  -- output
         SAVE_out_Dout           => c_dummy_64bit_0,       -- input
         SAVE_out_Adr            => open,                  -- output
         SAVE_out_rnw            => open,                  -- output
         SAVE_out_ena            => open,                  -- output
         SAVE_out_done           => c_dummy_0,             -- input
         rewind_on               => c_dummy_0,             -- input
         rewind_active           => c_dummy_0              -- input
      );

   -- Speed control is mainly a clock divider and it also manages pause/resume/fast-forward/etc.
   i_gb_clk_ctrl : entity work.speedcontrol
      port map
      (
         clk_sys                 => clk_main_i,
         pause                   => pause_i,
         speedup                 => '0',
         DMA_on                  => DMA_on,
         cart_act                => cart_rd or cart_wr,
         ce                      => sc_ce,
         ce_2x                   => sc_ce_2x,
         refresh                 => open,
         ff_on                   => open
      );
      
   -- MEGA65 keyboard and joystick controller
   -- m65_joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
   i_gamectrl : entity work.keyboard
      port map
      (
         -- M2M framework interface
         clk_main_i              => clk_main_i,         
         key_num_i               => kb_key_num_i,
         key_pressed_n_i         => kb_key_pressed_n_i,

         -- MEGA65 joystick input with variable mapping
         -- joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
         -- mapping: 00 = Standard, Fire=A
         --          01 = Standard, Fire=B
         --          10 = Up=A, Fire=B
         --          11 = Up=B, Fire=A
         joystick                => m65_joystick,
         joy_map                 => "00",                -- @TODO

         -- interface to the GBC's internal logic (low active)
         -- joypad:   
         -- Bit 3 - P13 Input Down  or Start
         -- Bit 2 - P12 Input Up    or Select
         -- Bit 1 - P11 Input Left  or Button B
         -- Bit 0 - P10 Input Right or Button A   
         p54                     => joypad_p54, -- "01" selects buttons and "10" selects direction keys
         joypad                  => joypad_data
      );

   m65_joystick <= (joy_1_fire_n_i  and joy_2_fire_n_i)  &
                   (joy_1_up_n_i    and joy_2_up_n_i)    &
                   (joy_1_down_n_i  and joy_2_down_n_i)  &
                   (joy_1_left_n_i  and joy_2_left_n_i)  &
                   (joy_1_right_n_i and joy_2_right_n_i);     

   -- On video_ce_o and video_ce_ovl_o: You have an important @TODO when porting a core:
   -- video_ce_o: You need to make sure that video_ce_o divides clk_main_i such that it transforms clk_main_i
   --             into the pixelclock of the core (means: the core's native output resolution pre-scandoubler)
   -- video_ce_ovl_o: Clock enable for the OSM overlay and for sampling the core's (retro) output in a way that
   --             it is displayed correctly on a "modern" analog input device: Make sure that video_ce_ovl_o
   --             transforms clk_main_o into the post-scandoubler pixelclock that is valid for the target
   --             resolution specified by VGA_DX/VGA_DY (globals.vhd)
   -- video_retro15kHz_o: '1', if the output from the core (post-scandoubler) in the retro 15 kHz analog RGB mode.
   --             Hint: Scandoubler off does not automatically mean retro 15 kHz on.
   video_ce_ovl_o <= video_ce_o;
   
   -------------------------------------------------------------------------------------------------
   -- TEMPORARY HARDCODED TETRIS CARTRIDGE MODELED AS A SIMPLE ROM 
   -------------------------------------------------------------------------------------------------

   itemp_cart : entity work.dualport_2clk_ram
      generic map (
         ADDR_WIDTH  => 16,
         DATA_WIDTH  => 8,
         ROM_PRELOAD => true,
         ROM_FILE    => "../../rom/tetris.rom"
      )
      port map (
         clock_a     => clk_main_i,
         address_a   => ext_bus_a15 & ext_bus_addr,
         data_a      => cart_di,
         wren_a      => cart_wr,
         q_a         => cart_do
     );

end architecture synthesis;

