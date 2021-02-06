----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- QNICE Co-Processor for ROM loading and On-Screen-Menu
--
-- gbc4mega65 machine is based on Gameboy_MiSTer
-- QNICE Co-Processor is based on QNICE-FPGA done by The QNICE Development Team
-- MEGA65 port done by sy2002 in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;
use work.env1_globals.all;
use work.qnice_tools.all;

entity QNICE is
generic (
   VGA_DX            : integer;
   VGA_DY            : integer
);
port (
   -- QNICE MEGA65 hardware interface
   CLK50             : in std_logic;                  -- 50 MHz clock                                    
   RESET_N           : in std_logic;                  -- CPU reset button
      
   UART_RXD          : in std_logic;                  -- receive data, 115.200 baud, 8-N-1, rxd, txd only; rts/cts are not available
   UART_TXD          : out std_logic;                 -- send data, ditto
   
   SD_RESET          : out std_logic;
   SD_CLK            : out std_logic;
   SD_MOSI           : out std_logic;
   SD_MISO           : in std_logic;
   
   -- Host VGA interface
   pixelclock        : in std_logic;
   vga_x             : in integer range 0 to VGA_DX - 1;
   vga_y             : in integer range 0 to VGA_DY - 1;
   vga_rgb           : out std_logic_vector(7 downto 0); 

   -- Control and status register
   gbc_reset         : buffer std_logic;
   gbc_pause         : buffer std_logic;

   -- Interfaces to Game Boy's RAMs (MMIO):
   gbc_bios_addr     : out std_logic_vector(11 downto 0);
   gbc_bios_we       : out std_logic;
   gbc_bios_data_in  : out std_logic_vector(7 downto 0);
   gbc_bios_data_out : in std_logic_vector(7 downto 0);
      
   -- Information about the current game cartridge
   cart_cgb_flag     : buffer std_logic_vector(7 downto 0);
   cart_sgb_flag     : buffer std_logic_vector(7 downto 0);
   cart_mbc_type     : buffer std_logic_vector(7 downto 0);
   cart_rom_size     : buffer std_logic_vector(7 downto 0);
   cart_ram_size     : buffer std_logic_vector(7 downto 0);
   cart_old_licensee : buffer std_logic_vector(7 downto 0)

); 
end QNICE;

architecture beh of QNICE is

-- Constants for VGA output
constant FONT_DX                 : integer := 16;
constant FONT_DY                 : integer := 16;
constant CHARS_DX                : integer := VGA_DX / FONT_DX;
constant CHARS_DY                : integer := VGA_DY / FONT_DY;
constant CHAR_MEM_SIZE           : integer := CHARS_DX * CHARS_DY;

-- CPU control signals
signal cpu_addr                  : std_logic_vector(15 downto 0);
signal cpu_data_in               : std_logic_vector(15 downto 0);
signal cpu_data_out              : std_logic_vector(15 downto 0);
signal cpu_data_dir              : std_logic;
signal cpu_data_valid            : std_logic;
signal cpu_wait_for_data         : std_logic;
signal cpu_halt                  : std_logic;

-- reset control
signal reset_ctl                 : std_logic;
signal reset_pre_pore            : std_logic;
signal reset_post_pore           : std_logic;

-- QNICE standard MMIO signals
signal rom_en                    : std_logic;
signal rom_data_out              : std_logic_vector(15 downto 0);
signal ram_en                    : std_logic;
signal ram_busy                  : std_logic;
signal ram_data_out              : std_logic_vector(15 downto 0);
signal switch_data_out           : std_logic_vector(15 downto 0);
signal uart_en                   : std_logic;
signal uart_we                   : std_logic;
signal uart_reg                  : std_logic_vector(1 downto 0);
signal uart_cpu_ws               : std_logic;
signal uart_data_out             : std_logic_vector(15 downto 0);
signal eae_en                    : std_logic;
signal eae_we                    : std_logic;
signal eae_reg                   : std_logic_vector(2 downto 0);
signal eae_data_out              : std_logic_vector(15 downto 0);
signal sd_en                     : std_logic;
signal sd_we                     : std_logic;
signal sd_reg                    : std_logic_vector(2 downto 0);
signal sd_data_out               : std_logic_vector(15 downto 0);

-- GBC specific MMIO signals
signal csr_en                    :  std_logic;
signal csr_we                    : std_logic;
signal csr_data_out              : std_logic_vector(15 downto 0);
signal vram_en                   : std_logic;
signal vram_we                   : std_logic;
signal vram_data_out_i           : std_logic_vector(7 downto 0);
signal vram_data_out             : std_logic_vector(15 downto 0);
signal gbc_bios_en               : std_logic;
signal gbc_bios_data_out_16bit   : std_logic_vector(15 downto 0);

