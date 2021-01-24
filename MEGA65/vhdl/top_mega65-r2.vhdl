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
signal vga_hs_int        : std_logic;
signal vga_vs_int        : std_logic;

-- debounced signals for the reset button and the joysticks; joystick signals are also inverted
signal dbnce_reset_n     : std_logic;
signal dbnce_joy1_up     : std_logic;
signal dbnce_joy1_down   : std_logic;
signal dbnce_joy1_left   : std_logic;
signal dbnce_joy1_right  : std_logic;
signal dbnce_joy1_fire   : std_logic;

-- Game Boy
signal global_ce         : std_logic;
signal is_CGB            : std_logic;
signal gbc_bios_addr     : std_logic_vector(11 downto 0);
signal gbc_bios_data     : std_logic_vector(7 downto 0);

-- LCD interface
signal lcd_clkena        : std_logic;
signal lcd_data          : std_logic_vector(14 downto 0);
signal lcd_mode          : std_logic_vector(1 downto 0);
signal lcd_mode_1        : std_logic_vector(1 downto 0);
signal lcd_on            : std_logic;
signal lcd_vsync         : std_logic;
signal lcd_vsync_1       : std_logic := '0';
signal pixel_out_x       : integer range 0 to 159;
signal pixel_out_y       : integer range 0 to 143;
signal pixel_out_data    : std_logic_vector(14 downto 0);  
signal pixel_out_we      : std_logic := '0';
signal frame_buffer_data : std_logic_vector(14 downto 0);
 
-- signals neccessary due to Verilog in VHDL embedding
-- otherwise, when wiring constants directly to the entity, then Vivado throws an error
signal i_ce_2x           : std_logic;
signal i_fast_boot       : std_logic;
signal i_joystick        : std_logic_vector(7 downto 0);
signal i_joystick_din    : std_logic_vector(3 downto 0);
signal i_reset           : std_logic;
signal i_dummy_0         : std_logic;
signal i_dummy_2bit_0    : std_logic_vector(1 downto 0);
signal i_dummy_8bit_0    : std_logic_vector(7 downto 0);
signal i_dummy_64bit_0   : std_logic_vector(63 downto 0);
signal i_dummy_129bit_0  : std_logic_vector(128 downto 0);
 
