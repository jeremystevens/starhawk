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

## Decisions

- **Enemies**: start with a single enemy type (phase 5) to get spawning and
  collision working; additional types/behaviors come later in polish or a
  follow-up phase.
- **Art**: pixel-art sprite sheets (generated PNGs), same approach as the
  pure-python-game-engine platformer hero -- not procedurally-drawn shapes.

## Status

Not started -- this doc exists to plan before writing any game code.
