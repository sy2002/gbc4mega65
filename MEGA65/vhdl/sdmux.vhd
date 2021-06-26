----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- Smart MEGA65 SD Card multiplexer
--
-- Activate the bottom tray's SD card, if there is no SD card in the slot on the
-- machine's back side. Otherwise the back side slot has precedence. It is
-- possible to overwrite the automatic behavior.
--
-- The smart multiplexer also makes sure that the QNICE SD card controller is
-- being reset as soon as the SD card is switched. 
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity sdmux is
   port (
      -- QNICE system interface
      sysclk50Mhz_i     : in std_logic;   -- QNIEC system clock
      sysreset_i        : in std_logic;   -- QNICE system reset
      
      -- Configuration lines to control the behavior of the multiplexer
      mode_i            : in std_logic;   -- SD Card mode: 0=Auto: SD card switches between the internal card (bottom tray)
                                          -- and the external card (back slot) automatically: External has higher precedence
      active_o          : out std_logic;  -- Currently active SD card: 0=internal / 1=external
      force_i           : in std_logic;   -- if mode_i=1 then use this to force internal (0) or external (1)
      detected_int_o    : out std_logic;  -- 1=internal SD card detected
      detected_ext_o    : out std_logic;  -- 1=external SD card detected
      
      -- interface to bottom tray's SD card
      sd_tray_detect_i  : in std_logic;   -- low active
      sd_tray_reset_o   : out std_logic;
      sd_tray_clk_o     : out std_logic;
      sd_tray_mosi_o    : out std_logic;
      sd_tray_miso_i    : in std_logic;
      
      -- interface to the SD card in the back slot
      sd_back_detect_i  : in std_logic;   -- low active
      sd_back_reset_o   : out std_logic;
      sd_back_clk_o     : out std_logic;
      sd_back_mosi_o    : out std_logic;
      sd_back_miso_i    : in std_logic;
      
      -- interface to the QNICE SD card controller
      ctrl_reset_o      : out std_logic;  -- high active; it is important that sdmux controls the QNICE controller's reset
      ctrl_sd_reset_i   : in std_logic;
      ctrl_sd_clk_i     : in std_logic;
      ctrl_sd_mosi_i    : in std_logic;
      ctrl_sd_miso_o    : out std_logic
   );
end sdmux;

architecture beh of sdmux is

begin

   ctrl_reset_o      <= sysreset_i;
   sd_tray_reset_o   <= ctrl_sd_reset_i;
   sd_tray_clk_o     <= ctrl_sd_clk_i;
   sd_tray_mosi_o    <= ctrl_sd_mosi_i;
   ctrl_sd_miso_o    <= sd_tray_miso_i;
   
   detected_int_o    <= not sd_tray_detect_i;
   detected_ext_o    <= not sd_back_detect_i;

end beh;
