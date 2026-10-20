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

## Assets

| File | Size | Notes |
| --- | --- | --- |
| `ship.png` | 80x48, 5x2 grid of 16x24 | Player ship; the "spin" is all 10 frames cycled. Used on the title screen and as the gameplay ship (phase 3). |
| `player_bullet.png` | 8x16 | Generated (`tools/generate_player_bullet.py`, gitignored); the default player weapon, cyan to match the ship. Not wired into gameplay yet. |
| `enemy-small.png` | 32x16, 2 frames of 16x16 | Small enemy, idle wobble animation. Not wired into gameplay yet. |
| `explosion.png` | 80x16, 5 frames of 16x16 | Enemy death animation. Not wired into gameplay yet. |
| `power-up.png` | 32x32, 2x2 grid of 16x16 | Four power-up pickups; see mapping above. Not wired into gameplay yet. |
| `back.png` | 2048x1536 | User-provided source nebula/starfield image; kept for reference/reprocessing. |
| `bg_space.png` | 800x1200 | `back.png` resized to the game's native width, seamless vertical loop via mirroring. The phase 3 gameplay background. |
| `title.mp3` | -- | Title screen music; loops, stops the instant Enter is pressed. |
| `stage1.mp3` | -- | Gameplay music; loops at 40% volume so future sound effects can cut through. Will need a real stage/level system once more stages exist (see note above). |

## Status

- [x] Phase 1: Game skeleton
- [x] Phase 2: Title screen
- [x] Phase 3: Player ship
- [ ] Phase 4: Shooting
- [ ] Phase 5: Enemies
- [ ] Phase 6: Collision & health/lives
- [ ] Phase 7: Score & HUD
- [ ] Phase 8: Game over screen
- [ ] Phase 9: Polish
- [ ] Phase 10: Power-ups
