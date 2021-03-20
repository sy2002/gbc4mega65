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

entity mbc is
generic (
   ROM_WIDTH   : integer
);
port (
   -- Game Boy's clock and reset
   gb_clk         : in std_logic;
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
end mbc;

architecture beh of mbc is

signal rom_mask         : std_logic_vector(8 downto 0);

-- MBC control registers
signal mbc_rom_bank_reg : std_logic_vector(8 downto 0);

begin

   rom_rd   <= cart_rd;
   cart_do  <= rom_data;

   -- the rom mask is used to ensure proper mirroring as described in https://gbdev.io/pandocs/#memory-bank-controllers
   -- and in MiSTer's mbc.sv
   calc_rom_mask : process(cart_rom_size)
   begin
      case cart_rom_size is
         when x"00"  => rom_mask <= "000000001";      -- 0 - 0 - 2 banks, 32k direct mapped
         when x"01"  => rom_mask <= "000000011";      -- 1 - 4 banks = 64k
         when x"02"  => rom_mask <= "000000111";      -- 2 - 8 banks = 128k
         when x"03"  => rom_mask <= "000001111";      -- 3 - 16 banks = 256k
         when x"04"  => rom_mask <= "000011111";      -- 4 - 32 banks = 512k
         when x"05"  => rom_mask <= "000111111";      -- 5 - 64 banks = 1M
         when x"06"  => rom_mask <= "001111111";      -- 6 - 128 banks = 2M
         when x"07"  => rom_mask <= "011111111";      -- 7 - 256 banks = 4M
         when x"08"  => rom_mask <= "111111111";      -- 8 - 512 banks = 8M
         when x"52"  => rom_mask <= "001111111";      -- $52 - 72 banks = 1.1M
         when x"53"  => rom_mask <= "001111111";      -- $53 - 80 banks = 1.2M
         when x"54"  => rom_mask <= "001111111";      -- $54 - 96 banks = 1.5M                 
         when others => rom_mask <= "001111111";      -- like $54 according to mbc.sv
      end case;
   end process;
   
   calc_rom_addr : process(cart_mbc_type, cart_addr, mbc_rom_bank_reg, rom_mask)
   variable rom_bank : std_logic_vector(8 downto 0);
   begin
      rom_addr <= (others => '0');
      rom_bank := mbc_rom_bank_reg and rom_mask;
            
      case cart_mbc_type is      
         -- no MBC: direct mapped ROM
         when x"00" =>
            rom_addr(15 downto 0) <= cart_addr;

         -- MBC 1
         when x"01" =>
            -- $0000-$3FFF: lower 16KB are hard wired
            if cart_addr(15 downto 14) = "00" then
               rom_addr(13 downto 0) <= cart_addr(13 downto 0);
            -- $4000-$7FFF: ROM bank $01-$7F
            elsif cart_addr(15 downto 14) = "01" then            
               if rom_bank = x"00" then
                  rom_bank := x"01";
               end if;
               rom_addr <= rom_bank(ROM_WIDTH - 14 - 1 downto 0) & cart_addr(13 downto 0);            
            end if;
            
         -- MBC 2 & MBC 2 + Battery
         when x"05" =>
         when x"06" =>
            -- $0000-$3FFF: lower 16KB are hard wired
            if cart_addr(15 downto 14) = "00" then
               rom_addr(13 downto 0) <= cart_addr(13 downto 0);
            -- $4000-$7FFF: ROM bank $01-$7F
            elsif cart_addr(15 downto 14) = "01" then            
               if rom_bank = x"00" then
                  rom_bank := x"01";
               end if;
               rom_addr <= rom_bank(ROM_WIDTH - 14 - 1 downto 0) & cart_addr(13 downto 0);            
            end if;
                  
         -- unsupported MBC
         when others => null;
      end case;                        
   end process;    

   write_registers : process(gb_clk)
   begin
      if rising_edge(gb_clk) then
         if gb_reset = '1' then
            mbc_rom_bank_reg <= "0" & x"01";
         else
            if cart_wr = '1' then
               case cart_mbc_type is
                  -- MBC 1, MBC2, MBC 2 + Battery 
                  when x"01" =>
                  when x"05" =>
                  when x"06" =>
                     case cart_addr(15 downto 13) is
                        -- $2000-$3FFF: ROM bank number (write only)
                        when "001" =>
                           mbc_rom_bank_reg(4 downto 0) <= cart_di(4 downto 0);
                        -- $4000-$5FFF:: RAM bank number or upper bits of ROM bank number (write only)
                        when "010" =>                        
                           mbc_rom_bank_reg(6 downto 5) <= cart_di(1 downto 0); 
                                             
                        -- unsupported MBC registers
                        when others => null;
                     end case;                  
                                       
                  -- unsupported MBC
                  when others => null;
               end case;
            end if;
         end if;
      end if;
   end process;

end beh;