begin

   is_CGB <= '1';
   global_ce <= '1';
   
   -- signals neccessary due to Verilog in VHDL embedding
   i_ce_2x           <= '0';
   i_fast_boot       <= '1';
   i_joystick        <= x"FF";
   i_joystick_din    <= "1111";
   i_dummy_0         <= '0';
   i_dummy_2bit_0    <= (others => '0');
   i_dummy_8bit_0    <= (others => '0');
   i_dummy_64bit_0   <= (others => '0');
   i_dummy_129bit_0  <= (others => '0');

   -- TODO: Achieve timing closure also when using the debouncer   
   --i_reset           <= not dbnce_reset_n;   
   i_reset           <= not RESET_N; -- TODO/WARNING: might glitch
   

   gameboy : entity work.gb
      port map
      (
         reset                   => i_reset,
                     
         clk_sys                 => main_clk,
         ce                      => global_ce,
         ce_2x                   => i_ce_2x,
                  
         fast_boot               => i_fast_boot,
         joystick                => i_joystick,
         isGBC                   => is_CGB,
         isGBC_game              => false,
      
         -- cartridge interface
         -- can adress up to 1MB ROM
         cart_addr               => open,
         cart_rd                 => open,  
         cart_wr                 => open, 
         cart_di                 => open,  
         cart_do                 => i_dummy_8bit_0,  
         
         --gbc bios interface
         gbc_bios_addr           => gbc_bios_addr,
         gbc_bios_do             => gbc_bios_data,
               
         -- audio    
         audio_l                 => open,
         audio_r                 => open,
               
         -- lcd interface     
         lcd_clkena              => lcd_clkena,
         lcd_data                => lcd_data,  
         lcd_mode                => lcd_mode,  
         lcd_on                  => lcd_on,    
         lcd_vsync               => lcd_vsync, 
            
         joy_p54                 => open,
         joy_din                 => i_joystick_din,
                  
         speed                   => open,   --GBC
         HDMA_on                 => open,
                  
         gg_reset                => i_reset,
         gg_en                   => i_dummy_0,
         gg_code                 => i_dummy_129bit_0,
         gg_available            => open,
            
         --serial port     
         sc_int_clock2           => open,
         serial_clk_in           => i_dummy_0,
         serial_clk_out          => open,
         serial_data_in          => i_dummy_0,
         serial_data_out         => open,
               
         -- save states
         cart_ram_size           => i_dummy_8bit_0,
         save_state              => i_dummy_0,
         load_state              => i_dummy_0,
         sleep_savestate         => open,
         savestate_number        => i_dummy_2bit_0,
               
         SaveStateExt_Din        => open, 
         SaveStateExt_Adr        => open, 
         SaveStateExt_wren       => open,
         SaveStateExt_rst        => open, 
         SaveStateExt_Dout       => i_dummy_64bit_0,
         SaveStateExt_load       => open,
         
         Savestate_CRAMAddr      => open,     
         Savestate_CRAMRWrEn     => open,    
         Savestate_CRAMWriteData => open,
         Savestate_CRAMReadData  => i_dummy_8bit_0, 
                  
         SAVE_out_Din            => open,   
         SAVE_out_Dout           => i_dummy_64bit_0,
         SAVE_out_Adr            => open,   
         SAVE_out_rnw            => open,   
         SAVE_out_ena            => open,   
         SAVE_out_done           => i_dummy_0,
               
         rewind_on               => i_dummy_0,
         rewind_active           => i_dummy_0
      );
          
   -- BIOS ROM / BOOT ROM
   boot_rom : entity work.BROM
      generic map
      (
         FILE_NAME   => "../../rom/cgb_bios.rom",
         ADDR_WIDTH  => 12,
         DATA_WIDTH  => 8
      )
      port map
      (
         CLK         => main_clk,
         ce          => '1',
         address     => gbc_bios_addr,
         data        => gbc_bios_data
      );

      
   frame_buffer : entity work.dualport_2clk_ram
      generic map
      ( 
         ADDR_WIDTH  => 15,
         DATA_WIDTH  => 15
      )
      port map
      (
         clock_a     => main_clk,
         address_a   => std_logic_vector(to_unsigned(pixel_out_y * 160 + pixel_out_x, 15)),
         data_a      => pixel_out_data,
         wren_a      => pixel_out_we,
         q_a         => open,
         
         clock_b     => vga_pixelclk,
         address_b   => std_logic_vector(to_unsigned(vga_row * 160 + vga_col, 15)),
         data_b      => (others => '0'),
         wren_b      => '0',
         q_b         => frame_buffer_data
      );

   lcd_to_pixels : process(main_clk)
   begin
      if rising_edge(main_clk) then
         pixel_out_we <= '0';
         lcd_vsync_1   <= lcd_vsync;
         lcd_mode_1    <= lcd_mode;
         if (lcd_on = '1') then
            if (lcd_vsync = '1' and lcd_vsync_1 = '0') then
               pixel_out_x <= 0;
               pixel_out_y <= 0;
            elsif (lcd_mode_1 /= "11" and lcd_mode = "11") then
               pixel_out_x  <= 0;
               if (pixel_out_y < 143) then
                  pixel_out_y <= pixel_out_y + 1;
               end if;
            elsif (lcd_clkena = '1' and global_ce = '1') then
               if (pixel_out_x < 159) then
                  pixel_out_x  <= pixel_out_x + 1;
               end if;
               pixel_out_we <= '1';
            end if;
         end if;
         
         if (is_CGB = '0') then
            case (lcd_data(1 downto 0)) is
               when "00"   => pixel_out_data <= "11111" & "11111" & "11111";
               when "01"   => pixel_out_data <= "10000" & "10000" & "10000";
               when "10"   => pixel_out_data <= "01000" & "01000" & "01000";
               when "11"   => pixel_out_data <= "00000" & "00000" & "00000";
               when others => pixel_out_data <= "00000" & "00000" & "11111";
            end case;
         else
            pixel_out_data <= lcd_data(4 downto 0) & lcd_data(9 downto 5) & lcd_data(14 downto 10);
         end if;
         
      end if;
   end process; 
                    
   -- MMCME2_ADV clock generator:
   --    Core clock:          32 MHz
   --    Pixelclock:          25.175 MHz
   --    QNICE co-processor:  50 MHz   
   clk_gen : entity work.clk
      port map
      (
         sys_clk_i         => CLK,
         pixelclk_o        => vga_pixelclk,  -- 25.175 MHz pixelclock for VGA 640x480 @ 60 Hz
         gbmain_o          => main_clk       -- 50 MHz clock for the QNICE co-processor  
      );

   -- debouncer for the RESET button as well as for the joysticks:
   -- 40ms for the RESET button
   -- 5ms for any joystick direction
   -- 1ms for the fire button
   do_dbnce_reset_n : entity work.debounce
      generic map(clk_freq => 100_000_000, stable_time => 40)
      port map (clk => clk, reset_n => '1', button => RESET_N, result => dbnce_reset_n);
   do_dbnce_joysticks : entity work.debouncer
      generic map
      (
         CLK_FREQ          => 100_000_000
      )
      port map
      (
         clk               => CLK,
         reset_n           => RESET_N,

         joy_1_up_n        => joy_1_up_n,
         joy_1_down_n      => joy_1_down_n, 
         joy_1_left_n      => joy_1_left_n, 
         joy_1_right_n     => joy_1_right_n, 
         joy_1_fire_n      => joy_1_fire_n, 
           
         dbnce_joy1_up     => dbnce_joy1_up,
         dbnce_joy1_down   => dbnce_joy1_down,
         dbnce_joy1_left   => dbnce_joy1_left,
         dbnce_joy1_right  => dbnce_joy1_right,
         dbnce_joy1_fire   => dbnce_joy1_fire
      );

   -- VGA 640x480 @ 60 Hz      
   -- Component that produces VGA timings and outputs the currently active pixel coordinate (row, column)      
   -- Timings taken from http://tinyvga.com/vga-timing/640x480@60Hz
   vga_pixels_and_timing : entity work.vga_controller
      generic map
      (
         h_pixels    => 640,              -- horiztonal display width in pixels
         v_pixels    => 480,              -- vertical display width in rows
         
         h_pulse     => 96,               -- horiztonal sync pulse width in pixels
         h_bp        => 48,               -- horiztonal back porch width in pixels
         h_fp        => 16,               -- horiztonal front porch width in pixels
         h_pol       => '0',              -- horizontal sync pulse polarity (1 = positive, 0 = negative)
         
         v_pulse     => 2,                -- vertical sync pulse width in rows
         v_bp        => 33,               -- vertical back porch width in rows
         v_fp        => 10,               -- vertical front porch width in rows
         v_pol       => '0'               -- vertical sync pulse polarity (1 = positive, 0 = negative)         
      )
      port map
      (
         pixel_clk   =>	vga_pixelclk,     -- pixel clock at frequency of VGA mode being used
         reset_n     => dbnce_reset_n,    -- active low asycnchronous reset
         h_sync      => vga_hs_int,       -- horiztonal sync pulse
         v_sync      => vga_vs_int,       -- vertical sync pulse
         disp_ena    => vga_disp_en,      -- display enable ('1' = display time, '0' = blanking time)
         column      => vga_col,          -- horizontal pixel coordinate
         row         => vga_row,          -- vertical pixel coordinate
         n_blank     => open,             -- direct blacking output to DAC
         n_sync      => open              -- sync-on-green output to DAC      
      );
   
   video_signal_latches : process(vga_pixelclk)
   begin
      if rising_edge(vga_pixelclk) then 
         if vga_disp_en then       
            if vga_col < 160 and vga_row < 144 then
               VGA_RED   <= frame_buffer_data(14 downto 10) & "000";
               VGA_GREEN <= frame_buffer_data(9 downto 5) & "000";
               VGA_BLUE  <= frame_buffer_data(4 downto 0) & "000";
            else
               VGA_RED   <= (others => '0');
               VGA_GREEN <= (others => '0');
               VGA_BLUE  <= (others => '1');
            end if;       
         
--            -- debug output to test, if VGA and vga_col/vga_row works       
--            VGA_RED   <= std_logic_vector(to_unsigned(vga_col + vga_row, 32)(7 downto 0));
--            VGA_BLUE  <= std_logic_vector(to_unsigned(vga_row, 9)(8 downto 3)) & "11";
--            VGA_GREEN <= std_logic_vector(to_unsigned(vga_col, 10)(9 downto 4)) & "11";

         -- for some reason, the VDAC does not like non-zero values outside the visible window
         -- maybe "vdac_sync_n <= '0';" activates sync-on-green?
         -- TODO: check that
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
end beh;
