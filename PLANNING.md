# Starhawk -- Planning

## Format

Vertical scroller -- the player flies upward through a scrolling level, rather
than a fixed-screen shooter.

## Build Phases

1. **Game skeleton** -- a game-state machine (title -> playing -> game over)
   so every later phase has somewhere to plug in.
2. **Title screen** -- game name, "press start" prompt, basic menu feel.
3. **Player ship** -- movement, screen bounds, basic sprite/shape.
4. **Shooting** -- bullets, fire rate, despawning off-screen.
5. **Enemies** -- spawning, movement patterns, collision with bullets.
6. **Collision & health/lives** -- player getting hit, death, respawn or
   game over.
7. **Score & HUD** -- score tracking, lives display, basic font/UI pass.
8. **Game over screen** -- final score, restart prompt, back to title.
9. **Polish** -- sound effects, particle/explosion effects, difficulty
   scaling, maybe a parallax starfield background.
10. **Power-ups** -- rapid fire, spread shot, shield, and laser beam
    pickups. Best implemented after shooting, enemies, and collision
    (phases 4-6) are working, since a pickup is itself a collision event.

## Future Consideration: Per-Stage Music (Not Yet a Phase)

True to 90s arcade shmups, each stage should have its own music track
rather than one loop for the whole game. Not implemented -- there's no
stage/level progression system yet, and `states/playing.lua` currently
just hardcodes `stage1.mp3`. Once stages are a real concept, `playing.lua`
will need to know which stage it's on and load that stage's music (and
probably its background/enemy set) accordingly, rather than one fixed
set of assets for the whole "playing" state.

## Future Consideration: Difficulty Driven by Level, Not Kills

Phase 6's enemy-tracking delay (see Decisions below) currently shrinks
based on kills this run, since there's no stage/level system yet. The
intent is for it to be driven by level number once stages exist instead.
The code already isolates this behind one function
(`currentTrackingDelay()` in `states/playing.lua`) specifically so that
swap is a small change later, not a rewrite.

## Future Consideration: Turret Enemies Mounted on Structures

Some 90s shmups attach actual gun turrets to the scrolling background
structures (fire at the player as that section passes). Not built yet --
the current structure pieces (see Decisions below) are purely decorative,
no collision or behavior. Worth revisiting once there's a reason to add
a second enemy type.

## Future Consideration: A Homing "Hunter" Enemy Type

The original enemy briefly nudged its drift centerline toward the
player's delayed position (on top of its aimed shots), but that stacked
with aimed fire and made the single enemy type too punishing -- players
were getting hit a lot. Removed; current enemy just falls with a
sine-wave drift around its spawn X and lines up aimed shots only. The
homing idea itself is fine -- it belongs on a distinct second "hunter"
type later, separate from this "shooter" type.

## Future Consideration: More/Reworked Background Structures

Noted for later, not active work: possibly add more structure pieces
beyond the current six, and/or revisit the shapes of the existing ones
(truss, hull, pipes, solar panels, antenna array, docking ring) now that
they have the dark-edge/mid/highlight shading pass.

## Decisions

- **Enemies**: start with a single enemy type (phase 5) to get spawning and
  collision working; additional types/behaviors come later in polish or a
  follow-up phase.
- **Art**: pixel-art sprite sheets (generated PNGs), same approach as the
  pure-python-game-engine platformer hero -- not procedurally-drawn shapes.
  In practice: some assets are hand-made/found (ship.png, enemy-small.png,
  explosion.png, power-up.png) and some are generated via Python/tkinter
  scripts in tools/ (player_bullet.png) -- both are fine, LOVE just loads
  whatever PNG ends up in assets/.
