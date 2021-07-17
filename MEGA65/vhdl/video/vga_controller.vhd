----------------------------------------------------------------------------------
-- Game Boy Color for MEGA65 (gbc4mega65)
--
-- VGA timing generator
--
-- This is just a wrapper of Adam Barnes' module.
--
-- This machine is based on Gameboy_MiSTer
-- MEGA65 port done by sy2002 and MJoergen in 2021 and licensed under GPL v3
----------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity vga_controller is
   port (
      h_pulse   : in  integer;    -- horizontal sync pulse width in pixels
      h_bp      : in  integer;    -- horizontal back porch width in pixels
      h_pixels  : in  integer;    -- horizontal display width in pixels
      h_fp      : in  integer;    -- horizontal front porch width in pixels
      h_pol     : in  std_logic;  -- horizontal sync pulse polarity (1 = positive, 0 = negative)
      v_pulse   : in  integer;    -- vertical sync pulse width in rows
      v_bp      : in  integer;    -- vertical back porch width in rows
      v_pixels  : in  integer;    -- vertical display width in rows
      v_fp      : in  integer;    -- vertical front porch width in rows
      v_pol     : in  std_logic;  -- vertical sync pulse polarity (1 = positive, 0 = negative)
      pixel_clk : in  std_logic;  -- pixel clock at frequency of vga mode being used
      reset_n   : in  std_logic;  -- active low sycnchronous reset
      h_sync    : out std_logic;  -- horiztonal sync pulse
      v_sync    : out std_logic;  -- vertical sync pulse
      disp_ena  : out std_logic;  -- display enable ('1' = display time, '0' = blanking time)
      column    : out integer;    -- horizontal pixel coordinate
      row       : out integer;    -- vertical pixel coordinate
      n_blank   : out std_logic;  -- direct blacking output to dac
      n_sync    : out std_logic   -- sync-on-green output to dac
   );
end vga_controller;

architecture synthesis of vga_controller is

constant DEFAULT_COL : integer := 0;
constant DEFAULT_ROW : integer := 0;

signal ax            : std_logic_vector(11 downto 0);
signal ay            : std_logic_vector(11 downto 0);
signal vblank        : std_logic;
signal hblank        : std_logic;

begin

   -- TODO: SINCE THIS IS FOR NOW JUST AN EXPERIMENT, ALL TIMING PARAMETERS ARE HARDCODED
   -- AND NOT TAKEN FROM video_modes_pkg . THIS NEEDS TO BE CHANGED.
   generator : entity work.video_out_timing
      port map (
         rst       => not reset_n,         -- reset
         clk       => pixel_clk,           -- pixel clock

         -- Input: Timing parameters for the video mode at hand
         -- TODO: SEE ABOVE / CHANGE HARDCODED TIMING
         --            name        => "1280x720p60     ",
         --            dmt         => false,
         --            id          => 4,
         --            clk_sel     => CLK_SEL_74M25,
         --            pix_rep     => 0,
         --            aspect      => ASPECT_16_9,
         --            interlace   => FALSE,
         --            v_tot       => 750,
         --            v_act       => 720,
         --            v_sync      => 5,
         --            v_bp        => 20,
         --            h_tot       => 1650,
         --            h_act       => 1280,
         --            h_sync      => 40,
         --            h_bp        => 220,
         --            vs_pol      => '1',
         --            hs_pol      => '1'         
         pix_rep   => '0',                 -- pixel repetition; 0 = none/x1, 1 = x2
         interlace => '0',
         v_tot     => std_logic_vector(to_unsigned(750, 11)),
         v_act     => std_logic_vector(to_unsigned(720, 11)),
         v_sync    => std_logic_vector(to_unsigned(5, 3)),
         v_bp      => std_logic_vector(to_unsigned(20, 6)),
         h_tot     => std_logic_vector(to_unsigned(1650, 12)),
         h_act     => std_logic_vector(to_unsigned(1280, 11)),
         h_sync    => std_logic_vector(to_unsigned(40, 7)),
         h_bp      => std_logic_vector(to_unsigned(220, 8)),
         align     => (others => '0'),                  
         
         -- Output: Sync and blanking signals, field ID, beam position
         f         => open,      -- field ID
         vs        => v_sync,    -- vertical sync
         hs        => h_sync,    -- horizontal sync
         vblank    => vblank,    -- vertical blank
         hblank    => hblank,    -- horizontal blank
         ax        => ax,        -- visible area X (signed)
         ay        => ay         -- visible area Y (signed)      
      );
      
      
   disp_ena  <= not (vblank or hblank);
   column    <= to_integer(signed(ax)) when disp_ena = '1' else DEFAULT_COL;
   row       <= to_integer(signed(ay)) when disp_ena = '1' else DEFAULT_ROW;
   n_blank   <= not disp_ena;
   n_sync    <= not (h_sync or v_sync);      

end architecture synthesis;
