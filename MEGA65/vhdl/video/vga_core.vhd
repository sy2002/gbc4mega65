----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- VGA core interface
--
-- This block converts the 15-bit RGB of the Game Boy to 24-bit RGB
-- that can be displayed on screen (includes color modes and color grading)
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 and MJoergen in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_core is
   generic  (
      G_VGA_DX               : natural;  -- 800
      G_VGA_DY               : natural;  -- 600
      G_GB_DX                : natural;  -- 160
      G_GB_DY                : natural;  -- 144
      G_GB_TO_VGA_SCALE      : natural   -- 4 : 160x144 => 640x576
   );
   port (
      -- pixel clock and current position on screen relative to pixel clock
      clk_i                  : in  std_logic;
      vga_col_i              : in  integer range 0 to G_VGA_DX - 1;
      vga_row_i              : in  integer range 0 to G_VGA_DY - 1;
      
      -- double buffering information for being used by the display decoder:
      --   vga_core_dbl_buf_i: information to which "page" the core is currently writing to:
      --   0 = page 0 = 0..32767, 1 = page 1 = 32768..65535
      --   vga_core_dbl_buf_ptr_i: lcd pointer into which the core is currently writing to 
      vga_core_dbl_buf_i     : in  std_logic;
      vga_core_dbl_buf_ptr_i : in  std_logic_vector(14 downto 0);
         
      -- 15-bit Game Boy RGB that will be converted
      vga_core_vram_addr_o   : out std_logic_vector(15 downto 0);
      vga_core_vram_data_i   : in  std_logic_vector(14 downto 0);
      
      -- Rendering attributes
      vga_color_i            : std_logic;      -- 0=classic Game Boy, 1=Game Boy Color
      vga_color_mode_i       : std_logic;      -- 0=fully saturated colors, 1=LCD emulation
            
      -- 24-bit RGB that can be displayed on screen
      vga_core_on_o          : out std_logic;
      vga_core_rgb_o         : out std_logic_vector(23 downto 0)    -- 23..0 = RGB, 8 bits each
   );
end vga_core;

architecture synthesis of vga_core is

   signal vga_col_next    : integer range 0 to G_VGA_DX - 1;
   signal vga_row_next    : integer range 0 to G_VGA_DY - 1;
   signal vga_core_on     : std_logic;
   
   -- vga_core_dbl_buf_i tells us, where the core is currently writing to
   -- double_buf_read defines, which "bank" we are reading from: 0=0..32767, 1=32768..65535
   signal double_buf_read : std_logic := '0';

