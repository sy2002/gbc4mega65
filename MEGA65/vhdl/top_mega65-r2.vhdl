----------------------------------------------------------------------------------
-- VHDLBoy port for MEGA65
--
-- R2-Version: Top Module for synthesizing the whole machine
--
-- The machine is based on Robert Peip's VHDLBoy
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity MEGA65_R2 is
port (
   CLK            : in std_logic;                  -- 100 MHz clock
   RESET_N        : in std_logic;                  -- CPU reset button
        
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
--   kb_io0         : out std_logic;                 -- clock to keyboard
--   kb_io1         : out std_logic;                 -- data output to keyboard
--   kb_io2         : in std_logic;                  -- data input from keyboard   
   
   -- SD Card
--   SD_RESET       : out std_logic;
--   SD_CLK         : out std_logic;
--   SD_MOSI        : out std_logic;
--   SD_MISO        : in std_logic;
   
   -- Joysticks
   joy_1_up_n     : in std_logic;
   joy_1_down_n   : in std_logic;
   joy_1_left_n   : in std_logic;
   joy_1_right_n  : in std_logic;
   joy_1_fire_n   : in std_logic
   
--   joy_2_up_n     : in std_logic;
--   joy_2_down_n   : in std_logic;
--   joy_2_left_n   : in std_logic;
--   joy_2_right_n  : in std_logic;
--   joy_2_fire_n   : in std_logic;
   
   -- 3.5mm analog audio jack
--   pwm_l          : out std_logic;
--   pwm_r          : out std_logic
   
      
   -- HDMI via ADV7511
--   hdmi_vsync     : out std_logic;
--   hdmi_hsync     : out std_logic;
--   hdmired        : out std_logic_vector(7 downto 0);
--   hdmigreen      : out std_logic_vector(7 downto 0);
--   hdmiblue       : out std_logic_vector(7 downto 0);
   
--   hdmi_clk       : out std_logic;      
--   hdmi_de        : out std_logic;                 -- high when valid pixels being output
   
--   hdmi_int       : in std_logic;                  -- interrupts by ADV7511
--   hdmi_spdif     : out std_logic := '0';          -- unused: GND
--   hdmi_scl       : inout std_logic;               -- I2C to/from ADV7511: serial clock
--   hdmi_sda       : inout std_logic;               -- I2C to/from ADV7511: serial data
   
   -- TPD12S016 companion chip for ADV7511
   --hpd_a          : inout std_logic;
--   ct_hpd         : out std_logic := '1';          -- assert to connect ADV7511 to the actual port
--   ls_oe          : out std_logic := '1';          -- ditto
   
   -- Built-in HyperRAM
--   hr_d           : inout unsigned(7 downto 0);    -- Data/Address
--   hr_rwds        : inout std_logic;               -- RW Data strobe
--   hr_reset       : out std_logic;                 -- Active low RESET line to HyperRAM
--   hr_clk_p       : out std_logic;
   
   -- Optional additional HyperRAM in trap-door slot
--   hr2_d          : inout unsigned(7 downto 0);    -- Data/Address
--   hr2_rwds       : inout std_logic;               -- RW Data strobe
--   hr2_reset      : out std_logic;                 -- Active low RESET line to HyperRAM
--   hr2_clk_p      : out std_logic;
--   hr_cs0         : out std_logic;
--   hr_cs1         : out std_logic   
); 
end MEGA65_R2;

architecture beh of MEGA65_R2 is

-- emulated flat memory space that contains the GameBoy's Boot ROM, WRAM, HRAM
-- as well as the game cartridge's ROM and RAM
signal mem_addr          : std_logic_vector(21 downto 0);   
signal mem_data_in       : std_logic_vector(31 downto 0);
signal mem_data_out      : std_logic_vector(31 downto 0);
signal mem_we_n          : std_logic;
signal mem_req           : std_logic;
signal mem_data_valid    : std_logic;

-- pixelclock, GB pixels input/output & latched VGA signals for processing via VDAC
signal pixelclock        : std_logic; -- 640x480 @ 60Hz means 25.175 MHz pixelclock
signal gameboy_pixels    : std_logic_vector(14 downto 0);
signal gameboy_px_active : std_logic;
signal vga_col           : integer range 0 to 639;
signal vga_row           : integer range 0 to 479;
signal vga_red_int       : std_logic_vector(4 downto 0);
signal vga_green_int     : std_logic_vector(4 downto 0);
signal vga_blue_int      : std_logic_vector(4 downto 0);
signal vga_hs_int        : std_logic;
signal vga_vs_int        : std_logic;