begin

   -- Merge data outputs from all devices into a single data input to the CPU.
   -- This requires that all devices output 0's when not selected.
   cpu_data_in <= rom_data_out            or
                  ram_data_out            or
                  switch_data_out         or
                  uart_data_out           or
                  eae_data_out            or
                  sd_data_out             or
                  csr_data_out            or
                  vram_data_out           or
                  gbc_bios_data_out_16bit;
                                    
   -- generate the general reset signal
   reset_ctl <= '1' when (reset_pre_pore = '1' or reset_post_pore = '1') else '0';                     
                  
   -- QNICE CPU
   cpu : entity work.QNICE_CPU
      port map
      (
         CLK                  => CLK50,
         RESET                => reset_ctl,
         WAIT_FOR_DATA        => cpu_wait_for_data,
         ADDR                 => cpu_addr,
         DATA_IN              => cpu_data_in,
         DATA_OUT             => cpu_data_out,
         DATA_DIR             => cpu_data_dir,
         DATA_VALID           => cpu_data_valid,
         HALT                 => cpu_halt,
         INS_CNT_STROBE       => open,
         INT_N                => '1',
         IGRANT_N             => open
      );
                  
   -- QNICE ROM
   rom : entity work.BROM
      generic map
      (
         FILE_NAME            => "../../QNICE/monitor/monitor.rom",
         ADDR_WIDTH           => 15,
         DATA_WIDTH           => 16,
         LATCH_ACTIVE         => false
      )
      port map
      (
         CLK                  => CLK50,
         ce                   => rom_en,
         address              => cpu_addr(14 downto 0),
         data                 => rom_data_out
      );
     
   -- RAM: up to 64kB consisting of up to 32.000 16 bit words
   ram : entity work.BRAM
      port map
      (
         clk                  => CLK50,
         ce                   => ram_en and not vram_en, -- VRAM is mapped from 0xD000
         address              => cpu_addr(14 downto 0),
         we                   => cpu_data_dir,         
         data_i               => cpu_data_out,
         data_o               => ram_data_out,
         busy                 => open         
      );

   -- special UART with FIFO that can be directly connected to the CPU bus
   uart : entity work.bus_uart
      generic map
      (
         DIVISOR              => UART_DIVISOR
      )
      port map
      (
         clk                  => CLK50,
         reset                => reset_ctl,
         rx                   => UART_RXD,
         tx                   => UART_TXD,
         rts                  => '0',
         cts                  => open,
         uart_en              => uart_en,
         uart_we              => uart_we,
         uart_reg             => uart_reg,
         uart_cpu_ws          => uart_cpu_ws,         
         cpu_data_in          => cpu_data_out,
         cpu_data_out         => uart_data_out
      );
      
   -- EAE - Extended Arithmetic Element (32-bit multiplication, division, modulo)
   eae_inst : entity work.eae
      port map
      (
         clk                  => CLK50,
         reset                => reset_ctl,
         en                   => eae_en,
         we                   => eae_we,
         reg                  => eae_reg,
         data_in              => cpu_data_out,
         data_out             => eae_data_out
      );

   -- SD Card
   sd_card : entity work.sdcard
      port map
      (
         clk                  => CLK50,
         reset                => reset_ctl,
         en                   => sd_en,
         we                   => sd_we,
         reg                  => sd_reg,
         data_in              => cpu_data_out,
         data_out             => sd_data_out,
         sd_reset             => SD_RESET,
         sd_clk               => SD_CLK,
         sd_mosi              => SD_MOSI,
         sd_miso              => SD_MISO
      );
    
    -- Standard QNICE-FPGA MMIO controller  
   mmio_std : entity work.mmio_mux
      generic map
      (
         GD_TIL               => false,
         GD_SWITCHES          => true,
         GD_HRAM              => false,
         GD_PORE              => false
      )
      port map (
         -- input from hardware
         HW_RESET             => not RESET_N,
         CLK                  => CLK50,
      
         -- input from CPU
         addr                 => cpu_addr,
         data_dir             => cpu_data_dir,
         data_valid           => cpu_data_valid,
         cpu_halt             => cpu_halt,
         cpu_igrant_n         => '1',
         
         -- let the CPU wait for data from the bus
         cpu_wait_for_data    => cpu_wait_for_data,
         
         -- ROM is enabled when the address is < $8000 and the CPU is reading
         rom_enable           => rom_en,
         rom_busy             => '0',
         
         -- RAM is enabled when the address is in ($8000..$FEFF)
         ram_enable           => ram_en,
         ram_busy             => '0',
                          
         -- SWITCHES is $FF00
         switch_reg_enable    => open,    -- hardcoded to zero (STDIN=STDOUT=UART)
         
         -- UART register range $FF10..$FF13
         uart_en              => uart_en,
         uart_we              => uart_we,
         uart_reg             => uart_reg,
         uart_cpu_ws          => uart_cpu_ws,
         
         -- Extended Arithmetic Element register range $FF18..$FF1F
         eae_en               => eae_en,
         eae_we               => eae_we,
         eae_reg              => eae_reg,
      
         -- SD Card register range $FF20..FF27
         sd_en                => sd_en,
         sd_we                => sd_we,
         sd_reg               => sd_reg,
         
         -- global state and reset management
         reset_pre_pore       => reset_pre_pore,
         reset_post_pore      => reset_post_pore,
                                 
         -- QNICE hardware unsupported by gbc4MEGA65
         til_reg0_enable      => open,
         til_reg1_enable      => open,         
         kbd_en               => open,
         kbd_we               => open,
         kbd_reg              => open,
         cyc_en               => open,
         cyc_we               => open,
         cyc_reg              => open,
         ins_en               => open,
         ins_we               => open,
         ins_reg              => open,
         pore_rom_enable      => open,
         pore_rom_busy        => '0',      
         tin_en               => open,
         tin_we               => open,
         tin_reg              => open,
         vga_en               => open,
         vga_we               => open,
         vga_reg              => open,
         hram_en              => open,
         hram_we              => open,
         hram_reg             => open, 
         hram_cpu_ws          => '0'          
      );
               
   -- Additional gbc4mega65 specific MMIO:
   -- 0xB000..0xBFFF: Game Cartridge RAM: 4kb gliding window defined by 0xFFE1
   -- 0xC000..0xCFFF: BIOS/BOOT "ROM RAM": 4kb
   -- 0xD000..0xDFFF: Screen RAM, "ASCII" codes
   -- 0xFFE0        : Game Boy control and status register
   csr_en                  <= '1' when cpu_addr(15 downto 0) = x"FFE0" else '0';
   csr_we                  <= csr_en and cpu_data_dir and cpu_data_valid;
   csr_data_out            <= x"000" & "00" & gbc_pause & gbc_reset when csr_en = '1' and csr_we = '0' else (others => '0');
   vram_en                 <= '1' when cpu_addr(15 downto 12) = x"D" else '0';
   vram_we                 <= vram_en and cpu_data_dir and cpu_data_valid;
   vram_data_out           <= x"00" & vram_data_out_i when vram_en = '1' and vram_we = '0' else (others => '0');
   gbc_bios_en             <= '1' when cpu_addr(15 downto 12) = x"C" else '0';
   gbc_bios_we             <= '1' when gbc_bios_en and cpu_data_dir and cpu_data_valid;
   gbc_bios_data_out_16bit <= x"00" & gbc_bios_data_out when gbc_bios_en = '1' and gbc_bios_we = '0' else (others => '0'); 
   gbc_bios_data_in        <= cpu_data_out(7 downto 0);
            
   -- Control and status register: Reset & Pause
   gbc_csr : process(clk50)
   begin
      if falling_edge(clk50) then
         if reset_ctl = '1' then
            gbc_reset <= '1';
            gbc_pause <= '0';
         elsif csr_we = '1' then
            gbc_reset <= cpu_data_out(0);
            gbc_pause <= cpu_data_out(1);
         end if;
      end if;
   end process;
   
   -- emulate the toggle switches as described in QNICE-FPGA's doc/README.md
   -- all zero: STDIN = STDOUT = UART
   switch_data_out <= (others => '0');
      
   -- Dual port & dual clock screen RAM / video RAM: contains the "ASCII" codes of the characters
   vram : entity work.dualport_2clk_ram
      generic map
      (
          ADDR_WIDTH          => f_log2(CHAR_MEM_SIZE),
          DATA_WIDTH          => 8
      )
      port map
      (
         clock_a              => not CLK50,        -- QNICE uses a tight timing and needs the RAM to be on the negative edge
         address_a            => (others => '0'),
         data_a               => cpu_data_out(7 downto 0),
         wren_a               => vram_we,
         q_a                  => vram_data_out_i,
   
         clock_b              => pixelclock,
         address_b            => (others => '0'),
         data_b               => (others => '0'),
         wren_b               => '0',
         q_b                  => open
      );         
end beh;