- **Power-up mapping** (power-up.png's 2x2 grid, by ring/gem color):
  - Bright cyan gem, orange ring -> **Laser Beam** (matches the player
    bullet's cyan color)
  - Dark teal gem, orange ring -> **Shield**
  - Orange gem, silver ring -> **Spread Shot**
  - Red gem, silver ring -> **Rapid Fire**
- **Lives & difficulty** (phase 6): 3 lives, 2s invincibility (with a
  flicker) after respawn. Enemy shots are aimed at a deliberately stale
  player position -- 3.0s delay at 0 kills, shrinking 0.1s per kill to
  real-time by 30 kills. Enemies themselves just fall with a sine-wave
  drift around their spawn X, no homing -- see the "hunter" future
  consideration above. See also the difficulty-by-level future
  consideration above.
- **LuaJIT upvalue limit**: a single function can reference at most 60
  local upvalues (LOVE runs LuaJIT, not stock Lua -- `luac5.4 -p` won't
  catch this). `playing.update` hit this once it grew to touch most of
  the module; fixed by splitting it into focused per-system functions
  (`updateShip`, `updateEnemies`, etc.). Keep an eye on function size
  going forward, and always confirm with a real `love .` launch, not
  just a syntax check.
- **Background structures**: a smooth scrolling gradient alone doesn't
  sell speed -- the eye needs concrete landmarks to track. Six
  decorative (no collision) structure pieces -- truss, hull, pipes,
  solar panels, antenna array, docking ring -- spawn one at a time, each
  tall enough to take ~10s to fully scroll past, with a long gap between
  spawns so one piece fully clears before the next appears (distinct
  "flying past a structure, then open space again" stretches). Back
  layer: drawn first, before stars or anything else, so they never
  compete with gameplay.
- **Stage 1 backdrop**: plain black instead of the nebula image
  (`bg_space.png`) -- tried both while chasing a "jittery" feeling that
  turned out to be local machine lag, not the code, and ended up
  preferring black against the structures/stars regardless. `bg_space.png`
  stays loaded for a future stage once there's a real per-stage
  background system (see the per-stage music future consideration).
- **Score & HUD** (phase 7): flat 100 points per kill, isolated behind
  `POINTS_PER_KILL` so a future second enemy type can be worth a
  different amount without touching collision code. HUD shows
  `SCORE`/`KILLS` as text top-left, and lives as a row of small static
  ship icons top-right (ship.png, same sprite as the title screen, just
  smaller and not spin-animated -- animating every icon read as too busy
  at a glance). Replaces the temporary "LIVES: N  KILLS: N" readout.
- **Game over screen** (phase 8): shows final score and kill count,
  passed from `playing.lua` via `changeState("gameover", score,
  killCount)` -- `changeState` now forwards any extra args straight to
  the target state's `enter()`. Visually mirrors the title screen
  (drifting starfield, drop-shadow logo text, blinking prompt) but in
  red/orange instead of cyan. `gameover.mp3` (~11s) plays once on entry
  as a "static" source, not looped like title.mp3/stage1.mp3 -- it's a
  sting, not a loop.

## Assets

| File | Size | Notes |
| --- | --- | --- |
| `ship.png` | 80x48, 5x2 grid of 16x24 | Player ship; the "spin" is all 10 frames cycled. Used on the title screen and as the gameplay ship (phase 3). |
| `player_bullet.png` | 8x16 | Generated (`tools/generate_player_bullet.py`, gitignored); the default (no-powerup) player weapon, cyan to match the ship. Phase 4. |
| `enemy-small.png` | 32x16, 2 frames of 16x16 | Small enemy, idle wobble animation. Phase 5. |
| `explosion.png` | 80x16, 5 frames of 16x16 | One-shot enemy death animation, plays once where an enemy is destroyed. Phase 5. |
| `power-up.png` | 32x32, 2x2 grid of 16x16 | Four power-up pickups; see mapping above. Not wired into gameplay yet. |
| `back.png` | 2048x1536 | User-provided source nebula/starfield image; kept for reference/reprocessing. |
| `bg_space.png` | 800x1200 | `back.png` resized to the game's native width, seamless vertical loop via mirroring. Loaded but not currently drawn -- stage 1 uses a plain black backdrop instead (see Decisions); kept for a later stage once there's a real per-stage background system. |
| `enemy_bullet.png` | 8x16 | Generated (`tools/generate_enemy_bullet.py`, gitignored); red/orange to read as hostile vs. the player's cyan bolts. Phase 6. |
| `player_explosion.png` | 80x16, 5 frames of 16x16 | Generated (`tools/generate_player_explosion.py`, gitignored) by recoloring explosion.png's exact shape to the player's cyan palette. Plays on player death. Phase 6. |
| `structure_truss.png` | 96x900 | Generated (`tools/generate_background_structures.py`, gitignored); lattice girder. Decorative back-layer scenery, no collision. |
| `structure_hull.png` | 96x900 | Station hull/module segment with panel seams and lit windows. Same generator. |
| `structure_pipes.png` | 96x900 | Parallel exterior conduits with flange rings. Same generator. |
| `structure_solar_panels.png` | 160x900 | Central spine with alternating solar panel wings. Same generator. |
| `structure_antenna.png` | 140x900 | Spine with alternating dish/antenna silhouettes. Same generator. |
| `structure_docking_ring.png` | 120x900 | Hull body with circular docking-collar cutouts. Same generator. |
| `title.mp3` | -- | Title screen music; loops, stops the instant Enter is pressed. |
| `stage1.mp3` | -- | Gameplay music; loops at 40% volume so sound effects can cut through. Will need a real stage/level system once more stages exist (see note above). |
| `norm_bullet.wav` | -- | Fires each shot of the normal (no-powerup) player bullet. Phase 4. |
| `enemy1_bullet.wav` | -- | The first enemy type's shot sound. Phase 6. |
| `enemy1_explode.wav` | -- | Plays when an enemy1 is destroyed, or when the player is hit. Phase 5/6. |
| `gameover.mp3` | ~11s | One-shot sting, not looped -- plays once when the game over screen is entered. Phase 8. |

## Status

- [x] Phase 1: Game skeleton
- [x] Phase 2: Title screen
- [x] Phase 3: Player ship
- [x] Phase 4: Shooting
- [x] Phase 5: Enemies
- [x] Phase 6: Collision & health/lives
- [x] Phase 7: Score & HUD
- [x] Phase 8: Game over screen
- [ ] Phase 9: Polish
- [ ] Phase 10: Power-ups
