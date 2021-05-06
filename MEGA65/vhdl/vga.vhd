library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;
use work.qnice_tools.all;

entity vga is
   generic  (
      G_VGA_DX          : integer;
      G_VGA_DY          : integer;
      G_GB_DX           : integer;
      G_GB_DY           : integer;
      G_GB_TO_VGA_SCALE : integer
   );
   port (
      clk_i          : in  std_logic;
      rst_i          : in  std_logic;

      vga_gbc_osm_i            : in  std_logic;
      vga_osm_vram_addr_o      : out std_logic_vector(15 downto 0);
      vga_osm_vram_data_i      : in  std_logic_vector(7 downto 0);
      vga_osm_vram_attr_data_i : in  std_logic_vector(7 downto 0);

      vga_address_o  : out std_logic_vector(14 downto 0);
      vga_data_i     : in  std_logic_vector(23 downto 0);

      -- VGA
      vga_red_o      : out std_logic_vector(7 downto 0);
      vga_green_o    : out std_logic_vector(7 downto 0);
      vga_blue_o     : out std_logic_vector(7 downto 0);
      vga_hs_o       : out std_logic;
      vga_vs_o       : out std_logic;

      -- VDAC
      vdac_clk_o     : out std_logic;
      vdac_sync_n_o  : out std_logic;
      vdac_blank_n_o : out std_logic
   );
end vga;

architecture synthesis of vga is

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
   signal vga_col      : integer range 0 to G_VGA_DX - 1;
   signal vga_row      : integer range 0 to G_VGA_DY - 1;
   signal vga_col_next : integer range 0 to G_VGA_DX - 1;
   signal vga_row_next : integer range 0 to G_VGA_DY - 1;
   signal vga_hs       : std_logic;
   signal vga_vs       : std_logic;

   signal vga_x        : integer range 0 to G_VGA_DX - 1;
   signal vga_y        : integer range 0 to G_VGA_DY - 1;
   signal vga_x_old    : integer range 0 to G_VGA_DX - 1;
   signal vga_y_old    : integer range 0 to G_VGA_DY - 1;
   signal vga_osm_on   : std_logic;
   signal vga_osm_rgb  : std_logic_vector(23 downto 0);   -- 23..0 = RGB, 8 bits each

   signal vga_osm_xy             : std_logic_vector(15 downto 0);
   signal vga_osm_dxdy           : std_logic_vector(15 downto 0);
   signal vga_osm_x1, vga_osm_x2 : integer range 0 to CHARS_DX - 1;
   signal vga_osm_y1, vga_osm_y2 : integer range 0 to CHARS_DY - 1;

   signal vga_osm_font_addr      : std_logic_vector(11 downto 0);
   signal vga_osm_font_data      : std_logic_vector(15 downto 0);