begin

   -- Scaler: 160 x 144 => 4x => 640 x 576
   -- Scaling by 4 is a convenient special case: We just need to use a SHR operation.
   -- We are doing this by taking the bits "9 downto 2" from the current column and row.
   -- This is a hardcoded and very fast operation.
   p_scaler : process (all)
      variable src_x: std_logic_vector(9 downto 0);
      variable src_y: std_logic_vector(9 downto 0);
      variable dst_x: std_logic_vector(7 downto 0);
      variable dst_y: std_logic_vector(7 downto 0);
      variable dst_x_i: integer range 0 to G_GB_DX - 1;
      variable dst_y_i: integer range 0 to G_GB_DY - 1;
      variable nextrow: integer range 0 to G_GB_DY - 1;
   begin
      src_x   := std_logic_vector(to_unsigned(vga_col_i, 10));
      src_y   := std_logic_vector(to_unsigned(vga_row_i, 10));
      dst_x   := src_x(9 downto 2);
      dst_y   := src_y(9 downto 2);
      dst_x_i := to_integer(unsigned(dst_x));
      dst_y_i := to_integer(unsigned(dst_y));
      nextrow := dst_y_i + 1;

      -- The dual port & dual clock RAM needs one clock cycle to provide the data. Therefore we need
      -- to always address one pixel ahead of where we currently stand
      if dst_x_i < G_GB_DX - 1 then
         vga_col_next <= dst_x_i + 1;
         vga_row_next <= dst_y_i;
      else
         vga_col_next <= 0;
         if nextrow < G_GB_DY then
            vga_row_next <= nextrow;
         else
            vga_row_next <= 0;
         end if;
      end if;
   end process p_scaler;
   
   dbl_buf : process (clk_i)
   begin
      if rising_edge(clk_i) then
         if vga_row_next = 0 then
		      -- Read from write buffer if it is far enough (as in "60 rows" equals 1/3 of the screen) ahead, ...
            if to_integer(unsigned(vga_core_dbl_buf_ptr_i)) >= G_GB_DX * 60 then
               double_buf_read <= vga_core_dbl_buf_i;
            -- ... otherwise read from the double buffer that is currently not being written to              
            else
               double_buf_read <= not vga_core_dbl_buf_i;
            end if;           
         end if;
      end if;
   end process;

   vga_core_vram_addr_o <= double_buf_read & std_logic_vector(to_unsigned(vga_row_next * G_GB_DX + vga_col_next, 15));

   vga_core_on <= '1' when
            vga_col_i >= 0 and vga_col_i < G_GB_DX * G_GB_TO_VGA_SCALE and
            vga_row_i >= 0 and vga_row_i < G_GB_DY * G_GB_TO_VGA_SCALE
         else '0';

   p_delay : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga_core_on_o <= vga_core_on;
      end if;
   end process;
   
   -- convert the 15-bit Game Boy RGB data from the frame buffer to 24-bit RGB that can be displayed
   gbrgb2screenrgb : process (all)
      variable r5, g5, b5                : unsigned(4 downto 0);
      variable r8, g8, b8                : std_logic_vector(7 downto 0);
      variable r10, g10, b10             : unsigned(9 downto 0);
      variable r10_min, g10_min, b10_min : unsigned(9 downto 0);
      variable gray                      : unsigned(7 downto 0);
   begin
      -- Classic Game Boy
      -- grayscale values taken from MiSTer's lcd.v
      if (vga_color_i = '0') then
         case (vga_core_vram_data_i(1 downto 0)) is
            when "00"   => gray := to_unsigned(252, 8);
            when "01"   => gray := to_unsigned(168, 8);
            when "10"   => gray := to_unsigned(96, 8);
            when "11"   => gray := x"00";
            when others => gray := x"00";
         end case;
         vga_core_rgb_o <= std_logic_vector(gray) & std_logic_vector(gray) & std_logic_vector(gray);
         
      -- Game Boy Color
      else
         -- Game Boy's color output is only 5-bit
         r5 := unsigned(vga_core_vram_data_i(4 downto 0));
         g5 := unsigned(vga_core_vram_data_i(9 downto 5));
         b5 := unsigned(vga_core_vram_data_i(14 downto 10));

         -- color grading / lcd emulation, taken from:
         -- https://web.archive.org/web/20210223205311/https://byuu.net/video/color-emulation/
         --
         -- R = (r * 26 + g *  4 + b *  2);
         -- G = (         g * 24 + b *  8);
         -- B = (r *  6 + g *  4 + b * 22);
         -- R = min(960, R) >> 2;
         -- G = min(960, G) >> 2;
         -- B = min(960, B) >> 2;

         r10 := (r5 * 26) + (g5 *  4) + (b5 *  2);
         g10 :=             (g5 * 24) + (b5 *  8);
         b10 := (r5 *  6) + (g5 *  4) + (b5 * 22);

         r10_min := MINIMUM(960, r10); -- just for being on the safe side, we are using separate vars. for the MINIMUM
         g10_min := MINIMUM(960, g10);
         b10_min := MINIMUM(960, b10);

         -- fully saturated color mode (raw rgb): repeat bit pattern to convert 5-bit color to 8-bit color according to byuu.net
         if vga_color_mode_i = '0' then
            r8 := std_logic_vector(r5 & r5(4 downto 2));
            g8 := std_logic_vector(g5 & g5(4 downto 2));
            b8 := std_logic_vector(b5 & b5(4 downto 2));

         -- LCD Emulation mode according to byuu.net
         else
            r8 := std_logic_vector(r10_min(9 downto 2)); -- taking 9 downto 2 equals >> 2
            g8 := std_logic_vector(g10_min(9 downto 2));
            b8 := std_logic_vector(b10_min(9 downto 2));
         end if;

         vga_core_rgb_o <= r8 & g8 & b8;
      end if;         
   end process;

end synthesis;

