library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qnice_tools.all;

entity vga_osm is
   generic  (
      G_VGA_DX          : integer;
      G_VGA_DY          : integer;
      G_GB_DX           : integer;
      G_GB_DY           : integer;
      G_GB_TO_VGA_SCALE : integer
   );
   port (
      clk_i                    : in  std_logic;
      rst_i                    : in  std_logic;

      vga_col_i                : integer range 0 to G_VGA_DX - 1;
      vga_row_i                : integer range 0 to G_VGA_DY - 1;

      vga_gbc_osm_i            : in  std_logic;
      vga_osm_xy_i             : in  std_logic_vector(15 downto 0);
      vga_osm_dxdy_i           : in  std_logic_vector(15 downto 0);
      vga_osm_vram_addr_o      : out std_logic_vector(15 downto 0);
      vga_osm_vram_data_i      : in  std_logic_vector(7 downto 0);
      vga_osm_vram_attr_data_i : in  std_logic_vector(7 downto 0);

      vga_osm_on_o             : out std_logic;
      vga_osm_rgb_o            : out std_logic_vector(23 downto 0)
   );
end vga_osm;

architecture synthesis of vga_osm is

   -- Constants for VGA output
   constant FONT_DX         : integer := 16;
   constant FONT_DY         : integer := 16;
   constant CHARS_DX        : integer := G_VGA_DX / FONT_DX;
   constant CHARS_DY        : integer := G_VGA_DY / FONT_DY;
   constant CHAR_MEM_SIZE   : integer := CHARS_DX * CHARS_DY;
   constant VRAM_ADDR_WIDTH : integer := f_log2(CHAR_MEM_SIZE);

   -- VGA signals
   signal vga_disp_en  : std_logic;
   signal vga_col_raw  : integer range 0 to G_VGA_DX - 1;
   signal vga_row_raw  : integer range 0 to G_VGA_DY - 1;
   signal vga_col_next : integer range 0 to G_VGA_DX - 1;
   signal vga_row_next : integer range 0 to G_VGA_DY - 1;
   signal vga_hs       : std_logic;
   signal vga_vs       : std_logic;

   signal vga_x        : integer range 0 to G_VGA_DX - 1;
   signal vga_y        : integer range 0 to G_VGA_DY - 1;
   signal vga_x_old    : integer range 0 to G_VGA_DX - 1;
   signal vga_y_old    : integer range 0 to G_VGA_DY - 1;

   signal vga_osm_x1, vga_osm_x2 : integer range 0 to CHARS_DX - 1;
   signal vga_osm_y1, vga_osm_y2 : integer range 0 to CHARS_DY - 1;

   signal vga_osm_font_addr      : std_logic_vector(11 downto 0);
   signal vga_osm_font_data      : std_logic_vector(15 downto 0);

begin

   vga_x <= vga_col_i;
   vga_y <= vga_row_i;

   -- it takes one pixelclock cycle until the vram returns the data
   latch_vga_xy : process(clk_i)
   begin
      if rising_edge(clk_i) then
         vga_x_old <= vga_x;
         vga_y_old <= vga_y;
      end if;
   end process;

   calc_boundaries : process (all)
      variable vga_osm_x : integer range 0 to CHARS_DX - 1;
      variable vga_osm_y : integer range 0 to CHARS_DY - 1;
   begin
      vga_osm_x  := to_integer(unsigned(vga_osm_xy_i(15 downto 8)));
      vga_osm_y  := to_integer(unsigned(vga_osm_xy_i(7 downto 0)));
      vga_osm_x1 <= vga_osm_x;
      vga_osm_y1 <= vga_osm_y;
      vga_osm_x2 <= vga_osm_x + to_integer(unsigned(vga_osm_dxdy_i(15 downto 8)));
      vga_osm_y2 <= vga_osm_y + to_integer(unsigned(vga_osm_dxdy_i(7 downto 0)));
   end process;

   -- render OSM: calculate the pixel that needs to be shown at the given position
   -- TODO: either here or in the top file: we are +1 pixel too much to the right (what about the vertical axis?)
   render_osm : process (all)
      variable vga_x_div_16 : integer range 0 to CHARS_DX - 1;
      variable vga_y_div_16 : integer range 0 to CHARS_DY - 1;
      variable vga_x_mod_16 : integer range 0 to 15;
      variable vga_y_mod_16 : integer range 0 to 15;

      function attr2rgb(attr: in std_logic_vector(3 downto 0)) return std_logic_vector is
      variable r, g, b: std_logic_vector(7 downto 0);
      variable brightness : std_logic_vector(7 downto 0);
      begin
         -- see comment above at vram_attr to understand the Attribute VRAM bit patterns
         brightness := x"FF" when attr(3) = '0' else x"7F";
         r := brightness when attr(2) = '1' else x"00";
         g := brightness when attr(1) = '1' else x"00";
         b := brightness when attr(0) = '1' else x"00";
         return r & g & b;
      end attr2rgb;

   begin
      vga_x_div_16 := to_integer(to_unsigned(vga_x, 16)(9 downto 4));
      vga_y_div_16 := to_integer(to_unsigned(vga_y, 16)(9 downto 4));
      vga_x_mod_16 := to_integer(to_unsigned(vga_x_old, 16)(3 downto 0));
      vga_y_mod_16 := to_integer(to_unsigned(vga_y_old, 16)(3 downto 0));
      vga_osm_vram_addr_o <= std_logic_vector(to_unsigned(vga_y_div_16 * CHARS_DX + vga_x_div_16, 16));
      vga_osm_font_addr <= std_logic_vector(to_unsigned(to_integer(unsigned(vga_osm_vram_data_i)) * FONT_DY + vga_y_mod_16, 12));
      -- if pixel is set in font (and take care of inverse on/off)
      if vga_osm_font_data(15 - vga_x_mod_16) = not vga_osm_vram_attr_data_i(7) then
         -- foreground color
         vga_osm_rgb_o <= attr2rgb(vga_osm_vram_attr_data_i(6) & vga_osm_vram_attr_data_i(2 downto 0));
      else
         -- background color
         vga_osm_rgb_o <= attr2rgb(vga_osm_vram_attr_data_i(6 downto 3));
      end if;

      if vga_x_div_16 >= vga_osm_x1 and vga_x_div_16 < vga_osm_x2 and vga_y_div_16 >= vga_osm_y1 and vga_y_div_16 < vga_osm_y2 then
         vga_osm_on_o <= vga_gbc_osm_i;
      else
         vga_osm_on_o <= '0';
      end if;
   end process;


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
      src_x    := std_logic_vector(to_unsigned(vga_col_i, 10));
      src_y    := std_logic_vector(to_unsigned(vga_row_i, 10));
      dst_x    := src_x(9 downto 2);
      dst_y    := src_y(9 downto 2);
      dst_x_i  := to_integer(unsigned(dst_x));
      dst_y_i  := to_integer(unsigned(dst_y));
      nextrow  := dst_y_i + 1;

      -- The dual port & dual clock RAM needs one clock cycle to provide the data. Therefore we need
      -- to always address one pixel ahead of were we currently stand
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


   -- 16x16 pixel font ROM
   font : entity work.BROM
      generic map
      (
         FILE_NAME    => "../font/Anikki-16x16.rom",
         ADDR_WIDTH   => 12,
         DATA_WIDTH   => 16,
         LATCH_ACTIVE => false
      )
      port map
      (
         clk          => clk_i,
         ce           => '1',
         address      => vga_osm_font_addr,
         data         => vga_osm_font_data
      ); -- font : entity work.BROM

end synthesis;

