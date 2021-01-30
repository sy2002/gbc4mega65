----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- Dual Port Dual Clock RAM: Drop-in replacement for "dpram.vhd"
--
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity dualport_2clk_ram is
	generic (
		 ADDR_WIDTH : integer := 8;
		 DATA_WIDTH : integer := 8
	); 
	port
	(
		clock_a      : IN STD_LOGIC;
		address_a    : IN STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
		data_a       : IN STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);
		wren_a       : IN STD_LOGIC := '0';
		q_a          : OUT STD_LOGIC_VECTOR (data_width-1 DOWNTO 0);

		clock_b      : IN STD_LOGIC;
		address_b    : IN STD_LOGIC_VECTOR (addr_width-1 DOWNTO 0);
		data_b       : IN STD_LOGIC_VECTOR (data_width-1 DOWNTO 0) := (others => '0');
		wren_b       : IN STD_LOGIC := '0';
		q_b          : OUT STD_LOGIC_VECTOR (data_width-1 DOWNTO 0)
	);
end dualport_2clk_ram;

architecture beh of dualport_2clk_ram is

type        memory_t is array(0 to 2**ADDR_WIDTH-1) of std_logic_vector((DATA_WIDTH-1) downto 0);
signal      ram               : memory_t;
attribute   ram_style         : string;
attribute   ram_style of ram  : signal is "block";

signal      address_a_int     : integer;
signal      address_b_int     : integer;

begin
   address_a_int <= to_integer(unsigned(address_a));
   address_b_int <= to_integer(unsigned(address_b));

   -- Port A
   write_a : process(clock_a)
   begin
      if rising_edge(clock_a) then
         if wren_a = '1' then
            ram(address_a_int) <= data_a;
         end if;
         q_a <= ram(address_a_int);         
      end if;
   end process;

   -- Port B
   write_b : process(clock_b)
   begin
      if rising_edge(clock_b) then
         if wren_b = '1' then
            ram(address_b_int) <= data_b;
         end if;
         q_b <= ram(address_b_int);         
      end if;
   end process;
end beh;							