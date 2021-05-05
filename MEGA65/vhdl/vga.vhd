library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

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

      vga_address_o  : out std_logic_vector(14 downto 0);
      vga_row_o      : out integer range 0 to G_VGA_DY - 1;
      vga_col_o      : out integer range 0 to G_VGA_DX - 1;
      vga_data_i     : in  std_logic_vector(23 downto 0);

      vga_osm_on_i   : in  std_logic;
      vga_osm_rgb_i  : in  std_logic_vector(23 downto 0);

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

   -- VGA signals
   signal vga_disp_en         : std_logic;
   signal vga_col_raw         : integer range 0 to G_VGA_DX - 1;
   signal vga_row_raw         : integer range 0 to G_VGA_DY - 1;
   signal vga_col             : integer range 0 to G_VGA_DX - 1;
   signal vga_row             : integer range 0 to G_VGA_DY - 1;
   signal vga_col_next        : integer range 0 to G_VGA_DX - 1;
   signal vga_row_next        : integer range 0 to G_VGA_DY - 1;
   signal vga_hs              : std_logic;
   signal vga_vs              : std_logic;

begin

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
            if vga_osm_on_i then
               vga_red_o   <= vga_osm_rgb_i(23 downto 16);
               vga_green_o <= vga_osm_rgb_i(15 downto 8);
               vga_blue_o  <= vga_osm_rgb_i(7 downto 0);
            end if;
         end if;

         -- VGA horizontal and vertical sync
         vga_hs_o <= vga_hs;
         vga_vs_o <= vga_vs;
      end if;
   end process; -- p_video_signal_latches : process(vga_pixelclk)

   -- make the VDAC output the image
   -- for some reason, the VDAC does not like non-zero values outside the visible window
   -- maybe "vdac_sync_n <= '0';" activates sync-on-green?
   -- TODO: check that
   vdac_sync_n_o  <= '0';
   vdac_blank_n_o <= '1';
   vdac_clk_o     <= not clk_i; -- inverting the clock leads to a sharper signal for some reason

   vga_row_o <= vga_row;
   vga_col_o <= vga_col;

end synthesis;

