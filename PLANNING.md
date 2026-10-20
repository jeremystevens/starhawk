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
| `ship.png` | 80x48, 5x2 grid of 16x24 | Player ship; the "spin" is all 10 frames cycled. Used on the title screen; will be the gameplay ship in phase 3. |
| `player_bullet.png` | 8x16 | Generated (`tools/generate_player_bullet.py`); the default player weapon, cyan to match the ship. |
| `laser-bolts.png` | 32x32, 2x2 grid of 16x16 | Top row: round orb bolts (unused for now). Bottom row: elongated beam bolts -- the enemy-hit projectile shown in the enemy-destroyed.gif reference. |
| `enemy-small.png` | 32x16, 2 frames of 16x16 | Small enemy, idle wobble animation. |
| `explosion.png` | 80x16, 5 frames of 16x16 | Enemy death animation. |
| `power-up.png` | 32x32, 2x2 grid of 16x16 | Four power-up pickups; see mapping above. |

## Status

- [x] Phase 1: Game skeleton
- [x] Phase 2: Title screen
- [ ] Phase 3: Player ship
- [ ] Phase 4: Shooting
- [ ] Phase 5: Enemies
- [ ] Phase 6: Collision & health/lives
- [ ] Phase 7: Score & HUD
- [ ] Phase 8: Game over screen
- [ ] Phase 9: Polish
- [ ] Phase 10: Power-ups
