----------------------------------------------------------------------------------
-- VHDLBoy port for MEGA65
--
-- Block RAM
--
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity BRAM is
generic (
   ADDR_WIDTH  : integer;
   DATA_WIDTH  : integer
);
port (
   clk         : in std_logic;
   address     : in std_logic_vector(ADDR_WIDTH - 1 downto 0);
   data_in     : in std_logic_vector(DATA_WIDTH - 1 downto 0);
   data_out    : out std_logic_vector(DATA_WIDTH - 1 downto 0);
   ce          : in std_logic;
   we          : in std_logic
);
end BRAM;

architecture beh of BRAM is

constant RAM_DEPTH : integer := 2**ADDR_WIDTH;
type RAM is array (0 to RAM_DEPTH - 1) of std_logic_vector(DATA_WIDTH - 1 downto 0);

signal   mem         : RAM;
signal   data_o      : std_logic_vector (DATA_WIDTH - 1 downto 0);
signal   address_int : integer;
  
begin

   data_out    <= data_o when (ce = '1' and we = '0') else (others => '0');
   address_int <= to_integer(unsigned(address));

   mem_read_write : process(clk)
   begin
      if falling_edge(clk) then
         if (ce = '1' and we = '1') then
            mem(address_int) <= data_in;
         end if;
         
         data_o <= mem(address_int);
      end if;
   end process;
   
end beh;
