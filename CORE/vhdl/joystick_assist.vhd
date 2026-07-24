---------------------------------------------------------------------------------------------------------
-- Game Boy and Game Boy Color for MEGA65 (gbc4mega65)
--
-- Joystick assist: the OSM "Jump & Run Improvements" for the Up=A and Up=B mappings
--
-- Many Game Boy jump'n'run games were designed around two thumbs: one holds a d-pad
-- direction while the other operates the jump button. With the stick-up-as-button
-- mappings a single lever does both jobs, and two gesture artifacts break the games'
-- expectations (measured with Super Mario Land, whose engine keeps forward momentum
-- in the air only while the direction stays held and scales jump height with how
-- long the button is held):
--    1. Flicking towards "up" releases the horizontal direction for a few frames,
--       which kills the horizontal momentum of the jump.
--    2. A quick flick holds "up" (= the jump button) too short for full jump height,
--       and a too-quick release can even stay invisible to the game's 60 Hz polling.
--
-- This entity reconditions the joystick vector with three deterministic rules.
-- It is pure time-shaping: every output edge corresponds to a physical input edge,
-- presses pass with zero added latency, and only releases are delayed.
--
--    BRIDGE    While an up-gesture is in progress, a horizontal direction that was
--              held for at least C_MINRUN_MS keeps being reported as held: armed
--              when the direction releases while up is pressed (corner roll) or
--              retroactively when up closes within C_RETRO_MS after the release
--              (flick through the neutral zone). The bridge ends immediately on the
--              opposite direction or down (the player signals a new intent, and no
--              left+right combination can ever leave this entity), seamlessly on a
--              physical re-press, or C_TAIL_MS after up opens (covers the return
--              transit of the lever). A deliberate "stop, then jump vertically" is
--              never bridged because its release-to-up gap exceeds C_RETRO_MS.
--    MINWIDTH  The up direction (= the mapped button) is reported held for at least
--              C_SOFT_MS ("Soft" preset, preserves the hold-for-height nuance) or
--              C_FULL_MS ("Full" preset, every flick becomes a full jump).
--    REARM     After up opens, the release is reported for at least C_REARM_MS
--              before a re-press passes through, so even the fastest double-flick
--              re-arms the edge-triggered jump logic of the games.
--
-- The two flicker-free core clock legs differ by 0.5% at most, which is irrelevant
-- for the millisecond windows, so G_CLK_FREQ is simply the native CORE_CLK_SPEED.
-- Fire and down always pass through unmodified. When enable_i is 0 the entity is
-- transparent and its state mirrors the physical stick, so that enabling it in the
-- OSM mid-game never produces a stale edge.
--
-- Runs in the clock domain of the core.
--
-- This machine is based on Gameboy_MiSTer
-- Powered by MiSTer2MEGA65
-- MEGA65 port done by sy2002 in 2021 - 2026 and licensed under GPL v3
---------------------------------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity joystick_assist is
   generic (
      G_CLK_FREQ           : natural                       -- core clock frequency in Hz
   );
   port (
      clk_main_i           : in  std_logic;                -- core clock
      reset_i              : in  std_logic;

      -- '1': assist active; gate this with "mapping is Up=A or Up=B" and the OSM preset
      enable_i             : in  std_logic;
      -- '0': "Soft" preset (C_SOFT_MS), '1': "Full" preset (C_FULL_MS)
      full_i               : in  std_logic;

      -- MEGA65 joystick vector, low active
      -- bit order: 4 = fire, 3 = up, 2 = down, 1 = left, 0 = right
      joystick_i           : in  std_logic_vector(4 downto 0);
      joystick_o           : out std_logic_vector(4 downto 0)
   );
end entity joystick_assist;

architecture beh of joystick_assist is