-- debounced signals for the reset button and the joysticks; joystick signals are also inverted
signal dbnce_reset_n     : std_logic;
signal dbnce_joy1_up     : std_logic;
signal dbnce_joy1_down   : std_logic;
signal dbnce_joy1_left   : std_logic;
signal dbnce_joy1_right  : std_logic;
signal dbnce_joy1_fire   : std_logic;

attribute mark_debug                      : boolean;
--attribute mark_debug of vga_red_int       : signal is true;
--attribute mark_debug of vga_green_int     : signal is true;
--attribute mark_debug of vga_blue_int      : signal is true;
attribute mark_debug of gameboy_pixels    : signal is true;
--attribute mark_debug of pixelclock        : signal is true;
--attribute mark_debug of dbnce_joy1_fire   : signal is true;
attribute mark_debug of vga_col           : signal is true;
attribute mark_debug of vga_row           : signal is true;
attribute mark_debug of gameboy_px_active : signal is true;


begin

   vga_red_int    <= gameboy_pixels(14 downto 10);
   vga_green_int  <= gameboy_pixels(9 downto 5);
   vga_blue_int   <= gameboy_pixels(4 downto 0); 
            
   machine : entity work.gameboy
      generic map
      (
         is_simu           => '0',               -- setting to 1 will activate cpu debug output
         scale_mult        => 3                  -- scale multiplier for image, 1 = 160x144, 2=320*288, ...         
      )
      port map
      (
         clk100            => CLK,
         Gameboy_on        => dbnce_reset_n,     -- switch gameboy on, setting to 0 will reset most parts
         Gameboy_Speedmult => "0001",            -- speed multiplier, 1 = normal speed, 2 = double, .... 
         
         -- game specific
         -- right now everything hardcoded for Super Mario Land
         Gameboy_CGB       => '1',               -- use gameboy color drawmode, switch this off after booting the cbg-bios when using games that don't support cgb, otherwise graphic glitches, extracted from rom address 0x143
         Gameboy_MBC       => "001",             -- MBC used, extracted from rom address 0x147, see PANDOCS for more info
         Gameboy_Rombanks  => x"01",             -- How many rombanks game has, extracted from rom address 0x148, see PANDOCS for more info
         Gameboy_Rambanks  => "00000",           -- How many rambanks game has, extracted from rom address 0x149, see PANDOCS for more info
         
         -- graphic
         clkvga            => pixelclock,        -- seperate clock for vga or hdmi
         oCoord_X          => vga_col,           -- current screen coordinate including offscreen
         oCoord_Y          => vga_row,           -- current screen coordinate including offscreen
         gameboy_graphic   => gameboy_pixels,    -- 5/5/5 rgb output
         gameboy_active    => gameboy_px_active, -- inside gameboy pixel area 
             
         -- sound
         sound_out         => open,              -- 16 bit signed sound,output, mono only
         
         -- keys
         Gameboy_KeyUp     => '0',  
         Gameboy_KeyDown   => '0',
         Gameboy_KeyLeft   => '0',
         Gameboy_KeyRight  => '0',
         Gameboy_KeyA      => '0',
         Gameboy_KeyB      => '0',
         Gameboy_KeyStart  => dbnce_joy1_fire,
         Gameboy_KeySelect => '0',
         
         -- memory ( gamerom, gameram, bootrom, HRAM, WRAM)
         mem_addr          => mem_addr,
         mem_dataout       => mem_data_in,
         mem_rnw           => mem_we_n,
         mem_request       => mem_req,
         mem_datain        => mem_data_out,
         mem_valid         => mem_data_valid
      );
      
   emulate_linear_ram : entity work.merged_memory
      port map
      ( 
         CLK               => CLK,   
         addr              => mem_addr,
         data_in           => mem_data_in,
         data_out          => mem_data_out,
         we                => not mem_we_n,
         req               => mem_req,
         valid             => mem_data_valid
      );
      
   clk_gen : entity work.clk
      port map
      (
         sys_clk_i         => CLK,
         pixelclk_o        => pixelclock  -- 25.175 MHz pixelclock for VGA 640x480 @ 60 Hz         
      );

   -- VGA 640x480 @ 60 Hz      
   -- Component that produces VGA timings and outputs the currently active pixel coordinate (row, column)      
   -- Timings taken from http://tinyvga.com/vga-timing/640x480@60Hz
   vga_pixels_and_timing : entity work.vga_controller
      generic map
      (
         h_pixels    => 640,           -- horiztonal display width in pixels
         v_pixels    => 480,           -- vertical display width in rows
         
         h_pulse     => 96,            -- horiztonal sync pulse width in pixels
         h_bp        => 48,            -- horiztonal back porch width in pixels
         h_fp        => 16,            -- horiztonal front porch width in pixels
         h_pol       => '0',           -- horizontal sync pulse polarity (1 = positive, 0 = negative)
         
         v_pulse     => 2,             -- vertical sync pulse width in rows
         v_bp        => 33,            -- vertical back porch width in rows
         v_fp        => 10,            -- vertical front porch width in rows
         v_pol       => '0'            -- vertical sync pulse polarity (1 = positive, 0 = negative)         
      )
      port map
      (
         pixel_clk   =>	pixelclock,    -- pixel clock at frequency of VGA mode being used
         reset_n     => dbnce_reset_n, -- active low asycnchronous reset
         h_sync      => vga_hs_int,    -- horiztonal sync pulse
         v_sync      => vga_vs_int,    -- vertical sync pulse
         disp_ena    => open,          -- display enable ('1' = display time, '0' = blanking time)
         column      => vga_col,       -- horizontal pixel coordinate
         row         => vga_row,       -- vertical pixel coordinate
         n_blank     => open,          -- direct blacking output to DAC
         n_sync      => open           -- sync-on-green output to DAC      
      );
   
   video_signal_latches : process(pixelclock)
   begin
      if rising_edge(pixelclock) then
