----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- Main file that contains the whole machine.

-- It can be configured to fit the different MEGA65 models using generics:
-- The different FPGA RAM sizes of R2 and R3 lead to different maximum sizes for
-- the cartridge ROM and RAM. Have a look at m65_const.vhd to learn more.
--
-- Screen resolution:
-- VGA out runs at SVGA mode 800 x 600 @ 60 Hz. This is a compromise between
-- the optimal usage of screen real estate and compatibility to older CRTs
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.qnice_tools.all;

entity MEGA65_Core is
generic (
   CART_ROM_MAX   : integer;                       -- maximum size of cartridge ROM in bytes
   CART_RAM_MAX   : integer;                       -- ditto cartridge RAM
   SYS_ROM_MAX    : integer;                       -- maximum cartridge ROM mode, see m65_const.vhd for details
   SYS_RAM_MAX    : integer                        -- ditto cartridge RAM
);
port (
   CLK            : in std_logic;                  -- 100 MHz clock
   RESET_N        : in std_logic;                  -- CPU reset button

   -- serial communication (rxd, txd only; rts/cts are not available)
   -- 115.200 baud, 8-N-1
   UART_RXD       : in std_logic;                  -- receive data
   UART_TXD       : out std_logic;                 -- send data

   -- VGA
   VGA_RED        : out std_logic_vector(7 downto 0);
   VGA_GREEN      : out std_logic_vector(7 downto 0);
   VGA_BLUE       : out std_logic_vector(7 downto 0);
   VGA_HS         : out std_logic;
   VGA_VS         : out std_logic;

   -- VDAC
   vdac_clk       : out std_logic;
   vdac_sync_n    : out std_logic;
   vdac_blank_n   : out std_logic;

   -- MEGA65 smart keyboard controller
   kb_io0         : out std_logic;                 -- clock to keyboard
   kb_io1         : out std_logic;                 -- data output to keyboard
   kb_io2         : in std_logic;                  -- data input from keyboard

   -- SD Card
   SD_RESET       : out std_logic;
   SD_CLK         : out std_logic;
   SD_MOSI        : out std_logic;
   SD_MISO        : in std_logic;

   -- 3.5mm analog audio jack
   pwm_l          : out std_logic;
   pwm_r          : out std_logic;

   -- Joysticks
   joy_1_up_n     : in std_logic;
   joy_1_down_n   : in std_logic;
   joy_1_left_n   : in std_logic;
   joy_1_right_n  : in std_logic;
   joy_1_fire_n   : in std_logic;

   joy_2_up_n     : in std_logic;
   joy_2_down_n   : in std_logic;
   joy_2_left_n   : in std_logic;
   joy_2_right_n  : in std_logic;
   joy_2_fire_n   : in std_logic
);
end MEGA65_Core;

architecture beh of MEGA65_Core is

constant CART_ROM_WIDTH    : integer := f_log2(CART_ROM_MAX);
constant CART_RAM_WIDTH    : integer := f_log2(CART_RAM_MAX);

-- ROM options
constant GBC_ORG_ROM       : string := "../../rom/cgb_bios.rom";        -- Copyrighted original GBC ROM, not checked-in into official repo
constant GBC_OSS_ROM       : string := "../../BootROMs/cgb_boot.rom";   -- Alternative Open Source GBC ROM
constant DMG_ORG_ROM       : string := "../../rom/dmg_boot.rom";        -- Copyrighted original DMG ROM, not checked-in into official repo
constant DMG_OSS_ROM       : string := "../../BootROMs/dmg_boot.rom";   -- Alternative Open Source DMG ROM

constant GBC_ROM           : string := GBC_OSS_ROM;   -- use Open Source ROMs by default
constant DMG_ROM           : string := GBC_OSS_ROM;

-- clock speeds
constant GB_CLK_SPEED      : integer := 33_554_432;
constant QNICE_CLK_SPEED   : integer := 50_000_000;

-- rendering constants
constant GB_DX             : integer := 160;          -- Game Boy's X pixel resolution
constant GB_DY             : integer := 144;          -- ditto Y
constant VGA_DX            : integer := 800;          -- SVGA mode 800 x 600 @ 60 Hz
constant VGA_DY            : integer := 600;          -- ditto
constant GB_TO_VGA_SCALE   : integer := 4;            -- 160 x 144 => 4x => 640 x 576