-- gesture windows in milliseconds, validated against Super Mario Land (see doc/jumpnrun.md)
constant C_RETRO_MS        : natural := 50;    -- max neutral gap of a flick that still bridges
constant C_TAIL_MS         : natural := 50;    -- bridge survival after up opens (return transit)
constant C_MINRUN_MS       : natural := 70;    -- direction must be held this long to be bridgeable
constant C_SOFT_MS         : natural := 80;    -- minimum reported press of up, "Soft" preset
constant C_FULL_MS         : natural := 200;   -- minimum reported press of up, "Full" preset
constant C_REARM_MS        : natural := 33;    -- minimum reported release of up (two 60 Hz polls)

constant C_TICK_MAX        : natural := G_CLK_FREQ / 1000 - 1;
constant C_SAT             : natural := 255;   -- all millisecond counters saturate here

-- physical stick, high active
signal up                  : std_logic;
signal dwn                 : std_logic;
signal lft                 : std_logic;
signal rgt                 : std_logic;

-- previous clock cycle of the physical stick (edge detection)
signal up_q                : std_logic;
signal lft_q               : std_logic;
signal rgt_q               : std_logic;

-- millisecond time base
signal tick_cnt            : natural range 0 to C_TICK_MAX;

-- BRIDGE state
type t_bridge is (IDLE, HOLD_RIGHT, HOLD_LEFT);
signal bridge              : t_bridge;
signal tail_ms             : natural range 0 to C_SAT;     -- ms since up opened while bridging
signal rgt_hold_ms         : natural range 0 to C_SAT;     -- ms right is being held
signal rgt_rel_ms          : natural range 0 to C_SAT;     -- ms since right was released
signal rgt_long            : std_logic;                    -- last right hold reached C_MINRUN_MS
signal lft_hold_ms         : natural range 0 to C_SAT;
signal lft_rel_ms          : natural range 0 to C_SAT;
signal lft_long            : std_logic;

-- MINWIDTH/REARM state: the shaped up direction (= the mapped Game Boy button)
signal btn_out             : std_logic;
signal btn_age_ms          : natural range 0 to C_SAT;     -- ms btn_out is being reported held
signal btn_gap_ms          : natural range 0 to C_SAT;     -- ms btn_out is being reported released
signal btn_pend            : std_logic;                    -- press waiting for C_REARM_MS to pass

