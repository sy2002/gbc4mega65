----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- MEGA65 keyboard controller
--
-- Can be directly connected to the MiSTer Game Boy's core because it stores
-- the key presses in a matrix just like documented here:
-- https://gbdev.io/pandocs/#ff00-p1-joyp-joypad-r-w
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity keyboard is
generic (
   CLOCK_SPEED : integer
);
port (
   clk         : in std_logic;
       
   -- interface to the MEGA65 keyboard controller       
   kio8        : out std_logic;        -- clock to keyboard
   kio9        : out std_logic;        -- data output to keyboard
   kio10       : in std_logic;         -- data input from keyboard
   
   -- joystick input with variable mapping (bit order as described below, bit 4 = fire)
--   joystick    : in std_logic_vector(4 downto 0);
--   joy_up_a    : std_logic;            -- joystick up = A, fire = B, otherwise fire = A and no B on joystick
      
   -- interface to the GBC's internal logic (low active)
   -- joypad:   
   -- Bit 3 - P13 Input Down  or Start    (0=Pressed)
   -- Bit 2 - P12 Input Up    or Select   (0=Pressed)
   -- Bit 1 - P11 Input Left  or Button B (0=Pressed)
   -- Bit 0 - P10 Input Right or Button A (0=Pressed)   
   p54         : in std_logic_vector(1 downto 0);  -- "01" selects buttons and "10" selects direction keys
   joypad      : out std_logic_vector(3 downto 0);
   
   -- interface to QNICE
   full_matrix : out std_logic_vector(15 downto 0)
);
end keyboard;

architecture beh of keyboard is

signal matrix_col          : std_logic_vector(7 downto 0);
signal matrix_col_idx      : integer range 0 to 9 := 0;
signal key_num             : integer range 0 to 79;
signal key_status_n        : std_logic;

-- Special keys that are not mapped to and not used in context of the Spectrum's matrix
signal key_esc             : std_logic;
signal m65_capslock_n      : std_logic;

-- Game Boy's keyboard matrix: low active matrix with 2 rows and 4 columns
-- Refer to "doc/assets/spectrum_keyboard_ports.png" to learn how it works
-- One more column was added to support additional keys used by QNICE
type matrix_reg_t is array(0 to 2) of std_logic_vector(3 downto 0);
signal matrix : matrix_reg_t := (others => "1111");  -- low active, i.e. "1111" means "no key pressed"

begin

   -- keyboard matrix: convert to high-active and output full matrix
   full_matrix <= x"0" & not matrix(2) & not matrix(1) & not matrix(0);
   
   m65driver : entity work.mega65kbd_to_matrix
   port map
   (
       ioclock          => clk,
      
       flopmotor        => '0',
       flopled          => '0',
       powerled         => '1',    
       
       kio8             => kio8,
       kio9             => kio9,
       kio10            => kio10,
      
       matrix_col       => matrix_col,
       matrix_col_idx   => matrix_col_idx,
       
       capslock_out     => open     
   );
   
   m65matrix_to_keynum : entity work.matrix_to_keynum
   generic map
   (
      scan_frequency    => 1000,
      clock_frequency   => CLOCK_SPEED      
   )
   port map
   (
      clk               => clk,
      reset_in          => '0',

      matrix_col => matrix_col,
      matrix_col_idx => matrix_col_idx,
      
      m65_key_num => key_num,
      m65_key_status_n => key_status_n,
      
      suppress_key_glitches => '1',
      suppress_key_retrigger => '0',
      
      bucky_key => open   
   );
   
   matrix_col_idx_handler : process(clk)
   begin
      if rising_edge(clk) then
         if matrix_col_idx < 9 then
           matrix_col_idx <= matrix_col_idx + 1;
         else
           matrix_col_idx <= 0;
         end if;      
      end if;
   end process;      
   
   -- fill the matrix registers that will be read by the Game Boy
   -- since we just need very few keys, we are not using a nice matrix table like zxuno4mega65;
   -- instead it is just a mere case structure
   write_matrix : process(clk)
   begin
      if rising_edge(clk) then
         case key_num is
            when 2      => matrix(0)(0) <= key_status_n;       -- cursor right
            when 7      => matrix(0)(3) <= key_status_n;       -- cursor down
            when 73     => matrix(0)(2) <= key_status_n;       -- cursor up
            when 74     => matrix(0)(1) <= key_status_n;       -- cursor left
            when 1      => matrix(1)(2) <= key_status_n;       -- Return      => Select
            when 60     => matrix(1)(3) <= key_status_n;       -- Space       => Start
            when 15     => matrix(1)(0) <= key_status_n;       -- Left Shift  => A
            when 61     => matrix(1)(1) <= key_status_n;       -- Mega key    => B
            when 63     => matrix(2)(0) <= key_status_n;       -- Run/Stop    => File browser
            when 67     => matrix(2)(1) <= key_status_n;       -- Help        => Options menu  
            when others => null;
         end case;
      end if;
   end process;

   -- return matrix to Game Boy
   read_matrix : process(p54, matrix)
   begin
      case p54 is
         when "01"   => joypad <= matrix(1);
         when "10"   => joypad <= matrix(0);
         when others => joypad <= "1111";
      end case;
   end process;
end beh;