-- clocks
signal main_clk            : std_logic;               -- Game Boy core main clock @ 33.554432 MHz
signal vga_pixelclk        : std_logic;               -- SVGA mode 800 x 600 @ 60 Hz: 40.00 MHz
signal qnice_clk           : std_logic;               -- QNICE main clock @ 50 MHz

-- VGA signals
signal vga_disp_en         : std_logic;
signal vga_col_raw         : integer range 0 to VGA_DX - 1;
signal vga_row_raw         : integer range 0 to VGA_DY - 1;
signal vga_col             : integer range 0 to VGA_DX - 1;
signal vga_row             : integer range 0 to VGA_DY - 1;
signal vga_col_next        : integer range 0 to VGA_DX - 1;
signal vga_row_next        : integer range 0 to VGA_DY - 1;
signal vga_hs_int          : std_logic;
signal vga_vs_int          : std_logic;
signal vga_address         : std_logic_vector(14 downto 0);

-- Audio signals
signal pcm_audio_left      : std_logic_vector(15 downto 0);
signal pcm_audio_right     : std_logic_vector(15 downto 0);

-- debounced signals for the reset button and the joysticks
signal dbnce_reset_n       : std_logic;
signal dbnce_joy1_up_n     : std_logic;
signal dbnce_joy1_down_n   : std_logic;
signal dbnce_joy1_left_n   : std_logic;
signal dbnce_joy1_right_n  : std_logic;
signal dbnce_joy1_fire_n   : std_logic;
signal dbnce_joy2_up_n     : std_logic;
signal dbnce_joy2_down_n   : std_logic;
signal dbnce_joy2_left_n   : std_logic;
signal dbnce_joy2_right_n  : std_logic;
signal dbnce_joy2_fire_n   : std_logic;

-- joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
signal m65_joystick        : std_logic_vector(4 downto 0);

-- Game Boy
signal gbc_bios_addr       : std_logic_vector(11 downto 0);
signal gbc_bios_data       : std_logic_vector(7 downto 0);

-- LCD interface
signal lcd_clkena          : std_logic;
signal lcd_data            : std_logic_vector(14 downto 0);
signal lcd_mode            : std_logic_vector(1 downto 0);
signal lcd_on              : std_logic;
signal lcd_vsync           : std_logic;
signal pixel_out_we        : std_logic;
signal pixel_out_ptr       : integer range 0 to (GB_DX * GB_DY) - 1 := 0;
signal pixel_out_data      : std_logic_vector(23 downto 0) := (others => '0');
signal frame_buffer_data   : std_logic_vector(23 downto 0);

 -- speed control
signal sc_ce               : std_logic;
signal sc_ce_2x            : std_logic;
signal HDMA_on             : std_logic;

-- cartridge signals
signal cart_addr           : std_logic_vector(15 downto 0);
signal cart_rd             : std_logic;
signal cart_wr             : std_logic;
signal cart_do             : std_logic_vector(7 downto 0);
signal cart_di             : std_logic_vector(7 downto 0);

-- cartridge flags
signal cart_cgb_flag       : std_logic_vector(7 downto 0);
signal cart_sgb_flag       : std_logic_vector(7 downto 0);
signal cart_mbc_type       : std_logic_vector(7 downto 0);
signal cart_rom_size       : std_logic_vector(7 downto 0);
signal cart_ram_size       : std_logic_vector(7 downto 0);
signal cart_old_licensee   : std_logic_vector(7 downto 0);

signal isGBC_Game          : boolean;     -- current cartridge is dedicated GBC game
signal isSGB_Game          : boolean;     -- current cartridge is dedicated SBC game

-- MBC signals
signal cartrom_addr        : std_logic_vector(22 downto 0);
signal cartrom_rd          : std_logic;
signal cartrom_data        : std_logic_vector(7 downto 0);
signal cartram_addr        : std_logic_vector(16 downto 0);
signal cartram_rd          : std_logic;
signal cartram_wr          : std_logic;
signal cartram_data_in     : std_logic_vector(7 downto 0);
signal cartram_data_out    : std_logic_vector(7 downto 0);

-- joypad: p54 selects matrix entry and data contains either
-- the direction keys or the other buttons
signal joypad_p54          : std_logic_vector(1 downto 0);
signal joypad_data         : std_logic_vector(3 downto 0);
signal joypad_data_i       : std_logic_vector(3 downto 0);