begin

   up  <= not joystick_i(3);
   dwn <= not joystick_i(2);
   lft <= not joystick_i(1);
   rgt <= not joystick_i(0);

   p_assist : process (clk_main_i)
      variable v_tick    : boolean;
      variable v_up_rise : boolean;
      variable v_press   : natural range 0 to C_SAT;
      variable v_bridge  : t_bridge;
   begin
      if rising_edge(clk_main_i) then
         -- millisecond tick
         v_tick := tick_cnt = C_TICK_MAX;
         if v_tick then
            tick_cnt <= 0;
         else
            tick_cnt <= tick_cnt + 1;
         end if;

         v_up_rise := up = '1' and up_q = '0';

         -- hold/release age bookkeeping of the horizontal directions
         if rgt = '1' then
            if v_tick and rgt_hold_ms /= C_SAT then
               rgt_hold_ms <= rgt_hold_ms + 1;
            end if;
         else
            if rgt_q = '1' then                            -- release edge: remember if it was a real run
               rgt_long    <= '1' when rgt_hold_ms >= C_MINRUN_MS else '0';
               rgt_hold_ms <= 0;
               rgt_rel_ms  <= 0;
            elsif v_tick and rgt_rel_ms /= C_SAT then
               rgt_rel_ms <= rgt_rel_ms + 1;
            end if;
         end if;
         if lft = '1' then
            if v_tick and lft_hold_ms /= C_SAT then
               lft_hold_ms <= lft_hold_ms + 1;
            end if;
         else
            if lft_q = '1' then
               lft_long    <= '1' when lft_hold_ms >= C_MINRUN_MS else '0';
               lft_hold_ms <= 0;
               lft_rel_ms  <= 0;
            elsif v_tick and lft_rel_ms /= C_SAT then
               lft_rel_ms <= lft_rel_ms + 1;
            end if;
         end if;

         -- BRIDGE: arm first, then the cancel conditions win over a same-cycle arm
         v_bridge := bridge;
         if bridge = IDLE then
            if rgt = '0' and ((rgt_q = '1' and up = '1' and rgt_hold_ms >= C_MINRUN_MS) or
                              (v_up_rise and rgt_rel_ms <= C_RETRO_MS and rgt_long = '1')) then
               v_bridge := HOLD_RIGHT;
               tail_ms  <= 0;
            elsif lft = '0' and ((lft_q = '1' and up = '1' and lft_hold_ms >= C_MINRUN_MS) or
                                 (v_up_rise and lft_rel_ms <= C_RETRO_MS and lft_long = '1')) then
               v_bridge := HOLD_LEFT;
               tail_ms  <= 0;
            end if;
         end if;
         if v_bridge = HOLD_RIGHT and (lft = '1' or dwn = '1' or rgt = '1') then
            v_bridge := IDLE;
         elsif v_bridge = HOLD_LEFT and (rgt = '1' or dwn = '1' or lft = '1') then
            v_bridge := IDLE;
         end if;
         if v_bridge /= IDLE then
            if up = '1' then
               tail_ms <= 0;
            elsif v_tick then
               if tail_ms >= C_TAIL_MS then
                  v_bridge := IDLE;
               else
                  tail_ms <= tail_ms + 1;
               end if;
            end if;
         end if;
         bridge <= v_bridge;

         -- MINWIDTH/REARM: shape the up direction into btn_out
         if full_i = '1' then
            v_press := C_FULL_MS;
         else
            v_press := C_SOFT_MS;
         end if;
         if btn_out = '1' then
            if v_tick and btn_age_ms /= C_SAT then
               btn_age_ms <= btn_age_ms + 1;
            end if;
         else
            if v_tick and btn_gap_ms /= C_SAT then
               btn_gap_ms <= btn_gap_ms + 1;
            end if;
         end if;
         if (v_up_rise or btn_pend = '1') and btn_out = '0' then
            if btn_gap_ms >= C_REARM_MS then
               btn_out    <= '1';
               btn_age_ms <= 0;
               btn_pend   <= '0';
            else
               btn_pend   <= '1';
            end if;
         end if;
         if btn_out = '1' and up = '0' and btn_age_ms >= v_press then
            btn_out    <= '0';
            btn_gap_ms <= 0;
         end if;

         up_q  <= up;
         rgt_q <= rgt;
         lft_q <= lft;

         -- while in reset or disabled: stay transparent and mirror the physical stick,
         -- so that switching the assist on mid-game never produces a stale edge
         if reset_i = '1' or enable_i = '0' then
            bridge      <= IDLE;
            tail_ms     <= 0;
            rgt_rel_ms  <= C_SAT;
            lft_rel_ms  <= C_SAT;
            rgt_long    <= '0';
            lft_long    <= '0';
            rgt_hold_ms <= C_SAT when rgt = '1' and reset_i = '0' else 0;
            lft_hold_ms <= C_SAT when lft = '1' and reset_i = '0' else 0;
            btn_out     <= up and not reset_i;
            btn_age_ms  <= C_SAT;
            btn_gap_ms  <= C_SAT;
            btn_pend    <= '0';
         end if;
      end if;
   end process p_assist;

   -- low active outputs; fire and down always pass through
   joystick_o(4) <= joystick_i(4);
   joystick_o(3) <= not btn_out when enable_i = '1' else joystick_i(3);
   joystick_o(2) <= joystick_i(2);
   joystick_o(1) <= '0' when enable_i = '1' and (lft = '1' or bridge = HOLD_LEFT) else joystick_i(1);
   joystick_o(0) <= '0' when enable_i = '1' and (rgt = '1' or bridge = HOLD_RIGHT) else joystick_i(0);

end architecture beh;