--         if gameboy_px_active then
            -- VGA: wire the simplified color system of the VGA component to the VGA outputs         
            VGA_RED     <= vga_red_int    & "000";
            VGA_GREEN   <= vga_green_int  & "000";
            VGA_BLUE    <= vga_blue_int   & "000";
            
--         -- DEBUG: Show the rest of the screen in green color, so that we can see the Game Boy's screen boundaries
--         else
--            VGA_RED     <= (others => '0');
--            VGA_GREEN   <= (others => '1');
--            VGA_BLUE    <= (others => '0');
--         end if;
         
--         -- DEBUG: Show the Game Boy screen using a pattern made of column and row information, so
--         -- that we can check, if VGA itself and the row and col counters are working
--         if gameboy_px_active then
--            VGA_RED   <= std_logic_vector(to_unsigned(vga_col, 8));
--            VGA_BLUE  <= std_logic_vector(to_unsigned(vga_row, 8));
--            VGA_GREEN <= (others => '1');
--         end if;
         
         -- VGA horizontal and vertical sync
         VGA_HS      <= vga_hs_int;
         VGA_VS      <= vga_vs_int;         
      end if;
   end process;

   -- make the VDAC output the image    
   vdac_sync_n <= '0';
   vdac_blank_n <= '1';   
   vdac_clk <= not pixelclock; -- inverting the clock leads to a sharper signal for some reason
   
   -- debouncer for the RESET button as well as for the joysticks:
   -- 40ms for the RESET button
   -- 5ms for any joystick direction
   -- 1ms for the fire button
   do_dbnce_reset_n : entity work.debounce
      generic map(clk_freq => 100_000_000, stable_time => 40)
      port map (clk => CLK, reset_n => '1', button => RESET_N, result => dbnce_reset_n);
      
   do_dbnce_joy1_up : entity work.debounce
      generic map(clk_freq => 100_000_000, stable_time => 5)
      port map (clk => CLK, reset_n => dbnce_reset_n, button => not joy_1_up_n, result => dbnce_joy1_up);

   do_dbnce_joy1_down : entity work.debounce
      generic map(clk_freq => 100_000_000, stable_time => 5)
      port map (clk => CLK, reset_n => dbnce_reset_n, button => not joy_1_down_n, result => dbnce_joy1_down);

   do_dbnce_joy1_left : entity work.debounce
      generic map(clk_freq => 100_000_000, stable_time => 5)
      port map (clk => CLK, reset_n => dbnce_reset_n, button => not joy_1_left_n, result => dbnce_joy1_left);

   do_dbnce_joy1_right : entity work.debounce
      generic map(clk_freq => 100_000_000, stable_time => 5)
      port map (clk => CLK, reset_n => dbnce_reset_n, button => not joy_1_right_n, result => dbnce_joy1_right);

   do_dbnce_joy1_fire : entity work.debounce
      generic map(clk_freq => 100_000_000, stable_time => 1)
      port map (clk => CLK, reset_n => dbnce_reset_n, button => not joy_1_fire_n, result => dbnce_joy1_fire);
end beh;
