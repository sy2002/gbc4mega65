----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- Memory Bank Controller (MBC)
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity mbc_wrapper is
generic (
   ROM_WIDTH   : integer
);
port (
   -- Game Boy's clock and reset
   gb_clk         : in std_logic;
   gb_ce_2x       : in std_logic;
   gb_reset       : in std_logic;

   -- Game Boy's cartridge interface
   cart_addr      : in std_logic_vector(15 downto 0);
   cart_rd        : in std_logic;
   cart_wr        : in std_logic;
   cart_do        : out std_logic_vector(7 downto 0);
   cart_di        : in std_logic_vector(7 downto 0);
   
   -- Cartridge ROM interface
   rom_addr       : out std_logic_vector(ROM_WIDTH - 1 downto 0);
   rom_rd         : out std_logic;
   rom_data       : in std_logic_vector(7 downto 0);
   
   -- Cartridge flags
   cart_mbc_type  : in std_logic_vector(7 downto 0);
   cart_rom_size  : in std_logic_vector(7 downto 0);
   cart_ram_size  : in std_logic_vector(7 downto 0)   
);
end mbc_wrapper;

architecture beh of mbc_wrapper is

signal   rom_addr_23bit : std_logic_vector(22 downto 0);

begin

   rom_addr <= rom_addr_23bit(ROM_WIDTH - 1 downto 0);
   rom_rd   <= cart_rd;
   cart_do  <= rom_data;
  
   mbc_i : entity work.mbc
      port map
      (
         clk_sys        => gb_clk,
         ce_cpu2x       => gb_ce_2x,         
         clkram         => gb_clk,
         reset          => gb_reset,
         
         cart_addr      => cart_addr,
	      cart_rd        => cart_rd,
         cart_wr        => cart_wr,
         cart_di        => cart_di,
         
         rom_addr       => rom_addr_23bit,
         
         cart_mbc_type  => cart_mbc_type,
         cart_rom_size  => cart_rom_size,
         cart_ram_size  => cart_ram_size
      );

end beh;