-- QNICE control signals (see also gbc.asm for more details)
signal qngbc_reset         : std_logic;
signal qngbc_pause         : std_logic;
signal qngbc_keyboard      : std_logic;
signal qngbc_joystick      : std_logic;
signal qngbc_color         : std_logic;
signal qngbc_joy_map       : std_logic_vector(1 downto 0);
signal qngbc_color_mode    : std_logic;

signal qngbc_bios_addr     : std_logic_vector(11 downto 0);
signal qngbc_bios_we       : std_logic;
signal qngbc_bios_data_in  : std_logic_vector(7 downto 0);
signal qngbc_bios_data_out : std_logic_vector(7 downto 0);
signal qngbc_cart_addr     : std_logic_vector(22 downto 0);
signal qngbc_cart_we       : std_logic;
signal qngbc_cart_data_in  : std_logic_vector(7 downto 0);
signal qngbc_cart_data_out : std_logic_vector(7 downto 0);
signal qngbc_osm_on        : std_logic;
signal qngbc_osm_rgb       : std_logic_vector(23 downto 0);
signal qngbc_keyb_matrix   : std_logic_vector(15 downto 0);

-- constants necessary due to Verilog in VHDL embedding
-- otherwise, when wiring constants directly to the entity, then Vivado throws an error
constant c_fast_boot       : std_logic := '0';
constant c_joystick        : std_logic_vector(7 downto 0) := X"FF";
constant c_dummy_0         : std_logic := '0';
constant c_dummy_2bit_0    : std_logic_vector(1 downto 0) := (others => '0');
constant c_dummy_8bit_0    : std_logic_vector(7 downto 0) := (others => '0');
constant c_dummy_64bit_0   : std_logic_vector(63 downto 0) := (others => '0');
constant c_dummy_129bit_0  : std_logic_vector(128 downto 0) := (others => '0');

signal i_reset             : std_logic;

