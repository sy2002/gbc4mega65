----------------------------------------------------------------------------------
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity lcd_to_pixels is
   generic (
      GB_DX              : natural;     -- Game Boy's X pixel resolution
      GB_DY              : natural      -- ditto Y
   );
   port (
      clk_i              : in  std_logic;
      sc_ce_i            : in  std_logic;
      
      -- Game Boy LCD output
      lcd_clkena_i       : in  std_logic;
      lcd_data_i         : in  std_logic_vector(14 downto 0);
      lcd_mode_i         : in  std_logic_vector(1 downto 0);
      lcd_on_i           : in  std_logic;
      lcd_vsync_i        : in  std_logic;
      
      -- LCD converted to 15-bit pixel data (that still needs to be decoded for being displayed on screen)
      pixel_out_we_o     : out std_logic;
      pixel_out_ptr_o    : out integer range 0 to 65535 := 0;
      pixel_out_data_o   : out std_logic_vector(14 downto 0)
      
      -- double buffering information for being used by the display decoder:
      -- 0=use frame buffer addresses 0..32767, 1=use 32768..65.535
      --double_buffer_o    : out std_logic
   );
end lcd_to_pixels;

architecture synthesis of lcd_to_pixels is

   signal lcd_r_blank_de      : std_logic := '0';
   signal lcd_r_blank_output  : std_logic := '0';
   signal lcd_r_off           : std_logic := '0';
   signal lcd_r_old_off       : std_logic := '0';
   signal lcd_r_old_on        : std_logic := '0';
   signal lcd_r_old_vs        : std_logic := '0';
   signal lcd_r_blank_hcnt    : integer range 0 to GB_DX - 1 := 0;
   signal lcd_r_blank_vcnt    : integer range 0 to GB_DY - 1 := 0;
   signal lcd_r_blank_data    : std_logic_vector(14 downto 0) := (others => '0');

begin

   lcd_to_pixels : process (clk_i)
      variable pixel_we                  : std_logic;
   begin
      if rising_edge(clk_i) then
         pixel_we := sc_ce_i and (lcd_clkena_i or lcd_r_blank_de);
         pixel_out_we_o <= pixel_we;

         if lcd_on_i = '0' or lcd_mode_i = "01" then
            lcd_r_off <= '1';
         else
            lcd_r_off <= '0';
         end if;

         if lcd_on_i = '0' and lcd_r_blank_output = '1' and lcd_r_blank_hcnt < GB_DX and lcd_r_blank_vcnt < GB_DY then
            lcd_r_blank_de <= '1';
         else
            lcd_r_blank_de <= '0';
         end if;

         if pixel_we = '1' then
            pixel_out_ptr_o <= pixel_out_ptr_o + 1;
         end if;

         lcd_r_old_off <= lcd_r_off;
         if (lcd_r_old_off xor lcd_r_off) = '1' then
            pixel_out_ptr_o <= 0;
         end if;

         lcd_r_old_on <= lcd_on_i;
         if lcd_r_old_on = '1' and lcd_on_i = '0' and lcd_r_blank_output = '0' then
            lcd_r_blank_output <= '1';
            lcd_r_blank_hcnt <= 0;
            lcd_r_blank_vcnt <= 0;
         end if;

         -- regenerate LCD timings for filling with blank color when LCD is off
         if sc_ce_i = '1' and lcd_on_i = '0' and lcd_r_blank_output = '1' then
            lcd_r_blank_data <= lcd_data_i;
            lcd_r_blank_hcnt <= lcd_r_blank_hcnt + 1;
            if lcd_r_blank_hcnt = 455 then
               lcd_r_blank_hcnt <= 0;
               lcd_r_blank_vcnt <= lcd_r_blank_vcnt + 1;
               if lcd_r_blank_vcnt = 153 then
                  lcd_r_blank_vcnt <= 0;
                  pixel_out_ptr_o <= 0;
               end if;
            end if;
         end if;

         -- output 1 blank frame until VSync after LCD is enabled
         lcd_r_old_vs <= lcd_vsync_i;
         if lcd_r_old_vs = '0' and lcd_vsync_i = '1' and lcd_r_blank_output = '1' then
            lcd_r_blank_output <= '0';
         end if;

         if lcd_on_i = '1' and lcd_r_blank_output = '1' then
            pixel_out_data_o <= lcd_r_blank_data;        
         else
            pixel_out_data_o <= lcd_data_i;
         end if;
      end if;
   end process;
   
end architecture synthesis;

