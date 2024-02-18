----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- MEGA65 keyboard controller
--
-- Can be directly connected to the MiSTer Game Boy's core because it stores
-- the key presses in a matrix just like documented here:
-- https://gbdev.io/pandocs/Joypad_Input.html
--
-- done by sy2002 in 2021 and 2024 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity keyboard is
   port (
      clk_main_i           : in std_logic;               -- core clock
         
      -- Interface to the MEGA65 keyboard
      key_num_i            : in integer range 0 to 79;   -- cycles through all MEGA65 keys
      key_pressed_n_i      : in std_logic;               -- low active: debounced feedback: is kb_key_num_i pressed right now?
               
      -- joystick input with variable mapping
      -- joystick vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
      -- mapping: 00 = Standard, Fire=A
      --          01 = Standard, Fire=B
      --          10 = Up=A, Fire=B
      --          11 = Up=B, Fire=A
      -- make sure that this mapping is consistent with gbc.asm
      joystick_i           : in std_logic_vector(4 downto 0);
      joy_map_i            : in std_logic_vector(1 downto 0);
         
      -- interface to the GBC's internal logic (low active)
      -- joypad:   
      -- Bit 3 - P13 Input Down  or Start
      -- Bit 2 - P12 Input Up    or Select
      -- Bit 1 - P11 Input Left  or Button B
      -- Bit 0 - P10 Input Right or Button A   
      p54_i                : in std_logic_vector(1 downto 0);  -- "01" selects buttons and "10" selects direction keys
      joypad_o             : out std_logic_vector(3 downto 0)
   );
end keyboard;

architecture beh of keyboard is

-- MEGA65 key codes that kb_key_num_i is using while
-- kb_key_pressed_n_i is signalling (low active) which key is pressed
constant m65_ins_del       : integer := 0;
constant m65_return        : integer := 1;
constant m65_horz_crsr     : integer := 2;   -- means cursor right in C64 terminology
constant m65_f7            : integer := 3;
constant m65_f1            : integer := 4;
constant m65_f3            : integer := 5;
constant m65_f5            : integer := 6;
constant m65_vert_crsr     : integer := 7;   -- means cursor down in C64 terminology
constant m65_3             : integer := 8;
constant m65_w             : integer := 9;
constant m65_a             : integer := 10;
constant m65_4             : integer := 11;
constant m65_z             : integer := 12;
constant m65_s             : integer := 13;
constant m65_e             : integer := 14;
constant m65_left_shift    : integer := 15;
constant m65_5             : integer := 16;
constant m65_r             : integer := 17;
constant m65_d             : integer := 18;
constant m65_6             : integer := 19;
constant m65_c             : integer := 20;
constant m65_f             : integer := 21;
constant m65_t             : integer := 22;
constant m65_x             : integer := 23;
constant m65_7             : integer := 24;
constant m65_y             : integer := 25;
constant m65_g             : integer := 26;
constant m65_8             : integer := 27;
constant m65_b             : integer := 28;
constant m65_h             : integer := 29;
constant m65_u             : integer := 30;
constant m65_v             : integer := 31;
constant m65_9             : integer := 32;
constant m65_i             : integer := 33;
constant m65_j             : integer := 34;
constant m65_0             : integer := 35;
constant m65_m             : integer := 36;
constant m65_k             : integer := 37;
constant m65_o             : integer := 38;
constant m65_n             : integer := 39;
constant m65_plus          : integer := 40;
constant m65_p             : integer := 41; 
constant m65_l             : integer := 42;
constant m65_minus         : integer := 43;
constant m65_dot           : integer := 44;
constant m65_colon         : integer := 45;
constant m65_at            : integer := 46;
constant m65_comma         : integer := 47;
constant m65_gbp           : integer := 48;
constant m65_asterisk      : integer := 49;
constant m65_semicolon     : integer := 50;
constant m65_clr_home      : integer := 51;
constant m65_right_shift   : integer := 52;
constant m65_equal         : integer := 53;
constant m65_arrow_up      : integer := 54;  -- symbol, not cursor
constant m65_slash         : integer := 55;
constant m65_1             : integer := 56;
constant m65_arrow_left    : integer := 57;  -- symbol, not cursor
constant m65_ctrl          : integer := 58;
constant m65_2             : integer := 59;
constant m65_space         : integer := 60;
constant m65_mega          : integer := 61;
constant m65_q             : integer := 62;
constant m65_run_stop      : integer := 63;
constant m65_no_scrl       : integer := 64;
constant m65_tab           : integer := 65;
constant m65_alt           : integer := 66;
constant m65_help          : integer := 67;
constant m65_f9            : integer := 68;
constant m65_f11           : integer := 69;
constant m65_f13           : integer := 70;
constant m65_esc           : integer := 71;
constant m65_capslock      : integer := 72;
constant m65_up_crsr       : integer := 73;  -- cursor up
constant m65_left_crsr     : integer := 74;  -- cursor left
constant m65_restore       : integer := 75;

