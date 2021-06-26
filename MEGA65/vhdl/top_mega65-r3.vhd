----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- R3-Version: Top Module for synthesizing the whole machine
--
-- Screen resolution: 1280x720 @ 60 Hz (720p @ 60 Hz)
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.m65_const.all;

entity MEGA65_R3 is
port (
   CLK            : in std_logic;                  -- 100 MHz clock
   RESET_N        : in std_logic;                  -- CPU reset button
   
   -- serial communication (rxd, txd only; rts/cts are not available)
   -- 115.200 baud, 8-N-1
   UART_RXD       : in std_logic;                  -- receive data
   UART_TXD       : out std_logic;                 -- send data   
        
   -- VGA and VDAC
   VGA_RED        : out std_logic_vector(7 downto 0);
   VGA_GREEN      : out std_logic_vector(7 downto 0);
   VGA_BLUE       : out std_logic_vector(7 downto 0);
   VGA_HS         : out std_logic;
   VGA_VS         : out std_logic;
   
   vdac_clk       : out std_logic;
   vdac_sync_n    : out std_logic;
   vdac_blank_n   : out std_logic;
   
   -- Digital Video
   tmds_data_p    : out std_logic_vector(2 downto 0);
   tmds_data_n    : out std_logic_vector(2 downto 0);
   tmds_clk_p     : out std_logic;
   tmds_clk_n     : out std_logic;

   -- MEGA65 smart keyboard controller
   kb_io0         : out std_logic;                 -- clock to keyboard
   kb_io1         : out std_logic;                 -- data output to keyboard
   kb_io2         : in std_logic;                  -- data input from keyboard   
   
   -- SD Card (internal on bottom)
   SD_RESET       : out std_logic;
   SD_CLK         : out std_logic;
   SD_MOSI        : out std_logic;
   SD_MISO        : in std_logic;
   SD_CD          : in std_logic;

   -- SD Card (external on back)
   SD2_RESET      : out std_logic;
   SD2_CLK        : out std_logic;
   SD2_MOSI       : out std_logic;
   SD2_MISO       : in std_logic;
   SD2_CD         : in std_logic;
   
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
end MEGA65_R3;

architecture beh of MEGA65_R3 is
begin

   MEGA65 : entity work.MEGA65_Core
      generic map
      (
         -- m65_const.vhd contains details and explanations
         -- @TODO: REVERT BACK TO R3
         CART_ROM_MAX   => CART_ROM_MAX_R2,  -- @TODO: REVERT BACK TO R3
         CART_RAM_MAX   => CART_RAM_MAX_R2,  -- @TODO: REVERT BACK TO R3
         SYS_ROM_MAX    => SYS_ROM_MAX_R2,   -- @TODO: REVERT BACK TO R3
         SYS_RAM_MAX    => SYS_RAM_MAX_R2    -- @TODO: REVERT BACK TO R3
      )
      port map
      (
         CLK            => CLK,
         RESET_N        => RESET_N,
         
         -- serial communication (rxd, txd only; rts/cts are not available)
         -- 115.200 baud, 8-N-1         
         UART_RXD       => UART_RXD,
         UART_TXD       => UART_TXD,
            
         -- VGA and VDAC
         VGA_RED        => VGA_RED,
         VGA_GREEN      => VGA_GREEN,
         VGA_BLUE       => VGA_BLUE,
         VGA_HS         => VGA_HS,
         VGA_VS         => VGA_VS,
      
         vdac_clk       => vdac_clk,
         vdac_sync_n    => vdac_sync_n,
         vdac_blank_n   => vdac_blank_n,

         tmds_data_p    => tmds_data_p,
         tmds_data_n    => tmds_data_n,
         tmds_clk_p     => tmds_clk_p,
         tmds_clk_n     => tmds_clk_n,
         
         -- MEGA65 smart keyboard controller
         kb_io0         => kb_io0,
         kb_io1         => kb_io1,
         kb_io2         => kb_io2,   
         
         -- SD Card (internal on bottom)
         SD_RESET       => SD_RESET,
         SD_CLK         => SD_CLK,
         SD_MOSI        => SD_MOSI,
         SD_MISO        => SD_MISO,
         SD_CD          => SD_CD,

         -- SD Card (external on back)
         SD2_RESET      => SD2_RESET,
         SD2_CLK        => SD2_CLK,
         SD2_MOSI       => SD2_MOSI,
         SD2_MISO       => SD2_MISO,
         SD2_CD         => SD2_CD,
         
         -- 3.5mm analog audio jack
         pwm_l          => pwm_l,
         pwm_r          => pwm_r,
            
         -- Joysticks
         joy_1_up_n     => joy_1_up_n,     
         joy_1_down_n   => joy_1_down_n,
         joy_1_left_n   => joy_1_left_n,
         joy_1_right_n  => joy_1_right_n,  
         joy_1_fire_n   => joy_1_fire_n,   
            
         joy_2_up_n     => joy_2_up_n, 
         joy_2_down_n   => joy_2_down_n,
         joy_2_left_n   => joy_2_left_n,   
         joy_2_right_n  => joy_2_right_n,  
         joy_2_fire_n   => joy_2_fire_n
      ); 

end beh;
