----------------------------------------------------------------------------------
-- Gameboy Color for MEGA65 (gbc4mega65)
--
-- R2-Version: Top Module for synthesizing the whole machine
--
-- This machine is based on Gameboy_MiSTer
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

-- clocks
signal main_clk          : std_logic;  -- Game Boy core main clock @ 32 MHz
signal vga_pixelclk      : std_logic;  -- 640x480 @ 60 Hz clock: 27.175 MHz

-- VGA signals
signal vga_disp_en       : std_logic;
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

begin
                              
   -- MMCME2_ADV clock generator:
   --    Core clock:          32 MHz
   --    Pixelclock:          25.175 MHz
   --    QNICE co-processor:  50 MHz   
   clk_gen : entity work.clk
      port map
      (
         sys_clk_i         => CLK,
         pixelclk_o        => vga_pixelclk   -- 25.175 MHz pixelclock for VGA 640x480 @ 60 Hz         
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
         pixel_clk   =>	vga_pixelclk,  -- pixel clock at frequency of VGA mode being used
         reset_n     => dbnce_reset_n, -- active low asycnchronous reset
         h_sync      => vga_hs_int,    -- horiztonal sync pulse
         v_sync      => vga_vs_int,    -- vertical sync pulse
         disp_ena    => vga_disp_en,   -- display enable ('1' = display time, '0' = blanking time)
         column      => vga_col,       -- horizontal pixel coordinate
         row         => vga_row,       -- vertical pixel coordinate
         n_blank     => open,          -- direct blacking output to DAC
         n_sync      => open           -- sync-on-green output to DAC      
      );
   
   video_signal_latches : process(vga_pixelclk)
   begin
      if rising_edge(vga_pixelclk) then 
         if vga_disp_en then       
         
            -- debug output to test, if VGA and vga_col/vga_row works       
            VGA_RED   <= std_logic_vector(to_unsigned(vga_col + vga_row, 32)(7 downto 0));
            VGA_BLUE  <= std_logic_vector(to_unsigned(vga_row, 9)(8 downto 3)) & "11";
            VGA_GREEN <= std_logic_vector(to_unsigned(vga_col, 10)(9 downto 4)) & "11";
         else
            VGA_RED   <= (others => '0');
            VGA_BLUE  <= (others => '0');
            VGA_GREEN <= (others => '0');
         end if;
                        
         -- VGA horizontal and vertical sync
         VGA_HS      <= vga_hs_int;
         VGA_VS      <= vga_vs_int;         
      end if;
   end process;
        
   -- make the VDAC output the image    
   vdac_sync_n <= '0';
   vdac_blank_n <= '1';   
   vdac_clk <= not vga_pixelclk; -- inverting the clock leads to a sharper signal for some reason
   
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