-- Game Boy's keyboard matrix: low active matrix with 2 rows and 4 columns
-- Refer to "doc/assets/spectrum_keyboard_ports.png" to learn how it works
-- One more column was added to support additional keys used by QNICE
type matrix_reg_t is array(0 to 1) of std_logic_vector(3 downto 0);
signal matrix : matrix_reg_t := (others => "1111");  -- low active, i.e. "1111" means "no key pressed"

-- mapped joystick that can be connected with Game Boy's input matrix:
-- bit order (low active)
--    0 = up
--    1 = down
--    2 = left
--    3 = right
--    4 = A
--    5 = B
signal   joystick_m        : std_logic_vector(5 downto 0);
constant JM_UP             : integer := 0;
constant JM_DOWN           : integer := 1;
constant JM_RIGHT          : integer := 2;
constant JM_LEFT           : integer := 3;
constant JM_A              : integer := 4;
constant JM_B              : integer := 5;

begin

   -- fill the matrix registers that will be read by the Game Boy
   -- since we just need very few keys, we are not using a nice matrix table like zxuno4mega65;
   -- instead it is just a mere case structure
   write_matrix : process(clk_main_i)
   variable key_up, key_down, key_left, key_right, key_a, key_b : std_logic := '1';
   begin
      if rising_edge(clk_main_i) then
         case key_num_i is
            when m65_horz_crsr   => key_right    := key_pressed_n_i;       -- cursor right
            when m65_vert_crsr   => key_down     := key_pressed_n_i;       -- cursor down
            when m65_up_crsr     => key_up       := key_pressed_n_i;       -- cursor up
            when m65_left_crsr   => key_left     := key_pressed_n_i;       -- cursor left
            when m65_return      => matrix(1)(2) <= key_pressed_n_i;       -- Return      => Select
            when m65_space       => matrix(1)(3) <= key_pressed_n_i;       -- Space       => Start
            when m65_left_shift  => key_a        := key_pressed_n_i;       -- Left Shift  => A
            when m65_mega        => key_b        := key_pressed_n_i;       -- Mega key    => B
            when others => null;
         end case;
         
         matrix(0)(0) <= key_right and joystick_m(JM_RIGHT);
         matrix(0)(3) <= key_down  and joystick_m(JM_DOWN);
         matrix(0)(2) <= key_up    and joystick_m(JM_UP);
         matrix(0)(1) <= key_left  and joystick_m(JM_LEFT);
         matrix(1)(0) <= key_a     and joystick_m(JM_A);
         matrix(1)(1) <= key_b     and joystick_m(JM_B);
      end if;
   end process;
   
   -- perform joystick mapping
   map_joystick : process(all)
   begin
      -- joystick input vector: low active; bit order: 4=fire, 3=up, 2=down, 1=left, 0=right
      joystick_m(JM_LEFT)  <= joystick_i(1);
      joystick_m(JM_RIGHT) <= joystick_i(0);
      joystick_m(JM_UP)    <= joystick_i(3);      
      joystick_m(JM_DOWN)  <= joystick_i(2);
      
      -- low active; make sure this mapping is consistent to gbc.asm      
      case joy_map_i is
         -- 00 = Standard, Fire=A      
         when "00" =>
            joystick_m(JM_A)  <= joystick_i(4);
            joystick_m(JM_B)  <= '1';
            
         -- 01 = Standard, Fire=B
         when "01" =>
            joystick_m(JM_A)  <= '1';
            joystick_m(JM_B)  <= joystick_i(4);
            
         -- 10 = Up=A, Fire=B
         when "10" =>   
            joystick_m(JM_A)  <= joystick_i(3);
            joystick_m(JM_B)  <= joystick_i(4);
            
         -- 11 = Up=B, Fire=A
         when "11" =>
            joystick_m(JM_A)  <= joystick_i(4);
            joystick_m(JM_B)  <= joystick_i(3);            
      end case;
   end process;
      
   -- return matrix to Game Boy
   read_matrix : process(all)
   begin
      case p54_i is
         when "01"   => joypad_o <= matrix(1);
         when "10"   => joypad_o <= matrix(0);
         when others => joypad_o <= "1111";
      end case;
   end process;

end beh;

