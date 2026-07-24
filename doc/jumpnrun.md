# Jump & Run Improvements

Many Game Boy classics - Super Mario Land, Wario Land, Donkey Kong, Kirby and
countless others - use a button to jump. On the MEGA65 you can play them the
arcade way instead: choose the joystick mapping "Up=A, Fire=B" (or "Up=B,
Fire=A") and pushing the stick up makes your hero jump, just like on the C64
or the Amiga.

The "Jump & Run Improvements" make this feel as good as it sounds. You find
them in the on-screen-menu under "Joystick", directly below the mapping
choices. They only take effect in the two "Up=..." mappings; in the Standard
mappings the core always behaves exactly like a real Game Boy with a game pad.

## Why jumping with a joystick feels different

On the original handheld, two thumbs share the work: one keeps the d-pad
pressed towards the direction you are running, the other presses the jump
button. Without thinking about it, players give the game three guarantees:

1. **The direction stays held while you jump.** Your left thumb never lets go
   of "right" just because your right thumb presses the button.
2. **The jump button stays pressed for a while.** Most Game Boy jump'n'runs
   measure how long you hold the button: a short tap is a small hop, holding
   it makes the full jump. A "full" jump typically wants the button held for
   an eighth of a second or more.
3. **Releasing the button is clearly separated from the next press**, so the
   game can tell two jumps apart.

With up-to-jump on a joystick, one single lever suddenly has to do the work of
both thumbs - and a quick, instinctive flick towards "up" quietly breaks all
three guarantees at once: for a split second the stick leaves the "right"
position (guarantee 1), the flick is over faster than the game expects the
button to be held (guarantee 2), and a very fast double-flick can be quicker
than the game looks at the controls (guarantee 3).

Games punish this surprisingly hard. Super Mario Land, for example, keeps
Mario's forward speed in the air only while "right" stays pressed: if the
stick leaves "right" for just a thirtieth of a second around the jump, a full
running jump collapses from about 113 pixels of distance to about 30 - Mario
pops straight up and lands almost where he took off. And a fast flick that
holds "up" only briefly produces a half-height hop instead of a full jump.
It feels like the core swallowed your input or reacted late. It did not - the
game simply did exactly what a Game Boy would have done with that stick.

## The three settings

- **Off** - the assist is completely out of the circuit. The core behaves
  bit-exactly like a real Game Boy wired to your joystick.

- **Soft** (the default) - the assist restores the three guarantees while
  keeping you in full control of the jump height. While you flick up, the
  direction you were running keeps counting as held, so your jumps keep their
  forward momentum. Very short flicks are gently extended so that the game
  reliably sees them, but the "tap for a small hop, hold for a full jump"
  skill stays completely intact.

- **Full** - like Soft, but every flick counts as a decisively held jump
  button. You give up the fine height control; in exchange, a casual flick
  produces a proper full jump every time. This is the relaxed, C64-style
  "the stick does the work" setting.

If you are not sure: stay on Soft. Switch to Full if you find yourself
wishing that quick flicks would jump higher.

## What the assist never does

- It never presses anything you did not press. Every signal it sends to the
  game corresponds to a real movement of your stick - it only smooths the
  timing.
- It never adds lag. Presses always pass through instantly; the assist only
  ever extends things, never delays them.
- It never interferes with your intent. Pushing the opposite direction or
  down instantly overrides the assist, stopping on the spot works exactly as
  without it, and a deliberate "stop, then jump straight up" stays a perfectly
  vertical jump.
- It never changes the Standard mappings, the keyboard, or the games
  themselves. Set it to Off and the core is exactly as before.

## One tip that still helps

Even with the assist active, the nicest way to jump while running is to roll
the stick into the diagonal - up and forward at the same time - and hold it
there through the jump, the way arcade players do. The assist then has almost
nothing left to fix; it mainly catches the fast, instinctive flicks that
happen in the heat of the moment.

## For the technically inclined

The assist is a small, fully deterministic state machine
(`CORE/vhdl/joystick_assist.vhd`) between the merged joystick ports and the
joypad matrix adapter. Its design rule is *time-shaping, never synthesis*:
every output edge corresponds to a physical input edge, presses pass with zero
added latency, and only releases are re-timed. There is no adaptivity and no
randomness - identical stick timelines always produce identical results.

Three rules, with all windows in milliseconds:

| Rule | What it does | Window |
| --- | --- | --- |
| Bridge | A horizontal direction that was held for at least 70 ms keeps counting as held during an up-gesture: armed when the direction releases while up is pressed, or retroactively when up closes within 50 ms after the release (a flick through the neutral zone). It ends immediately on the opposite direction or down, seamlessly on a physical re-press, or 50 ms after up opens. | 70 / 50 / 50 ms |
| Minimum press | The up direction (which the mapping turns into the A or B button) is reported held for at least 80 ms (Soft) or 200 ms (Full). | 80 / 200 ms |
| Re-arm | After up opens, the release is reported for at least 33 ms (two 60 Hz polls) before a re-press passes through, so edge-triggered jump logic always re-arms. | 33 ms |

The retroactive arming is what keeps the assist latency-free: a normal
release propagates instantly, and only if "up" follows within the 50 ms window
does the direction get re-asserted - in time for the game's next poll, because
Game Boy games read the joypad once per frame. The deliberate
"stop, then jump vertically" gesture is never bridged, since its release-to-up
gap exceeds the window. Left+right can never leave the entity simultaneously,
and the whole assist is transparent (a wire) when disabled or in a Standard
mapping.

The windows were validated against Super Mario Land in an instrumented
emulator, driving the game with scripted stick gestures and reading the
engine's own state variables. Reference is a perfect pad-style running jump
(39 px apex, 111 px distance):

| Gesture | Without assist | Soft | Full |
| --- | --- | --- | --- |
| Flick to straight up, 50 ms | 21 px / 17 px | 23 px / 50 px | 35 px / 68 px |
| Up held, but stick left "right" | 39 px / 26 px | 39 px / 111 px | 39 px / 111 px |
| "Right" slips for 33 ms mid-air | 39 px / 33 px | 39 px / 111 px | 39 px / 111 px |
| Precision stop, no jump | identical | identical | identical |
| Stop, then vertical jump | identical | identical | identical |
| Jump, then reverse direction | identical | identical | identical |

The last three rows are the guardrails: gestures that express a clear intent
are bit-identical with and without the assist.

In the hardware, the OSM radio group is decoded in `CORE/vhdl/mega65.vhd`
(fall-through default Soft, so an all-zero configuration file is safe) and
hard-gated in `CORE/vhdl/main.vhd` to the two "Up=..." mappings. The state
machine runs in the core clock domain on a millisecond tick; the two
flicker-free clock legs differ by at most 0.5%, which is irrelevant for these
windows.
