---------------------------------------------------------------------------------------------------------
-- Game Boy and Game Boy Color for MEGA65 (gbc4mega65)
--
-- MEGA65 keyboard and joystick to Game Boy joypad adapter
--
-- Runs in the clock domain of the core.
--
-- The MEGA65 keyboard mapping is identical to the original gbc4mega65 releases:
--    Cursor keys        Game Boy joypad (d-pad)
--    Space              Start
--    Return             Select
--    Left Shift         A
--    MEGA65 key         B
--
-- Joystick support including the four mapping modes of the original core (joy_map_i):
--    00 = Standard, Fire=A
--    01 = Standard, Fire=B
--    10 = Up=A, Fire=B      (moving up ALSO presses d-pad up: natural jump'n'run feeling)
--    11 = Up=B, Fire=A      (ditto)
--
-- The Game Boy reads the joypad via the classic P54 matrix-select mechanism: joy_p54_i
-- selects either the button or the direction row and joy_din_o returns the selected
-- row, low active.
--
-- This machine is based on Gameboy_MiSTer
-- Powered by MiSTer2MEGA65
-- MEGA65 port done by sy2002 in 2021 - 2026 and licensed under GPL v3
---------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity keyboard is
   port (
      clk_main_i           : in  std_logic;                 -- core clock

      -- Interface to the MEGA65 keyboard
      key_num_i            : in  integer range 0 to 79;     -- cycles through all MEGA65 keys
      key_pressed_n_i      : in  std_logic;                 -- low active: debounced feedback: is kb_key_num_i pressed right now?

      -- MEGA65 joysticks: both ports merged, low active
      -- bit order: 4 = fire, 3 = up, 2 = down, 1 = left, 0 = right
      joystick_i           : in  std_logic_vector(4 downto 0);

      -- joystick mapping mode, see header
      joy_map_i            : in  std_logic_vector(1 downto 0);

      -- Game Boy joypad interface (gb.v): row select and readout, low active
      joy_p54_i            : in  std_logic_vector(1 downto 0);
      joy_din_o            : out std_logic_vector(3 downto 0)
   );
end entity keyboard;

architecture beh of keyboard is

-- MEGA65 key codes that key_num_i is using while key_pressed_n_i is signalling
-- (low active) which key is pressed
constant m65_return        : integer := 1;
constant m65_horz_crsr     : integer := 2;   -- means cursor right in C64 terminology
constant m65_left_shift    : integer := 15;
constant m65_vert_crsr     : integer := 7;   -- means cursor down in C64 terminology
constant m65_space         : integer := 60;
constant m65_mega          : integer := 61;
constant m65_up_crsr       : integer := 73;  -- cursor up
constant m65_left_crsr     : integer := 74;  -- cursor left

-- low active per-key state of the MEGA65 keyboard
signal key_pressed_n       : std_logic_vector(79 downto 0) := (others => '1');

-- keys relevant for the Game Boy, low active
signal key_up_n            : std_logic;
signal key_down_n          : std_logic;
signal key_left_n          : std_logic;
signal key_right_n         : std_logic;
signal key_a_n             : std_logic;
signal key_b_n             : std_logic;
signal key_select_n        : std_logic;
signal key_start_n         : std_logic;

-- joystick directions, low active
signal joy_up_n            : std_logic;
signal joy_down_n          : std_logic;
signal joy_left_n          : std_logic;
signal joy_right_n         : std_logic;
signal joy_fire_n          : std_logic;

-- joystick after applying the mapping mode, low active
signal joy_a_n             : std_logic;
signal joy_b_n             : std_logic;

-- Game Boy joypad matrix, low active
-- directions: 3 = Down, 2 = Up, 1 = Left, 0 = Right
-- buttons:    3 = Start, 2 = Select, 1 = B, 0 = A
signal matrix_dir_n        : std_logic_vector(3 downto 0);
signal matrix_btn_n        : std_logic_vector(3 downto 0);

begin

   keyboard_state : process (clk_main_i)
   begin
      if rising_edge(clk_main_i) then
         key_pressed_n(key_num_i) <= key_pressed_n_i;
      end if;
   end process;

   key_right_n  <= key_pressed_n(m65_horz_crsr);
   key_left_n   <= key_pressed_n(m65_left_crsr);
   key_up_n     <= key_pressed_n(m65_up_crsr);
   key_down_n   <= key_pressed_n(m65_vert_crsr);
   key_a_n      <= key_pressed_n(m65_left_shift);
   key_b_n      <= key_pressed_n(m65_mega);
   key_select_n <= key_pressed_n(m65_return);
   key_start_n  <= key_pressed_n(m65_space);

   joy_fire_n   <= joystick_i(4);
   joy_up_n     <= joystick_i(3);
   joy_down_n   <= joystick_i(2);
   joy_left_n   <= joystick_i(1);
   joy_right_n  <= joystick_i(0);

   -- The four joystick mapping modes of the original gbc4mega65 core.
   -- In the modes 10 and 11 the joystick's "up" both moves up (d-pad) and presses the
   -- mapped button, so that games that use a button to jump feel natural with a joystick.
   map_joystick : process (all)
   begin
      case joy_map_i is
         when "00" =>                  -- Standard, Fire=A
            joy_a_n <= joy_fire_n;
            joy_b_n <= '1';
         when "01" =>                  -- Standard, Fire=B
            joy_a_n <= '1';
            joy_b_n <= joy_fire_n;
         when "10" =>                  -- Up=A, Fire=B
            joy_a_n <= joy_up_n;
            joy_b_n <= joy_fire_n;
         when others =>                -- Up=B, Fire=A
            joy_a_n <= joy_fire_n;
            joy_b_n <= joy_up_n;
      end case;
   end process;

   -- merge keyboard and joystick into the Game Boy's joypad matrix (low active)
   matrix_dir_n(0) <= key_right_n  and joy_right_n;
   matrix_dir_n(1) <= key_left_n   and joy_left_n;
   matrix_dir_n(2) <= key_up_n     and joy_up_n;
   matrix_dir_n(3) <= key_down_n   and joy_down_n;
   matrix_btn_n(0) <= key_a_n      and joy_a_n;
   matrix_btn_n(1) <= key_b_n      and joy_b_n;
   matrix_btn_n(2) <= key_select_n;
   matrix_btn_n(3) <= key_start_n;

   -- Game Boy joypad readout: joy_p54_i selects the matrix row (low active selects)
   --    "01": P15 = 0 selects the buttons
   --    "10": P14 = 0 selects the directions
   read_matrix : process (all)
   begin
      case joy_p54_i is
         when "01"   => joy_din_o <= matrix_btn_n;
         when "10"   => joy_din_o <= matrix_dir_n;
         when others => joy_din_o <= "1111";
      end case;
   end process;

end architecture beh;
