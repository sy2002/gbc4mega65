-- Comment by sy2002 on June 19, 2021:
--
-- This has been a test tone generator in Adam's original code.-
-- Paul modified both in the MEGA65 project to be something like a
-- clock domain crossing mechanism plus an oversampler?
-- No idea. For now, I take it as it is.
-- @TODO: Think it through. Understand it. Optimize it.
--
-- Moreover, it contains a supposedly more precise 48 kHz clock from Adam
-- which Paul also modified/improved to be even more precise.
--
-- The aim of all these modifications/improvements/hacks is that the HDMI
-- audio stream works on as many HDMI decvices as possible.
--
--
-- What I changed:
-- * Renamed from audio_out_test_one to audio_out_tone.
-- * Removed unused generic fref
-- * Changed inout ports into clear in or out ports


--------------------------------------------------------------------------------
-- audio_out_test_tone.vhd                                                    --
-- Simple test tone generator (fs = 48kHz).                                   --
--------------------------------------------------------------------------------
-- (C) Copyright 2020 Adam Barnes <ambarnes@gmail.com>                        --
-- This file is part of The Tyto Project. The Tyto Project is free software:  --
-- you can redistribute it and/or modify it under the terms of the GNU Lesser --
-- General Public License as published by the Free Software Foundation,       --
-- either version 3 of the License, or (at your option) any later version.    --
-- The Tyto Project is distributed in the hope that it will be useful, but    --
-- WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY --
-- or FITNESS FOR A PARTICULAR PURPOSE. See the GNU Lesser General Public     --
-- License for more details. You should have received a copy of the GNU       --
-- Lesser General Public License along with The Tyto Project. If not, see     --
-- https://www.gnu.org/licenses/.                                             --
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;

entity audio_out_tone is
    port (
        -- Allow switching between these to audio sample rates
        select_44100 : in std_logic; 
      
        ref_rst     : in    std_logic;                      -- reference clock reset
        ref_clk     : in    std_logic;                      -- reference clock (100MHz)

        pcm_rst     : out   std_logic;                      -- audio clock reset
        pcm_clk     : out   std_logic;                      -- audio clock (256Fs = 12.288MHz)
        pcm_clken   : out   std_logic;                      -- audio clock enable (Fs = 48kHz)

        audio_left_slow     : in std_logic_vector(15 downto 0);
        audio_right_slow    : in std_logic_vector(15 downto 0);
        sample_ready_toggle : in std_logic;
        
        pcm_l       : out   std_logic_vector(15 downto 0);  -- } synchronous to pcm_clk
        pcm_r       : out   std_logic_vector(15 downto 0)   -- } valid on pcm_clken
    );
end entity audio_out_tone;

architecture synth of audio_out_tone is

  signal last_sample_ready_toggle : std_logic := '0';
  signal sample_stable_cycles : integer := 0; 

begin

    i_audio_clk : entity work.audio_clock
        generic map (            
            fs      => 48.0,
            ratio   => 256
        )
      port map (
            select_44100 => select_44100,
            rsti         => ref_rst,
            clki         => ref_clk,
            rsto         => pcm_rst,
            clk          => pcm_clk,
            clken        => pcm_clken
        );

    process(pcm_clk)
    begin
        if rising_edge(pcm_clk) then
          -- Receive samples via slow toggle clock from CPU clock domain
          if last_sample_ready_toggle /= sample_ready_toggle then
            sample_stable_cycles <= 0;
            last_sample_ready_toggle <= sample_ready_toggle;
          else
            sample_stable_cycles <= sample_stable_cycles + 1;
            if sample_stable_cycles = 8 then
              pcm_l <= audio_left_slow;
              pcm_r <= audio_right_slow;
            end if;
          end if;
          
        end if;
    end process;
    
end architecture synth;
