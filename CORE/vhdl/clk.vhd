-------------------------------------------------------------------------------------------------------------
-- Game Boy and Game Boy Color for MEGA65 (gbc4mega65)
--
-- Clock Generator using the Xilinx specific MMCME2_ADV:
--
--   The MiSTer Game Boy machine expects 8x the clock speed of the original Game Boy:
--      8 x 4.194304 MHz = 33.554432 MHz  ("main_clk", gb.v/speedcontrol/mbc)
--   The MiSTer LCD-to-video module lcd.v expects 16x the Game Boy clock:
--      16 x 4.194304 MHz = 67.108864 MHz ("video_clk", exactly 2x main_clk)
--
--   Native leg (i_clk_main):
--      f_VCO  = 100 MHz x CLKFBOUT_MULT_F / DIVCLK_DIVIDE = 100 x 56.375 / 6 = 939.583 MHz
--      video  = f_VCO / CLKOUT0_DIVIDE_F = 939.583 / 14   = 67.113095 MHz (ideal 67.108864, +63 ppm)
--      main   = f_VCO / CLKOUT1_DIVIDE   = 939.583 / 28   = 33.556548 MHz (ideal 33.554432, +63 ppm)
--      Game Boy frame rate: main / 8 / (456 x 154) = 59.7313 Hz (ideal 59.7275 Hz)
--
--   HDMI flicker-free "fast" twin (i_clk_fast), see below:
--      f_VCO  = 100 x 52.625 / 6 = 877.083 MHz
--      video  = 877.083 / 13     = 67.468 MHz
--      main   = 877.083 / 26     = 33.734 MHz  =>  frame rate 60.0473 Hz (just above 60)
--
-- MMCME2_ADV legality checks (Artix-7 XC7A200T, see Xilinx DS181 / UG472):
--    * VCO 939.583 MHz and 877.083 MHz are within the MMCM VCO range of 600..1200 MHz
--      (conservative -1 speed grade limit; -2 allows up to 1440 MHz)
--    * PFD = 100 MHz / DIVCLK_DIVIDE(6) = 16.667 MHz, within the allowed 10..450 MHz
--    * CLKFBOUT_MULT_F 56.375 and 52.625 are legal multiples of 0.125 within 2.000..64.000
--    * CLKOUT0_DIVIDE_F 14.000/13.000 are integer-valued; CLKOUT1_DIVIDE 28/26 are integers
--
-- HDMI flicker-free (same mechanism as C64MEGA65 and AExp): the HDMI output modes run at
-- fixed standard rates (e.g. exactly 60.000 Hz at 720p), while the native Game Boy runs at
-- 59.7275 Hz. ascal's frame buffer write and read pointers therefore chase each other in
-- HyperRAM and periodically collide (visible as a slowly wandering tear line). The framework
-- measures the pointer gap and pulses hr_high_o/hr_low_o; a small FSM in mega65.vhd uses this
-- feedback to dither between the "native" and "fast" clock legs via a glitch-free
-- BUFGMUX_CTRL, time-averaging the core to exactly the HDMI frame rate. Both main_clk and
-- video_clk switch together (two BUFGMUX_CTRL sharing one select), so the fixed 1:2 ratio
-- that lcd.v relies on is preserved on both legs.
--
-- This machine is based on Gameboy_MiSTer
-- Powered by MiSTer2MEGA65
-- MEGA65 port done by sy2002 in 2021 - 2026 and licensed under GPL v3
-------------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

library xpm;
use xpm.vcomponents.all;

entity clk is
   port (
      sys_clk_i       : in  std_logic;   -- expects 100 MHz

      -- HDMI flicker-free core clock select (asynchronous, glitch-free absorbed by BUFGMUX_CTRL):
      --   "00" = native 33.556548 MHz main / 67.113095 MHz video (59.7313 Hz, below 60;
      --          also the flicker-free-OFF/authentic case)
      --   "01" = fast   33.733974 MHz main / 67.467949 MHz video (60.0473 Hz, above 60)
      -- Bit 1 is reserved for a potential third leg; unused here.
      core_speed_i    : in  unsigned(1 downto 0);

      main_clk_o      : out std_logic;   -- Game Boy core clock: 8 x 4.194304 MHz = 33.554432 MHz nominal
      main_rst_o      : out std_logic;   -- main's reset, synchronized

      video_clk_o     : out std_logic;   -- lcd.v video clock: 16 x 4.194304 MHz = 67.108864 MHz nominal
      video_rst_o     : out std_logic    -- video's reset, synchronized
   );