begin

   -- MMCME2_ADV clock generators:
   --    Core clock:          33.554432 MHz
   --    Pixelclock:          34.96 MHz
   --    QNICE co-processor:  50 MHz
   clk_gen : entity work.clk_m
      port map
      (
         sys_clk_i         => CLK,
         gbmain_o          => main_clk,         -- Game Boy's 33.554432 MHz main clock
         qnice_o           => qnice_clk         -- QNICE's 50 MHz main clock
      );
   clk_pixel : entity work.clk_p
      port map
      (
         sys_clk_i         => CLK,
         pixelclk_o        => vga_pixelclk      -- 40.00 MHz pixelclock for SVGA mode 800 x 600 @ 60 Hz
      );

   -- TODO: Achieve timing closure also when using the debouncer
   --i_reset           <= not dbnce_reset_n;
   i_reset           <= not RESET_N; -- TODO/WARNING: might glitch


   ---------------------------------------------------------------------------------------------
   -- main_clk
   ---------------------------------------------------------------------------------------------

   -- The actual machine (GB/GBC core)
   gameboy : entity work.gb
      port map
      (
         reset                   => qngbc_reset,      -- input

         clk_sys                 => main_clk,         -- input
         ce                      => sc_ce,            -- input
         ce_2x                   => sc_ce_2x,         -- input

         fast_boot               => c_fast_boot,      -- input
         joystick                => c_joystick,       -- input
         isGBC                   => qngbc_color,      -- input
         isGBC_game              => isGBC_Game,       -- input

         -- Cartridge interface: Connects with the Memory Bank Controller (MBC)
         cart_addr               => cart_addr,        -- output
         cart_rd                 => cart_rd,          -- output
         cart_wr                 => cart_wr,          -- output
         cart_di                 => cart_di,          -- input
         cart_do                 => cart_do,          -- output

         -- Game Boy BIOS interface
         gbc_bios_addr           => gbc_bios_addr,    -- output
         gbc_bios_do             => gbc_bios_data,    -- input

         -- audio
         audio_l                 => pcm_audio_left,   -- output
         audio_r                 => pcm_audio_right,  -- output

         -- lcd interface
         lcd_clkena              => lcd_clkena,       -- output
         lcd_data                => lcd_data,         -- output
         lcd_mode                => lcd_mode,         -- output
         lcd_on                  => lcd_on,           -- output
         lcd_vsync               => lcd_vsync,        -- output

         joy_p54                 => joypad_p54,       -- output
         joy_din                 => joypad_data,      -- input

         speed                   => open,   --GBC     -- output
         HDMA_on                 => HDMA_on,          -- output

         -- cheating/game code engine: not supported on MEGA65
         gg_reset                => i_reset,          -- input
         gg_en                   => c_dummy_0,        -- input
         gg_code                 => c_dummy_129bit_0, -- input
         gg_available            => open,             -- output

         -- serial port: not supported on MEGA65
         sc_int_clock2           => open,             -- output
         serial_clk_in           => c_dummy_0,        -- input
         serial_clk_out          => open,             -- output
         serial_data_in          => c_dummy_0,        -- input
         serial_data_out         => open,             -- output

         -- MiSTer's save states & rewind feature: not supported on MEGA65
         cart_ram_size           => c_dummy_8bit_0,   -- input
         save_state              => c_dummy_0,        -- input
         load_state              => c_dummy_0,        -- input
         savestate_number        => c_dummy_2bit_0,   -- input
         sleep_savestate         => open,             -- output
         state_loaded            => open,             -- output
         SaveStateExt_Din        => open,             -- output
         SaveStateExt_Adr        => open,             -- output
         SaveStateExt_wren       => open,             -- output
         SaveStateExt_rst        => open,             -- output
         SaveStateExt_Dout       => c_dummy_64bit_0,  -- input
         SaveStateExt_load       => open,             -- output
         Savestate_CRAMAddr      => open,             -- output
         Savestate_CRAMRWrEn     => open,             -- output
         Savestate_CRAMWriteData => open,             -- output
         Savestate_CRAMReadData  => c_dummy_8bit_0,   -- input
         SAVE_out_Din            => open,             -- output
         SAVE_out_Dout           => c_dummy_64bit_0,  -- input
         SAVE_out_Adr            => open,             -- output
         SAVE_out_rnw            => open,             -- output
         SAVE_out_ena            => open,             -- output
         SAVE_out_done           => c_dummy_0,        -- input
         rewind_on               => c_dummy_0,        -- input
         rewind_active           => c_dummy_0         -- input
      );

   -- Speed control is mainly a clock divider and it also manages pause/resume/fast-forward/etc.
   gb_clk_ctrl : entity work.speedcontrol
      port map
      (
         clk_sys                 => main_clk,
         pause                   => qngbc_pause,
         speedup                 => '0',
         cart_act                => cart_rd or cart_wr,
         HDMA_on                 => HDMA_on,
         ce                      => sc_ce,
         ce_2x                   => sc_ce_2x,
         refresh                 => open,
         ff_on                   => open
      );

   -- Memory Bank Controller (MBC)
   gb_mbc : entity work.mbc
      port map
      (
         -- Game Boy's clock and reset
         clk_sys                 => main_clk,
         ce_cpu2x                => sc_ce_2x,
         reset                   => qngbc_reset,

         -- Game Boy's cartridge interface
         cart_addr               => cart_addr,
         cart_rd                 => cart_rd,
         cart_wr                 => cart_wr,
         cart_do                 => cart_do,
         cart_di                 => cart_di,

         -- Cartridge ROM interface
         rom_addr                => cartrom_addr,
         rom_rd                  => cartrom_rd,
         rom_data                => cartrom_data,

         -- Cartridge RAM interface
         ram_addr                => cartram_addr,
         ram_rd                  => cartram_rd,
         ram_wr                  => cartram_wr,
         ram_do                  => cartram_data_out,
         ram_di                  => cartram_data_in,

         -- Cartridge flags
         cart_mbc_type           => cart_mbc_type,
         cart_rom_size           => cart_rom_size,
         cart_ram_size           => cart_ram_size
      );

   -- Generate the signals necessary to store the LCD output into the frame buffer
   -- This process is heavily inspired and in part a 1-to-1 translation of portions of MiSTer's lcd.v

   i_lcd_to_pixels : entity work.lcd_to_pixels
   port map (
      clk_i                      => main_clk,
      sc_ce_i                    => sc_ce,
      qngbc_color_i              => qngbc_color,
      qngbc_color_mode_i         => qngbc_color_mode,
      lcd_clkena_i               => lcd_clkena,
      lcd_data_i                 => lcd_data,
      lcd_mode_i                 => lcd_mode,
      lcd_on_i                   => lcd_on,
      lcd_vsync_i                => lcd_vsync,
      pixel_out_we_o             => pixel_out_we,
      pixel_out_ptr_o            => pixel_out_ptr,
      pixel_out_data_o           => pixel_out_data
   ); -- i_lcd_to_pixels

   -- MEGA65 keyboard and joystick controller
   kbd : entity work.keyboard
      generic map
      (
         CLOCK_SPEED             => GB_CLK_SPEED
      )
      port map
      (
         clk                     => main_clk,
         kio8                    => kb_io0,
         kio9                    => kb_io1,
         kio10                   => kb_io2,
         joystick                => m65_joystick,
         joy_map                 => qngbc_joy_map,

         p54                     => joypad_p54,
         joypad                  => joypad_data_i,
         full_matrix             => qngbc_keyb_matrix
      );

   -- debouncer for the RESET button as well as for the joysticks:
   -- 40ms for the RESET button
   -- 5ms for any joystick direction
   -- 1ms for the fire button
   do_dbnce_reset_n : entity work.debounce
      generic map(clk_freq => GB_CLK_SPEED, stable_time => 40)
      port map (clk => main_clk, reset_n => '1', button => RESET_N, result => dbnce_reset_n);
   do_dbnce_joysticks : entity work.debouncer
      generic map
      (
         CLK_FREQ                => GB_CLK_SPEED
      )
      port map
      (
         clk                     => main_clk,
         reset_n                 => RESET_N,

         joy_1_up_n              => joy_1_up_n,
         joy_1_down_n            => joy_1_down_n,
         joy_1_left_n            => joy_1_left_n,
         joy_1_right_n           => joy_1_right_n,
         joy_1_fire_n            => joy_1_fire_n,

         dbnce_joy1_up_n         => dbnce_joy1_up_n,
         dbnce_joy1_down_n       => dbnce_joy1_down_n,
         dbnce_joy1_left_n       => dbnce_joy1_left_n,
         dbnce_joy1_right_n      => dbnce_joy1_right_n,
         dbnce_joy1_fire_n       => dbnce_joy1_fire_n,

         joy_2_up_n              => joy_2_up_n,
         joy_2_down_n            => joy_2_down_n,
         joy_2_left_n            => joy_2_left_n,
         joy_2_right_n           => joy_2_right_n,
         joy_2_fire_n            => joy_2_fire_n,

         dbnce_joy2_up_n         => dbnce_joy2_up_n,
         dbnce_joy2_down_n       => dbnce_joy2_down_n,
         dbnce_joy2_left_n       => dbnce_joy2_left_n,
         dbnce_joy2_right_n      => dbnce_joy2_right_n,
         dbnce_joy2_fire_n       => dbnce_joy2_fire_n
      );

   -- joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
   m65_joystick <= (dbnce_joy1_fire_n  and dbnce_joy2_fire_n) &
                   (dbnce_joy1_up_n    and dbnce_joy2_up_n)   &
                   (dbnce_joy1_down_n  and dbnce_joy2_down_n) &
                   (dbnce_joy1_left_n  and dbnce_joy2_left_n) &
                   (dbnce_joy1_right_n and dbnce_joy2_right_n);

   -- Switch keyboard and joystick on/off according to the QNICE control and status register (see gbc.asm)
   -- joypad_data is active low
   joypad_data <= joypad_data_i when qngbc_keyboard = '1' else (others => '1');

   -- Cartridge header flags
   -- Infos taken from: https://gbdev.io/pandocs/#the-cartridge-header and from MiSTer's mbc.sv
   isGBC_Game <= true when cart_cgb_flag = x"80" or cart_cgb_flag = x"C0" else false;
   isSGB_Game <= true when cart_sgb_flag = x"03" and cart_old_licensee = x"33" else false;


   ---------------------------------------------------------------------------------------------
   -- qnice_clk
   ---------------------------------------------------------------------------------------------

   -- QNICE Co-Processor (System-on-a-Chip) for ROM loading and On-Screen-Menu
   QNICE_SOC : entity work.QNICE
      generic map
      (
         VGA_DX                  => VGA_DX,
         VGA_DY                  => VGA_DY,
         MAX_ROM                 => SYS_ROM_MAX,
         MAX_RAM                 => SYS_RAM_MAX
      )
      port map
      (
         CLK50                   => qnice_clk,        -- 50 MHz clock      -- input
         RESET_N                 => RESET_N,                               -- input

         -- serial communication (rxd, txd only; rts/cts are not available)
         -- 115.200 baud, 8-N-1
         UART_RXD                => UART_RXD,         -- receive data      -- input
         UART_TXD                => UART_TXD,         -- send data         -- output

         -- SD Card
         SD_RESET                => SD_RESET,                              -- output
         SD_CLK                  => SD_CLK,                                -- output
         SD_MOSI                 => SD_MOSI,                               -- output
         SD_MISO                 => SD_MISO,                               -- input

         -- keyboard interface
         full_matrix             => qngbc_keyb_matrix,                     -- input

         -- VGA interface
         pixelclock              => vga_pixelclk,                          -- input
         vga_x                   => vga_col,                               -- input
         vga_y                   => vga_row,                               -- input
         vga_on                  => qngbc_osm_on,                          -- output
         vga_rgb                 => qngbc_osm_rgb,                         -- output

         -- Game Boy control
         gbc_reset               => qngbc_reset,                           -- output
         gbc_pause               => qngbc_pause,                           -- output
         gbc_keyboard            => qngbc_keyboard,                        -- output
         gbc_joystick            => qngbc_joystick,                        -- output
         gbc_color               => qngbc_color,                           -- output
         gbc_joy_map             => qngbc_joy_map,                         -- output
         gbc_color_mode          => qngbc_color_mode,                      -- output

         -- Interfaces to Game Boy's RAMs (MMIO):
         gbc_bios_addr           => qngbc_bios_addr,                       -- output
         gbc_bios_we             => qngbc_bios_we,                         -- output
         gbc_bios_data_in        => qngbc_bios_data_in,                    -- output
         gbc_bios_data_out       => qngbc_bios_data_out,                   -- input
         gbc_cart_addr           => qngbc_cart_addr,                       -- output
         gbc_cart_we             => qngbc_cart_we,                         -- output
         gbc_cart_data_in        => qngbc_cart_data_in,                    -- output
         gbc_cart_data_out       => qngbc_cart_data_out,                   -- input

         -- Cartridge flags
         cart_cgb_flag           => cart_cgb_flag,                         -- output
         cart_sgb_flag           => cart_sgb_flag,                         -- output
         cart_mbc_type           => cart_mbc_type,                         -- output
         cart_rom_size           => cart_rom_size,                         -- output
         cart_ram_size           => cart_ram_size,                         -- output
         cart_old_licensee       => cart_old_licensee                      -- output
      ); -- QNICE_SOC : entity work.QNICE

   -- Convert the Game Boy's PCM output to pulse density modulation
   -- TODO: Is this component configured correctly when it comes to clock speed, constants used within
   -- the component, subtracting 32768 while converting to signed, etc.
   pcm2pdm : entity work.pcm_to_pdm
      port map
      (
         cpuclock                => qnice_clk,
         pcm_left                => signed(signed(pcm_audio_left) - 32768),
         pcm_right               => signed(signed(pcm_audio_right) - 32768),
         pdm_left                => pwm_l,
         pdm_right               => pwm_r,
         audio_mode              => '0'
      );


   ---------------------------------------------------------------------------------------------
   -- vga_pixelclk
   ---------------------------------------------------------------------------------------------

   -- SVGA mode 800 x 600 @ 60 Hz
   -- Component that produces VGA timings and outputs the currently active pixel coordinate (row, column)
   -- Timings taken from http://tinyvga.com/vga-timing/800x600@60Hz
   vga_pixels_and_timing : entity work.vga_controller
      generic map
      (
         h_pixels                => VGA_DX,           -- horiztonal display width in pixels
         v_pixels                => VGA_DY,           -- vertical display width in rows

         h_pulse                 => 128,              -- horiztonal sync pulse width in pixels
         h_bp                    => 88,               -- horiztonal back porch width in pixels
         h_fp                    => 40,               -- horiztonal front porch width in pixels
         h_pol                   => '1',              -- horizontal sync pulse polarity (1 = positive, 0 = negative)

         v_pulse                 => 4,                -- vertical sync pulse width in rows
         v_bp                    => 23,               -- vertical back porch width in rows
         v_fp                    => 1,                -- vertical front porch width in rows
         v_pol                   => '1'               -- vertical sync pulse polarity (1 = positive, 0 = negative)
      )
      port map
      (
         pixel_clk               =>	vga_pixelclk,     -- pixel clock at frequency of VGA mode being used
         reset_n                 => dbnce_reset_n,    -- active low asycnchronous reset
         h_sync                  => vga_hs_int,       -- horiztonal sync pulse
         v_sync                  => vga_vs_int,       -- vertical sync pulse
         disp_ena                => vga_disp_en,      -- display enable ('1' = display time, '0' = blanking time)
         column                  => vga_col_raw,      -- horizontal pixel coordinate
         row                     => vga_row_raw,      -- vertical pixel coordinate
         n_blank                 => open,             -- direct blacking output to DAC
         n_sync                  => open              -- sync-on-green output to DAC
      );

   -- due to the latching of the VGA signals, we are one pixel off: compensate for that
   adjust_pixel_skew : process(vga_col_raw, vga_row_raw)
      variable nextrow  : integer range 0 to VGA_DY - 1;
   begin
      nextrow := vga_row_raw + 1;
      if vga_col_raw < VGA_DX - 1 then
         vga_col <= vga_col_raw + 1;
         vga_row <= vga_row_raw;
      else
         vga_col <= 0;
         if nextrow < VGA_DY then
            vga_row <= nextrow;
         else
            vga_row <= 0;
         end if;
      end if;
   end process;

   -- Scaler: 160 x 144 => 4x => 640 x 576
   -- Scaling by 4 is a convenient special case: We just need to use a SHR operation.
   -- We are doing this by taking the bits "9 downto 2" from the current column and row.
   -- This is a hardcoded and very fast operation.
   scaler : process(vga_col, vga_row)
      variable src_x: std_logic_vector(9 downto 0);
      variable src_y: std_logic_vector(9 downto 0);
      variable dst_x: std_logic_vector(7 downto 0);
      variable dst_y: std_logic_vector(7 downto 0);
      variable dst_x_i: integer range 0 to GB_DX - 1;
      variable dst_y_i: integer range 0 to GB_DY - 1;
      variable nextrow: integer range 0 to GB_DY - 1;
   begin
      src_x    := std_logic_vector(to_unsigned(vga_col, 10));
      src_y    := std_logic_vector(to_unsigned(vga_row, 10));
      dst_x    := src_x(9 downto 2);
      dst_y    := src_y(9 downto 2);
      dst_x_i  := to_integer(unsigned(dst_x));
      dst_y_i  := to_integer(unsigned(dst_y));
      nextrow  := dst_y_i + 1;

      -- The dual port & dual clock RAM needs one clock cycle to provide the data. Therefore we need
      -- to always address one pixel ahead of were we currently stand
      if dst_x_i < GB_DX - 1 then
         vga_col_next <= dst_x_i + 1;
         vga_row_next <= dst_y_i;
      else
         vga_col_next <= 0;
         if nextrow < GB_DY then
            vga_row_next <= nextrow;
         else
            vga_row_next <= 0;
         end if;
      end if;
   end process;

   vga_address <= std_logic_vector(to_unsigned(vga_row_next * GB_DX + vga_col_next, 15));

   video_signal_latches : process(vga_pixelclk)
   begin
      if rising_edge(vga_pixelclk) then
         VGA_RED   <= (others => '0');
         VGA_BLUE  <= (others => '0');
         VGA_GREEN <= (others => '0');

         if vga_disp_en then
            -- Game Boy output
            -- TODO: Investigate, why the top/left pixel is always white and solve it;
            -- workaround in the meantime: the top/left pixel is set to be always black which seems to be less intrusive
            if (vga_col_raw > 0 or vga_row_raw > 0) and
               (vga_col_raw < GB_DX * GB_TO_VGA_SCALE and vga_row_raw < GB_DY * GB_TO_VGA_SCALE) then
               VGA_RED   <= frame_buffer_data(23 downto 16);
               VGA_GREEN <= frame_buffer_data(15 downto 8);
               VGA_BLUE  <= frame_buffer_data(7 downto 0);
            end if;

            -- On-Screen-Menu (OSM) output
            if qngbc_osm_on then
               VGA_RED   <= qngbc_osm_rgb(23 downto 16);
               VGA_GREEN <= qngbc_osm_rgb(15 downto 8);
               VGA_BLUE  <= qngbc_osm_rgb(7 downto 0);
            end if;
         end if;

         -- VGA horizontal and vertical sync
         VGA_HS      <= vga_hs_int;
         VGA_VS      <= vga_vs_int;
      end if;
   end process;

   -- make the VDAC output the image
   -- for some reason, the VDAC does not like non-zero values outside the visible window
   -- maybe "vdac_sync_n <= '0';" activates sync-on-green?
   -- TODO: check that
   vdac_sync_n <= '0';
   vdac_blank_n <= '1';
   vdac_clk <= not vga_pixelclk; -- inverting the clock leads to a sharper signal for some reason


   ---------------------------------------------------------------------------------------------
   -- Dual Clocks
   ---------------------------------------------------------------------------------------------

   -- BIOS ROM / BOOT ROM
   bios_rom : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH     => 12,
         DATA_WIDTH     => 8,
         ROM_PRELOAD    => true,       -- load default ROM in case no other ROM is on the SD card
         ROM_FILE       => GBC_ROM,
         FALLING_B      => true        -- QNICE reads/writes on the falling clock edge
      )
      port map
      (
         -- GBC ROM interface
         clock_a        => main_clk,
         address_a      => gbc_bios_addr,
         q_a            => gbc_bios_data,

         -- QNICE RAM interface
         clock_b        => qnice_clk,
         address_b      => qngbc_bios_addr,
         data_b         => qngbc_bios_data_in,
         wren_b         => qngbc_bios_we,
         q_b            => qngbc_bios_data_out
      ); -- bios_rom : entity work.dualport_2clk_ram


   -- Cartridge ROM: modelled as a dual port dual clock RAM so that QNICE can fill it and Game Boy can read it
   game_cart_rom : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH        => CART_ROM_WIDTH,
         DATA_WIDTH        => 8,
         LATCH_ADDR_A      => true,       -- the gbc core expects that the RAM latches the address on cart_rd
         FALLING_B         => true        -- QNICE reads/writes on the falling clock edge
      )
      port map
      (
         -- GBC Game Cartridge ROM Interface
         clock_a           => main_clk,
         address_a         => cartrom_addr(CART_ROM_WIDTH - 1 downto 0),
         do_latch_addr_a   => cartrom_rd,
         q_a               => cartrom_data,

         -- QNICE RAM interface
         clock_b           => qnice_clk,
         address_b         => qngbc_cart_addr(CART_ROM_WIDTH - 1 downto 0),
         data_b            => qngbc_cart_data_in,
         wren_b            => qngbc_cart_we,
         q_b               => qngbc_cart_data_out
      ); -- game_cart_rom : entity work.dualport_2clk_ram


   -- Cartridge RAM
   game_cart_ram : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH        => CART_RAM_WIDTH,
         DATA_WIDTH        => 8
      )
      port map
      (
         clock_a           => main_clk,
         address_a         => cartram_addr(CART_RAM_WIDTH - 1 downto 0),
         data_a            => cartram_data_in,
         wren_a            => cartram_wr,
         q_a               => cartram_data_out
      ); -- game_cart_ram : entity work.dualport_2clk_ram


   -- Dual clock & dual port RAM that acts as framebuffer: the LCD display of the gameboy is
   -- written here by the GB core (using its local clock) and the VGA/HDMI display is being fed
   -- using the pixel clock
   frame_buffer : entity work.dualport_2clk_ram
      generic map
      (
         ADDR_WIDTH   => 15,
         MAXIMUM_SIZE => GB_DX * GB_DY, -- we do not need 2^15 x 24bit, but just (GB_DX * GB_DY) x 24bit
         DATA_WIDTH   => 24
      )
      port map
      (
         clock_a      => main_clk,
         address_a    => std_logic_vector(to_unsigned(pixel_out_ptr, 15)),
         data_a       => pixel_out_data,
         wren_a       => pixel_out_we,
         q_a          => open,

         clock_b      => vga_pixelclk,
         address_b    => vga_address,
         data_b       => (others => '0'),
         wren_b       => '0',
         q_b          => frame_buffer_data
      ); -- frame_buffer : entity work.dualport_2clk_ram

end beh;