begin

   vga_x <= vga_col;
   vga_y <= vga_row;

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
      vga_osm_x  := to_integer(unsigned(vga_osm_xy(15 downto 8)));
      vga_osm_y  := to_integer(unsigned(vga_osm_xy(7 downto 0)));
      vga_osm_x1 <= vga_osm_x;
      vga_osm_y1 <= vga_osm_y;
      vga_osm_x2 <= vga_osm_x + to_integer(unsigned(vga_osm_dxdy(15 downto 8)));
      vga_osm_y2 <= vga_osm_y + to_integer(unsigned(vga_osm_dxdy(7 downto 0)));
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
         vga_osm_rgb <= attr2rgb(vga_osm_vram_attr_data_i(6) & vga_osm_vram_attr_data_i(2 downto 0));
      else
         -- background color
         vga_osm_rgb <= attr2rgb(vga_osm_vram_attr_data_i(6 downto 3));
      end if;

      if vga_x_div_16 >= vga_osm_x1 and vga_x_div_16 < vga_osm_x2 and vga_y_div_16 >= vga_osm_y1 and vga_y_div_16 < vga_osm_y2 then
         vga_osm_on <= vga_gbc_osm_i;
      else
         vga_osm_on <= '0';
      end if;
   end process;


   -- SVGA mode 800 x 600 @ 60 Hz
   -- Component that produces VGA timings and outputs the currently active pixel coordinate (row, column)
   -- Timings taken from http://tinyvga.com/vga-timing/800x600@60Hz
   vga_pixels_and_timing : entity work.vga_controller
      generic map
      (
         H_PIXELS  => G_VGA_DX,           -- horizontal display width in pixels
         V_PIXELS  => G_VGA_DY,           -- vertical display width in rows

         H_PULSE   => 128,              -- horiztonal sync pulse width in pixels
         H_BP      => 88,               -- horiztonal back porch width in pixels
         H_FP      => 40,               -- horiztonal front porch width in pixels
         H_POL     => '1',              -- horizontal sync pulse polarity (1 = positive, 0 = negative)

         V_PULSE   => 4,                -- vertical sync pulse width in rows
         V_BP      => 23,               -- vertical back porch width in rows
         V_FP      => 1,                -- vertical front porch width in rows
         V_POL     => '1'               -- vertical sync pulse polarity (1 = positive, 0 = negative)
      )
      port map
      (
         pixel_clk => clk_i,            -- pixel clock at frequency of VGA mode being used
         reset_n   => rst_i,            -- active low asycnchronous reset
         h_sync    => vga_hs,           -- horiztonal sync pulse
         v_sync    => vga_vs,           -- vertical sync pulse
         disp_ena  => vga_disp_en,      -- display enable ('1' = display time, '0' = blanking time)
         column    => vga_col_raw,      -- horizontal pixel coordinate
         row       => vga_row_raw,      -- vertical pixel coordinate
         n_blank   => open,             -- direct blacking output to DAC
         n_sync    => open              -- sync-on-green output to DAC
      ); -- vga_pixels_and_timing : entity work.vga_controller


   -- due to the latching of the VGA signals, we are one pixel off: compensate for that
   p_adjust_pixel_skew : process (all)
      variable nextrow  : integer range 0 to G_VGA_DY - 1;
   begin
      nextrow := vga_row_raw + 1;
      if vga_col_raw < G_VGA_DX - 1 then
         vga_col <= vga_col_raw + 1;
         vga_row <= vga_row_raw;
      else
         vga_col <= 0;
         if nextrow < G_VGA_DY then
            vga_row <= nextrow;
         else
            vga_row <= 0;
         end if;
      end if;
   end process p_adjust_pixel_skew;


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
      src_x    := std_logic_vector(to_unsigned(vga_col, 10));
      src_y    := std_logic_vector(to_unsigned(vga_row, 10));
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


   vga_address_o <= std_logic_vector(to_unsigned(vga_row_next * G_GB_DX + vga_col_next, 15));

   p_video_signal_latches : process (clk_i)
   begin
      if rising_edge(clk_i) then
         vga_red_o   <= (others => '0');
         vga_blue_o  <= (others => '0');
         vga_green_o <= (others => '0');

         if vga_disp_en then
            -- Game Boy output
            -- TODO: Investigate, why the top/left pixel is always white and solve it;
            -- workaround in the meantime: the top/left pixel is set to be always black which seems to be less intrusive
            if (vga_col_raw > 0 or vga_row_raw > 0) and
               (vga_col_raw < G_GB_DX * G_GB_TO_VGA_SCALE and
                vga_row_raw < G_GB_DY * G_GB_TO_VGA_SCALE) then
               vga_red_o   <= vga_data_i(23 downto 16);
               vga_green_o <= vga_data_i(15 downto 8);
               vga_blue_o  <= vga_data_i(7 downto 0);
            end if;

            -- On-Screen-Menu (OSM) output
            if vga_osm_on then
               vga_red_o   <= vga_osm_rgb(23 downto 16);
               vga_green_o <= vga_osm_rgb(15 downto 8);
               vga_blue_o  <= vga_osm_rgb(7 downto 0);
            end if;
         end if;

         -- VGA horizontal and vertical sync
         vga_hs_o <= vga_hs;
         vga_vs_o <= vga_vs;
      end if;
   end process; -- p_video_signal_latches : process(vga_pixelclk)

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


   -- make the VDAC output the image
   -- for some reason, the VDAC does not like non-zero values outside the visible window
   -- maybe "vdac_sync_n <= '0';" activates sync-on-green?
   -- TODO: check that
   vdac_sync_n_o  <= '0';
   vdac_blank_n_o <= '1';
   vdac_clk_o     <= not clk_i; -- inverting the clock leads to a sharper signal for some reason

end synthesis;