end entity clk;

architecture rtl of clk is

-- native leg (33.556548 / 67.113095 MHz)
signal main_fb            : std_logic;
signal main_fb_mmcm       : std_logic;
signal native_video_mmcm  : std_logic;
signal native_main_mmcm   : std_logic;
signal main_locked        : std_logic;

-- fast leg (33.733974 / 67.467949 MHz), HDMI flicker-free twin
signal fast_fb            : std_logic;
signal fast_fb_mmcm       : std_logic;
signal fast_video_mmcm    : std_logic;
signal fast_main_mmcm     : std_logic;
signal fast_locked        : std_logic;

-- glitch-free mux outputs feeding the shared output BUFGs
signal main_clk_mmcm      : std_logic;
signal video_clk_mmcm     : std_logic;

begin

   -------------------------------------------------------------------------------------
   -- Native leg: 100 MHz x 56.375 / 6 = 939.583 MHz VCO
   --    CLKOUT0 / 14 = 67.113095 MHz video clock
   --    CLKOUT1 / 28 = 33.556548 MHz main clock
   -------------------------------------------------------------------------------------

   i_clk_main : MMCME2_ADV
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKOUT4_CASCADE      => FALSE,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => FALSE,
         CLKIN1_PERIOD        => 10.0,       -- INPUT @ 100 MHz
         REF_JITTER1          => 0.010,
         DIVCLK_DIVIDE        => 6,
         CLKFBOUT_MULT_F      => 56.375,     -- VCO = 939.583 MHz
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => FALSE,
         CLKOUT0_DIVIDE_F     => 14.000,     -- video: 67.113095 MHz (ideal 67.108864 MHz, +63 ppm)
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => FALSE,
         CLKOUT1_DIVIDE       => 28,         -- main: 33.556548 MHz (ideal 33.554432 MHz, +63 ppm)
         CLKOUT1_PHASE        => 0.000,
         CLKOUT1_DUTY_CYCLE   => 0.500,
         CLKOUT1_USE_FINE_PS  => FALSE
      )
      port map (
         -- Output clocks
         CLKFBOUT            => main_fb_mmcm,
         CLKOUT0             => native_video_mmcm,
         CLKOUT1             => native_main_mmcm,
         -- Input clock control
         CLKFBIN             => main_fb,
         CLKIN1              => sys_clk_i,
         CLKIN2              => '0',
         -- Tied to always select the primary input clock
         CLKINSEL            => '1',
         -- Ports for dynamic reconfiguration
         DADDR               => (others => '0'),
         DCLK                => '0',
         DEN                 => '0',
         DI                  => (others => '0'),
         DO                  => open,
         DRDY                => open,
         DWE                 => '0',
         -- Ports for dynamic phase shift
         PSCLK               => '0',
         PSEN                => '0',
         PSINCDEC            => '0',
         PSDONE              => open,
         -- Other control and status signals
         LOCKED              => main_locked,
         CLKINSTOPPED        => open,
         CLKFBSTOPPED        => open,
         PWRDWN              => '0',
         RST                 => '0'
      ); -- i_clk_main

   -------------------------------------------------------------------------------------
   -- HDMI flicker-free "fast" twin: 100 MHz x 52.625 / 6 = 877.083 MHz VCO
   --    CLKOUT0 / 13 = 67.467949 MHz video clock
   --    CLKOUT1 / 26 = 33.733974 MHz main clock  =>  60.0473 Hz frame rate
   -- Shares the native leg's DIVCLK_DIVIDE (6) for the same PFD frequency and a
   -- comparable jitter/clock-tree profile.
   -------------------------------------------------------------------------------------

   i_clk_fast : MMCME2_ADV
      generic map (
         BANDWIDTH            => "OPTIMIZED",
         CLKOUT4_CASCADE      => FALSE,
         COMPENSATION         => "ZHOLD",
         STARTUP_WAIT         => FALSE,
         CLKIN1_PERIOD        => 10.0,       -- INPUT @ 100 MHz
         REF_JITTER1          => 0.010,
         DIVCLK_DIVIDE        => 6,
         CLKFBOUT_MULT_F      => 52.625,     -- VCO = 877.083 MHz
         CLKFBOUT_PHASE       => 0.000,
         CLKFBOUT_USE_FINE_PS => FALSE,
         CLKOUT0_DIVIDE_F     => 13.000,     -- video: 67.467949 MHz
         CLKOUT0_PHASE        => 0.000,
         CLKOUT0_DUTY_CYCLE   => 0.500,
         CLKOUT0_USE_FINE_PS  => FALSE,
         CLKOUT1_DIVIDE       => 26,         -- main: 33.733974 MHz (frame rate 60.0473 Hz)
         CLKOUT1_PHASE        => 0.000,
         CLKOUT1_DUTY_CYCLE   => 0.500,
         CLKOUT1_USE_FINE_PS  => FALSE
      )
      port map (
         -- Output clocks
         CLKFBOUT            => fast_fb_mmcm,
         CLKOUT0             => fast_video_mmcm,
         CLKOUT1             => fast_main_mmcm,
         -- Input clock control
         CLKFBIN             => fast_fb,
         CLKIN1              => sys_clk_i,
         CLKIN2              => '0',
         -- Tied to always select the primary input clock
         CLKINSEL            => '1',
         -- Ports for dynamic reconfiguration
         DADDR               => (others => '0'),
         DCLK                => '0',
         DEN                 => '0',
         DI                  => (others => '0'),
         DO                  => open,
         DRDY                => open,
         DWE                 => '0',
         -- Ports for dynamic phase shift
         PSCLK               => '0',
         PSEN                => '0',
         PSINCDEC            => '0',
         PSDONE              => open,
         -- Other control and status signals
         LOCKED              => fast_locked,
         CLKINSTOPPED        => open,
         CLKFBSTOPPED        => open,
         PWRDWN              => '0',
         RST                 => '0'
      ); -- i_clk_fast

   -------------------------------------------------------------------------------------
   -- Output buffering
   -------------------------------------------------------------------------------------

   -- native leg feedback (ZHOLD compensates one BUFG delay)
   main_fb_bufg : BUFG
      port map (
         I => main_fb_mmcm,
         O => main_fb
      );

   -- fast leg feedback (its own BUFG, symmetric with native)
   fast_fb_bufg : BUFG
      port map (
         I => fast_fb_mmcm,
         O => fast_fb
      );

   -- Glitch-free switch between native ("00") and fast ("01"); the select is treated
   -- asynchronously to both clock inputs and absorbed cleanly by the BUFGMUX_CTRL.
   -- Both muxes share the same select, so main_clk and video_clk always come from the
   -- same leg and keep their exact 1:2 frequency ratio.
   i_bufgmux_main : BUFGMUX_CTRL
      port map (
         I0 => native_main_mmcm,    -- s = 0 -> native (33.556548 MHz)
         I1 => fast_main_mmcm,      -- s = 1 -> fast   (33.733974 MHz)
         S  => core_speed_i(0),
         O  => main_clk_mmcm
      );

   i_bufgmux_video : BUFGMUX_CTRL
      port map (
         I0 => native_video_mmcm,   -- s = 0 -> native (67.113095 MHz)
         I1 => fast_video_mmcm,     -- s = 1 -> fast   (67.467949 MHz)
         S  => core_speed_i(0),
         O  => video_clk_mmcm
      );

   main_clk_bufg : BUFG
      port map (
         I => main_clk_mmcm,
         O => main_clk_o
      );

   video_clk_bufg : BUFG
      port map (
         I => video_clk_mmcm,
         O => video_clk_o
      );

   -------------------------------------
   -- Reset generation
   -------------------------------------

   i_xpm_cdc_async_rst_main : xpm_cdc_async_rst
      generic map (
         RST_ACTIVE_HIGH => 1,
         DEST_SYNC_FF    => 6
      )
      port map (
         -- Hold the core in reset until BOTH legs are locked, so the "fast" MMCM is already
         -- toggling before the select can ever choose it (load-bearing: BUFGMUX_CTRL would
         -- otherwise forward a dead clock on the first native->fast switch).
         src_arst  => not (main_locked and fast_locked),
         dest_clk  => main_clk_o,
         dest_arst => main_rst_o
      );

   i_xpm_cdc_async_rst_video : xpm_cdc_async_rst
      generic map (
         RST_ACTIVE_HIGH => 1,
         DEST_SYNC_FF    => 6
      )
      port map (
         src_arst  => not (main_locked and fast_locked),
         dest_clk  => video_clk_o,
         dest_arst => video_rst_o
      );

end architecture rtl;
