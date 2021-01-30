----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- Debouncer for the joystick ports
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------


library IEEE;
use IEEE.STD_LOGIC_1164.ALL;

entity debouncer is
generic (
   CLK_FREQ           : in integer
);
port (
   clk                : in std_logic;
   reset_n            : in std_logic;

   joy_1_up_n         : in std_logic;
   joy_1_down_n       : in std_logic;
   joy_1_left_n       : in std_logic;
   joy_1_right_n      : in std_logic;
   joy_1_fire_n       : in std_logic;
   
   dbnce_joy1_up_n    : out std_logic;
   dbnce_joy1_down_n  : out std_logic;
   dbnce_joy1_left_n  : out std_logic;
   dbnce_joy1_right_n : out std_logic;
   dbnce_joy1_fire_n  : out std_logic      
);
end debouncer;

architecture beh of debouncer is

begin
   -- debouncer for the RESET button as well as for the joysticks:
   -- 5ms for any joystick direction
   -- 1ms for the fire button     
   do_dbnce_joy1_up : entity work.debounce
      generic map(clk_freq => CLK_FREQ, stable_time => 5)
      port map (clk => clk, reset_n => reset_n, button => joy_1_up_n, result => dbnce_joy1_up_n);

   do_dbnce_joy1_down : entity work.debounce
      generic map(clk_freq => CLK_FREQ, stable_time => 5)
      port map (clk => clk, reset_n => reset_n, button => joy_1_down_n, result => dbnce_joy1_down_n);

   do_dbnce_joy1_left : entity work.debounce
      generic map(clk_freq => CLK_FREQ, stable_time => 5)
      port map (clk => clk, reset_n => reset_n, button => joy_1_left_n, result => dbnce_joy1_left_n);

   do_dbnce_joy1_right : entity work.debounce
      generic map(clk_freq => CLK_FREQ, stable_time => 5)
      port map (clk => clk, reset_n => reset_n, button => joy_1_right_n, result => dbnce_joy1_right_n);

   do_dbnce_joy1_fire : entity work.debounce
      generic map(clk_freq => CLK_FREQ, stable_time => 1)
      port map (clk => clk, reset_n => reset_n, button => joy_1_fire_n, result => dbnce_joy1_fire_n);
end beh;
