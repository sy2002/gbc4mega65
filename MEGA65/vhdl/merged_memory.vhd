-------------------------------------------------------------------------------------------------
-- VHDLBoy port for MEGA65
--
-- Merged Memory: VHDLBoy expects > 8 MB RAM organized in > 2 MB of 32bit words,
-- which is organized according to this layout:
--
--    Game ROM start     : 0           (2M words x 32 bit   = 8 MB, we support 64 KB) 
--    Game RAM start     : 2,097,152   (128k words x 8 bit  = 128 KB, we support 128 KB)
--    WRAM start         : 2,228,224   (32k words x 8 bit   = 32 KB, we support 32 KB)
--    Boot ROM start     : 2,260,992   (4k words x 32 bit   = 16 KB, we support 16 KB)
--    HRAM start         : 2,265,088   (128 Bytes x 8 bit   = 128 Bytes, we support 128 Bytes)
--
-- As we are currently not having this amount of RAM, we are supporting
-- smaller ROMs and RAM requirements only.
--
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
-------------------------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity merged_memory is
port (
   CLK            : in std_logic;   
   addr           : in std_logic_vector(21 downto 0);   
   data_in        : in std_logic_vector(31 downto 0);
   data_out       : out std_logic_vector(31 downto 0);
   we             : in std_logic;
   req            : in std_logic;
   valid          : out std_logic
);
end merged_memory;

architecture beh of merged_memory is

-- taken from vhdlboy/gameboy_memorymux.vhd
constant GB_Gamerom_start  : integer :=       0;
constant GB_Gameram_start  : integer := 2097152;
constant GB_WRam_start     : integer := 2228224;
constant GB_BootRom_start  : integer := 2260992;
constant GB_HRAM_start     : integer := 2265088;

-- ROM/RAM sizes
constant GAME_ROM_SIZE     : integer := 16;
constant GAME_RAM_SIZE     : integer := 17;
constant WRAM_SIZE         : integer := 15;
constant BOOT_ROM_SIZE     : integer := 12;
constant HRAM_SIZE         : integer := 7;

-- adjusted address for each ROM/RAM
signal   game_rom_addr     : std_logic_vector(GAME_ROM_SIZE - 1 downto 0);
signal   game_ram_addr     : std_logic_vector(GAME_RAM_SIZE - 1 downto 0);
signal   WRAM_addr         : std_logic_vector(WRAM_SIZE - 1 downto 0);
signal   boot_rom_addr     : std_logic_vector(BOOT_ROM_SIZE - 1 downto 0);
signal   HRAM_addr         : std_logic_vector(HRAM_SIZE - 1 downto 0);

-- various chip-enable signals to control the multiple ROMs and RAMs
signal   game_rom_ce       : std_logic;
signal   game_ram_ce       : std_logic;
signal   WRAM_ce           : std_logic;
signal   boot_rom_ce       : std_logic;
signal   HRAM_ce           : std_logic;

-- various data out signals that are merged into the global data out
-- Important: If a chip is not enabled, it needs to return zero
signal   game_rom_data_out : std_logic_vector(31 downto 0);
signal   game_ram_data_out : std_logic_vector(7 downto 0);
signal   WRAM_data_out     : std_logic_vector(7 downto 0);
signal   boot_rom_data_out : std_logic_vector(31 downto 0);
signal   HRAM_data_out     : std_logic_vector(7 downto 0);

begin
   
   latch_data_out : process(CLK)
   begin
      if rising_edge(CLK) then
         valid <= '0';
         -- delay valid by 1 clock cycle to cater for the BRAM/Game Boy timing
         if req = '1' then
            valid    <= '1';         
            data_out <=             game_rom_data_out or
                        x"000000" & game_ram_data_out or 
                        x"000000" & WRAM_data_out     or
                                    boot_rom_data_out or
                        x"000000" & HRAM_data_out;
         end if;
      end if;
   end process;
                  
   -- adjusted address for each ROM/RAM, so that each ROM/RAM can internall start from zero
   game_rom_addr  <= addr(15 downto 0);
   game_ram_addr  <= std_logic_vector(to_unsigned(to_integer(unsigned(addr)) - GB_Gameram_start, GAME_RAM_SIZE));
   WRAM_addr      <= std_logic_vector(to_unsigned(to_integer(unsigned(addr)) - GB_WRam_start, WRAM_SIZE));
   boot_rom_addr  <= std_logic_vector(to_unsigned(to_integer(unsigned(addr)) - GB_BootRom_start, BOOT_ROM_SIZE));
   HRAM_addr      <= std_logic_vector(to_unsigned(to_integer(unsigned(addr)) - GB_HRAM_start, HRAM_SIZE));
                                               
   select_ram_or_rom : process(addr)
   variable addr_i : integer;
   begin
      game_rom_ce <= '0';
      game_ram_ce <= '0';
      WRAM_ce     <= '0';
      boot_rom_ce <= '0';
      hram_ce     <= '0';
      
      addr_i := to_integer(unsigned(addr));

      -- this if/elsif section needs to be arranged: from largest to smallest address
      if addr_i >= GB_HRAM_start then
         HRAM_ce <= '1';
      elsif addr_i >= GB_BootRom_start then
         boot_rom_ce <= '1';
      elsif addr_i >= GB_WRam_start then
         WRAM_ce <= '1';
      elsif addr_i >= GB_Gameram_start then
         game_ram_ce <= '1';
      else
         game_rom_ce <= '1';
      end if;         
   end process;

   boot_rom : entity work.BROM
      generic map
      (
         FILE_NAME   => "../../rom/cgb_bios.rom",
         ADDR_WIDTH  => BOOT_ROM_SIZE,
         DATA_WIDTH  => 32
      )
      port map
      (
         CLK         => CLK,
         ce          => boot_rom_ce,
         address     => boot_rom_addr,
         data        => boot_rom_data_out
      );

   game_rom : entity work.BROM
      generic map
      (
         FILE_NAME   => "../../rom/mario.rom",
         ADDR_WIDTH  => GAME_ROM_SIZE,
         DATA_WIDTH  => 32
      )
      port map
      (
         CLK         => CLK,
         ce          => game_rom_ce,
         address     => game_rom_addr,
         data        => game_rom_data_out
      );
      
   game_ram : entity work.BRAM
      generic map
      (
         ADDR_WIDTH  => GAME_RAM_SIZE,
         DATA_WIDTH  => 8
      )
      port map
      (
         CLK         => CLK,
         ce          => game_ram_ce,
         we          => we,
         address     => game_ram_addr,
         data_in     => data_in(7 downto 0),
         data_out    => game_ram_data_out
      );
      
   WRAM : entity work.BRAM
      generic map
      (
         ADDR_WIDTH  => WRAM_SIZE,
         DATA_WIDTH  => 8
      )
      port map
      (
         CLK         => CLK,
         ce          => WRAM_ce,
         we          => we,
         address     => WRAM_addr,
         data_in     => data_in(7 downto 0),
         data_out    => WRAM_data_out
      );
   
   HRAM : entity work.BRAM
      generic map
      (
         ADDR_WIDTH  => HRAM_SIZE,
         DATA_WIDTH  => 8
      )
      port map
      (
         CLK         => CLK,
         ce          => HRAM_ce,
         we          => we,
         address     => HRAM_addr,
         data_in     => data_in(7 downto 0),
         data_out    => HRAM_data_out
      );

end beh;
