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

begin

   -- TODO: SINCE THIS IS FOR NOW JUST AN EXPERIMENT, ALL TIMING PARAMETERS ARE HARDCODED
   -- AND NOT TAKEN FROM video_modes_pkg . THIS NEEDS TO BE CHANGED.
   generator : entity work.video_out_timing
      port map (
         rst       => not reset_n,         -- reset
         clk       => pixel_clk,           -- pixel clock

         -- Input: Timing parameters for the video mode at hand
         -- TODO: SEE ABOVE / CHANGE HARDCODED TIMING
         pix_rep   => '0',                 -- pixel repetition; 0 = none/x1, 1 = x2
         interlace => '0',: in    std_logic;
         v_tot     => -- 1..2048 (must be odd if interlaced)
         v_act     => -- 1..2048 (should be even)
         v_sync    => -- 1..7
         v_bp      => -- 1`..31
         h_tot     => -- 1..4096
         h_act     => -- 1..2048 (must be even)
         h_sync    => -- 1..127
         h_bp      => -- 0..255
         align     => -- alignment delay
         
         -- Output: Sync and blanking signals, field ID, beam position
         f         => -- field ID
         vs        => -- vertical sync
         hs        => -- horizontal sync
         vblank    => -- vertical blank
         hblank    => -- horizontal blank
         ax        => -- visible area X (signed)
         ay        => -- visible area Y (signed)      
      );


end architecture synthesis;
