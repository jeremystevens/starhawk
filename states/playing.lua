local playing = {}

local WIDTH, HEIGHT = love.graphics.getWidth(), love.graphics.getHeight()

-- Background: resized/mirrored from the user-provided back.png (see
-- tools/generate_background.py history) -- native 800px width, seamless
-- vertical loop via mirroring.
local BG_SCROLL_SPEED = 240
local bgImage = love.graphics.newImage("assets/bg_space.png")
bgImage:setFilter("linear", "linear")
local _, bgHeight = bgImage:getDimensions()
local bgOffset = 0

-- Background structures: long station/truss/pipe silhouettes that drift
-- down with the world, same speed as the nebula background. A smooth
-- gradient scrolling fast still reads as static -- these give the eye
-- concrete landmarks to track, which is what actually sells speed.
-- Deliberately a back layer: drawn right after the nebula, before stars
-- or anything else, so they never compete with gameplay.
local STRUCTURE_SCALE = 2
-- Pieces are tall enough now to take ~10s to fully scroll past at the
-- current BG_SCROLL_SPEED -- the spawn gap needs to clear that so one
-- piece fully exits before the next appears, giving distinct "flying
-- past a structure, then open space again" stretches rather than
-- overlapping pieces.
local STRUCTURE_SPAWN_MIN_INTERVAL = 14.0
local STRUCTURE_SPAWN_MAX_INTERVAL = 20.0

local structureImages = {
    love.graphics.newImage("assets/structure_truss.png"),
    love.graphics.newImage("assets/structure_hull.png"),
    love.graphics.newImage("assets/structure_pipes.png"),
    love.graphics.newImage("assets/structure_solar_panels.png"),
    love.graphics.newImage("assets/structure_antenna.png"),
    love.graphics.newImage("assets/structure_docking_ring.png"),
}
for _, image in ipairs(structureImages) do
    image:setFilter("nearest", "nearest")
end

local structures = {}
local structureSpawnTimer = 0

local function spawnStructure()
    local image = structureImages[love.math.random(1, #structureImages)]
    local imgW, imgH = image:getDimensions()
    local drawW, drawH = imgW * STRUCTURE_SCALE, imgH * STRUCTURE_SCALE
    table.insert(structures, {
        image = image,
        x = love.math.random(0, WIDTH - drawW),
        y = -drawH,
        drawW = drawW,
        drawH = drawH,
    })
end

-- Drifting, twinkling star layer -- same technique as the title screen's
-- starfield, but faster (closer) with a twinkle so it reads as a distinct
-- layer in front of the nebula backdrop.
local NUM_STARS = 60
local stars = {}
for i = 1, NUM_STARS do
    stars[i] = {
        x = love.math.random(0, WIDTH),
        y = love.math.random(0, HEIGHT),
        speed = love.math.random(310, 500),
        size = love.math.random(1, 2),
        twinklePhase = love.math.random() * math.pi * 2,
        twinkleSpeed = love.math.random(2, 5),
    }
end

-- Player ship: ship.png's full spin animation, per decision -- it
-- replaces the custom-generated ship entirely, spin included, even
-- though it won't track movement direction.
local SHIP_FRAME_W, SHIP_FRAME_H = 16, 24
local SHIP_COLS, SHIP_ROWS = 5, 2
local SHIP_SCALE = 2
local SHIP_FRAME_DURATION = 0.15
local SHIP_MAX_SPEED = 300
local SHIP_ACCELERATION = 1400  -- px/s^2 while a direction is held
local SHIP_DECELERATION = 1800  -- px/s^2 while drifting to a stop

local shipImage = love.graphics.newImage("assets/ship.png")
shipImage:setFilter("nearest", "nearest")

local shipQuads = {}
for row = 0, SHIP_ROWS - 1 do
    for col = 0, SHIP_COLS - 1 do
        table.insert(shipQuads, love.graphics.newQuad(
            col * SHIP_FRAME_W, row * SHIP_FRAME_H, SHIP_FRAME_W, SHIP_FRAME_H,
            shipImage:getDimensions()
        ))
    end
end

local shipFrameIndex = 1
local shipFrameTimer = 0
local shipX, shipY = WIDTH / 2, HEIGHT - 100
local shipVelX, shipVelY = 0, 0

-- Player position history, so enemies can be given a deliberately stale
-- view of "where the player is" (see currentTrackingDelay() below) rather
-- than always knowing the real-time position -- that's what keeps early
-- enemies from feeling perfectly accurate.
local POSITION_HISTORY_MAX_AGE = 3.5  -- keep more than the largest delay we'll ever use
local totalElapsedTime = 0
local positionHistory = {}

local function recordPlayerPosition()
    table.insert(positionHistory, { t = totalElapsedTime, x = shipX, y = shipY })
    while #positionHistory > 0 and positionHistory[1].t < totalElapsedTime - POSITION_HISTORY_MAX_AGE do
        table.remove(positionHistory, 1)
    end
end

local function getDelayedPlayerPosition(delay)
    if delay <= 0 or #positionHistory == 0 then
        return shipX, shipY
    end
    local targetTime = totalElapsedTime - delay
    if positionHistory[1].t >= targetTime then
        return positionHistory[1].x, positionHistory[1].y  -- not enough history yet
    end
    -- Walk from the most recent sample backward to the first one at or
    -- before targetTime -- that's "what we knew" at that moment.
    for i = #positionHistory, 1, -1 do
        if positionHistory[i].t <= targetTime then
            return positionHistory[i].x, positionHistory[i].y
        end
    end
    return positionHistory[1].x, positionHistory[1].y
end

local music = love.audio.newSource("assets/stage1.mp3", "stream")
music:setLooping(true)
music:setVolume(0.4)  -- stays in the background so sound effects cut through

-- Player bullets: the normal, no-powerup shot. Fire rate and other
-- weapon variants (rapid fire, spread, laser beam) are phase 10's job.
local BULLET_W, BULLET_H = 8, 16
local BULLET_SPEED = 500
local FIRE_COOLDOWN = 0.2  -- seconds between shots while held (5/sec)

local bulletImage = love.graphics.newImage("assets/player_bullet.png")
bulletImage:setFilter("nearest", "nearest")
local bulletSound = love.audio.newSource("assets/norm_bullet.wav", "static")

local bullets = {}
local fireCooldownRemaining = 0

local function fireBullet()
    table.insert(bullets, {
        x = shipX,
        y = shipY - (SHIP_FRAME_H * SHIP_SCALE) / 2,
    })
    -- Cloned so overlapping shots don't cut each other's sound off.
    love.audio.play(bulletSound:clone())
end

-- Enemies: a single type for phase 5 (spawning, movement, collision with
-- player bullets). Enemies shooting back is phase 6's job, alongside
-- actual player damage.
local ENEMY_FRAME_W, ENEMY_FRAME_H = 16, 16
local ENEMY_SCALE = 2
local ENEMY_FRAME_DURATION = 0.3
local ENEMY_FALL_SPEED = 215  -- too far below BG_SCROLL_SPEED and enemies visually lag the backdrop (look like they're drifting backward); too close and they close distance too fast to react to
local ENEMY_DRIFT_AMPLITUDE = 40
local ENEMY_DRIFT_FREQUENCY = 1.5
local SPAWN_INTERVAL = 1.2
local ENEMY_FIRE_MIN_INTERVAL = 2.2  -- bumped alongside ENEMY_FALL_SPEED -- faster-falling enemies are on screen less time, so give each one more breathing room between shots
local ENEMY_FIRE_MAX_INTERVAL = 4.0

-- Difficulty curve: enemy shots are aimed at a deliberately stale player
-- position, less stale as this run goes on. Driven by kills for now since
-- there's no stage/level system yet -- once one exists, this should be
-- driven by level number instead; everything else (getDelayedPlayerPosition,
-- the aim code in enemyFireBullet) stays the same either way.
local MAX_TRACKING_DELAY = 3.0      -- seconds, at 0 kills
local TRACKING_DELAY_PER_KILL = 0.1 -- seconds removed per kill (reaches 0 at 30 kills)
local killCount = 0

-- Score: flat points per kill for now -- isolated behind one constant so
-- a future second enemy type can carry a different value without
-- touching the collision code that awards it.
local POINTS_PER_KILL = 100
local score = 0

local function currentTrackingDelay()
    return math.max(0, MAX_TRACKING_DELAY - killCount * TRACKING_DELAY_PER_KILL)
end

local enemyImage = love.graphics.newImage("assets/enemy-small.png")
enemyImage:setFilter("nearest", "nearest")
local enemyQuads = {}
for col = 0, 1 do
    table.insert(enemyQuads, love.graphics.newQuad(
        col * ENEMY_FRAME_W, 0, ENEMY_FRAME_W, ENEMY_FRAME_H,
        enemyImage:getDimensions()
    ))
end

local enemies = {}
local spawnTimer = 0

local function spawnEnemy()
    local halfW = (ENEMY_FRAME_W * ENEMY_SCALE) / 2
    local baseX = love.math.random(halfW, WIDTH - halfW)
    table.insert(enemies, {
        baseX = baseX,
        x = baseX,
        y = -(ENEMY_FRAME_H * ENEMY_SCALE) / 2,
        drift = love.math.random() * math.pi * 2,
        frameIndex = 1,
        frameTimer = 0,
        fireTimer = love.math.random() * (ENEMY_FIRE_MAX_INTERVAL - ENEMY_FIRE_MIN_INTERVAL) + ENEMY_FIRE_MIN_INTERVAL,
    })
end

-- Explosions: a one-shot (non-looping) playback of explosion.png's 5
-- frames wherever an enemy was destroyed.
local EXPLOSION_FRAME_W, EXPLOSION_FRAME_H = 16, 16
local EXPLOSION_SCALE = 2
local EXPLOSION_FRAME_DURATION = 0.06
local EXPLOSION_FRAME_COUNT = 5

local explosionImage = love.graphics.newImage("assets/explosion.png")
explosionImage:setFilter("nearest", "nearest")
local explosionQuads = {}
for col = 0, EXPLOSION_FRAME_COUNT - 1 do
    table.insert(explosionQuads, love.graphics.newQuad(
        col * EXPLOSION_FRAME_W, 0, EXPLOSION_FRAME_W, EXPLOSION_FRAME_H,
        explosionImage:getDimensions()
    ))
end

-- player_explosion.png is the same shape/frames as explosion.png, just
-- recolored to the player's cyan palette (see
-- tools/generate_player_explosion.py) -- same quads work for both since
-- they're the same dimensions.
local playerExplosionImage = love.graphics.newImage("assets/player_explosion.png")
playerExplosionImage:setFilter("nearest", "nearest")

local explosions = {}
local explosionSound = love.audio.newSource("assets/enemy1_explode.wav", "static")

-- Particle burst layered on top of the sprite-sheet explosion animation --
-- small bright sparks plus a few slower debris chunks that fall with
-- gravity, both fading out over their lifetime. Pure rectangles, no new
-- art needed. Colors follow the project's existing hostile/friendly
-- language (enemy bullets red/orange, player stuff cyan).
local SPARK_COUNT = 18
local DEBRIS_COUNT = 7
local DEBRIS_GRAVITY = 260  -- px/s^2, debris only -- gives chunks weight, sparks stay weightless
local ENEMY_SPARK_COLOR = { 1, 0.75, 0.25 }
local ENEMY_DEBRIS_COLOR = { 0.45, 0.32, 0.18 }
local PLAYER_SPARK_COLOR = { 0.5, 0.95, 1 }
local PLAYER_DEBRIS_COLOR = { 0.25, 0.55, 0.65 }

local particles = {}

local function spawnParticles(x, y, isPlayer)
    local sparkColor = isPlayer and PLAYER_SPARK_COLOR or ENEMY_SPARK_COLOR
    local debrisColor = isPlayer and PLAYER_DEBRIS_COLOR or ENEMY_DEBRIS_COLOR

    for i = 1, SPARK_COUNT do
        local angle = love.math.random() * math.pi * 2
        local speed = love.math.random(100, 280)
        local life = love.math.random() * 0.3 + 0.3
        table.insert(particles, {
            kind = "spark",
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            size = love.math.random(2, 3),
            color = sparkColor,
            life = life, maxLife = life,
            drag = 2.5,
        })
    end

    for i = 1, DEBRIS_COUNT do
        local angle = love.math.random() * math.pi * 2
        local speed = love.math.random(40, 140)
        local life = love.math.random() * 0.35 + 0.45
        table.insert(particles, {
            kind = "debris",
            x = x, y = y,
            vx = math.cos(angle) * speed,
            vy = math.sin(angle) * speed,
            size = love.math.random(3, 6),
            color = debrisColor,
            life = life, maxLife = life,
            drag = 1.0,
        })
    end
end

local function spawnExplosion(x, y, image)
    table.insert(explosions, {
        x = x, y = y, image = image or explosionImage,
        frameIndex = 1, frameTimer = 0,
    })
    spawnParticles(x, y, image == playerExplosionImage)
    love.audio.play(explosionSound:clone())
end

-- Enemy bullets: fired by each enemy on its own timer. Red/orange so
-- they read as hostile vs. the player's cyan bolts.
local ENEMY_BULLET_W, ENEMY_BULLET_H = 8, 16
local ENEMY_BULLET_SPEED = 260

local enemyBulletImage = love.graphics.newImage("assets/enemy_bullet.png")
enemyBulletImage:setFilter("nearest", "nearest")
local enemyBulletSound = love.audio.newSource("assets/enemy1_bullet.wav", "static")

local enemyBullets = {}

local function enemyFireBullet(enemy)
    -- Aimed at the player's delayed (stale) position, not the real one --
    -- see currentTrackingDelay() above.
    local targetX, targetY = getDelayedPlayerPosition(currentTrackingDelay())
    local dx, dy = targetX - enemy.x, targetY - enemy.y
    local length = math.sqrt(dx * dx + dy * dy)
    if length == 0 then
        dx, dy, length = 0, 1, 1  -- degenerate case: just fire straight down
    end

    table.insert(enemyBullets, {
        x = enemy.x,
        y = enemy.y,
        vx = (dx / length) * ENEMY_BULLET_SPEED,
        vy = (dy / length) * ENEMY_BULLET_SPEED,
    })
    love.audio.play(enemyBulletSound:clone())
end

-- Player lives, invincibility after respawn (with a flicker so it's
-- visible), and the respawn/game-over flow.
local START_LIVES = 3
local INVINCIBLE_DURATION = 2.0
local INVINCIBLE_FLICKER_INTERVAL = 0.1

local lives = START_LIVES
local invincibleRemaining = 0
local flickerTimer = 0
local shipVisible = true

-- HUD: score/kills text plus a row of small ship icons for lives --
-- same ship.png used on the title screen, just smaller and a single
-- static frame (animating every icon would be too busy at a glance).
local HUD_MARGIN = 12
local HUD_SHIP_SCALE = 1
local HUD_ICON_SPACING = (SHIP_FRAME_W * HUD_SHIP_SCALE) + 6
local hudFont = love.graphics.newFont(16)

local function respawnShip()
    shipX, shipY = WIDTH / 2, HEIGHT - 100
    shipVelX, shipVelY = 0, 0
    invincibleRemaining = INVINCIBLE_DURATION
    flickerTimer = 0
    shipVisible = true
end

local function playerHit()
    if invincibleRemaining > 0 or lives <= 0 then
        return
    end

    spawnExplosion(shipX, shipY, playerExplosionImage)
    lives = lives - 1

    if lives > 0 then
        respawnShip()
    else
        music:stop()
        changeState("gameover", score, killCount)
    end
end

function playing.enter()
    shipX, shipY = WIDTH / 2, HEIGHT - 100
    shipVelX, shipVelY = 0, 0
    shipFrameIndex = 1
    shipFrameTimer = 0
    bullets = {}
    fireCooldownRemaining = 0
    enemies = {}
    spawnTimer = SPAWN_INTERVAL
    explosions = {}
    particles = {}
    enemyBullets = {}
    lives = START_LIVES
    invincibleRemaining = 0
    flickerTimer = 0
    shipVisible = true
    totalElapsedTime = 0
    positionHistory = {}
    killCount = 0
    score = 0
    structures = {}
    structureSpawnTimer = STRUCTURE_SPAWN_MIN_INTERVAL
    music:play()
end

-- Accelerate `value` toward `target` at `rate` per second, without
-- overshooting -- used for both the accelerate-toward-input-direction
-- and decelerate-toward-zero-when-idle cases below.
local function approach(value, target, rate, dt)
    if value < target then
        return math.min(value + rate * dt, target)
    elseif value > target then
        return math.max(value - rate * dt, target)
    end
    return value
end

-- playing.update(dt) is split into focused functions below rather than
-- one giant body -- beyond readability, LuaJIT (what LOVE actually runs,
-- unlike the luac5.4 used for local syntax checks) caps a single function
-- at 60 upvalues, and one function touching this many systems blew past
-- that limit.

local function updateBackground(dt)
    bgOffset = (bgOffset + BG_SCROLL_SPEED * dt) % bgHeight

    for _, star in ipairs(stars) do
        star.y = star.y + star.speed * dt
        if star.y > HEIGHT then
            star.y = 0
            star.x = love.math.random(0, WIDTH)
        end
        star.twinklePhase = star.twinklePhase + star.twinkleSpeed * dt
    end
end

local function updateStructures(dt)
    structureSpawnTimer = structureSpawnTimer - dt
    if structureSpawnTimer <= 0 then
        spawnStructure()
        structureSpawnTimer = love.math.random() *
            (STRUCTURE_SPAWN_MAX_INTERVAL - STRUCTURE_SPAWN_MIN_INTERVAL) + STRUCTURE_SPAWN_MIN_INTERVAL
    end

    for i = #structures, 1, -1 do
        local structure = structures[i]
        structure.y = structure.y + BG_SCROLL_SPEED * dt
        if structure.y > HEIGHT then
            table.remove(structures, i)
        end
    end
end

local function updateShip(dt)
    shipFrameTimer = shipFrameTimer + dt
    if shipFrameTimer >= SHIP_FRAME_DURATION then
        shipFrameTimer = shipFrameTimer - SHIP_FRAME_DURATION
        shipFrameIndex = shipFrameIndex % #shipQuads + 1
    end

    local dx, dy = 0, 0
    if love.keyboard.isDown("left") or love.keyboard.isDown("a") then dx = dx - 1 end
    if love.keyboard.isDown("right") or love.keyboard.isDown("d") then dx = dx + 1 end
    if love.keyboard.isDown("up") or love.keyboard.isDown("w") then dy = dy - 1 end
    if love.keyboard.isDown("down") or love.keyboard.isDown("s") then dy = dy + 1 end
    if dx ~= 0 and dy ~= 0 then
        local length = math.sqrt(dx * dx + dy * dy)
        dx, dy = dx / length, dy / length
    end

    -- Accelerate toward full speed in the held direction, or decelerate
    -- toward zero when nothing's held -- this is what gives the ship
    -- weight/momentum instead of snapping instantly to full speed and
    -- stopping dead the moment a key is released.
    local targetVelX, targetVelY = dx * SHIP_MAX_SPEED, dy * SHIP_MAX_SPEED
    local rateX = (dx == 0) and SHIP_DECELERATION or SHIP_ACCELERATION
    local rateY = (dy == 0) and SHIP_DECELERATION or SHIP_ACCELERATION
    shipVelX = approach(shipVelX, targetVelX, rateX, dt)
    shipVelY = approach(shipVelY, targetVelY, rateY, dt)

    shipX = shipX + shipVelX * dt
    shipY = shipY + shipVelY * dt

    local halfW = (SHIP_FRAME_W * SHIP_SCALE) / 2
    local halfH = (SHIP_FRAME_H * SHIP_SCALE) / 2
    shipX = math.max(halfW, math.min(WIDTH - halfW, shipX))
    shipY = math.max(halfH, math.min(HEIGHT - halfH, shipY))

    fireCooldownRemaining = math.max(0, fireCooldownRemaining - dt)
    if love.keyboard.isDown("space") and fireCooldownRemaining <= 0 then
        fireBullet()
        fireCooldownRemaining = FIRE_COOLDOWN
    end
end

local function updatePlayerBullets(dt)
    for i = #bullets, 1, -1 do
        local bullet = bullets[i]
        bullet.y = bullet.y - BULLET_SPEED * dt
        if bullet.y < -BULLET_H then
            table.remove(bullets, i)
        end
    end
end

local function updateEnemies(dt)
    spawnTimer = spawnTimer - dt
    if spawnTimer <= 0 then
        spawnEnemy()
        spawnTimer = SPAWN_INTERVAL
    end

    local enemyHalfH = (ENEMY_FRAME_H * ENEMY_SCALE) / 2
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        enemy.y = enemy.y + ENEMY_FALL_SPEED * dt

        -- No horizontal homing -- this type just falls straight down with
        -- a sine wiggle around its spawn X. It still lines up aimed shots
        -- via the delayed position below; an actively-homing "hunter" type
        -- is a future second enemy, not this one (see PLANNING.md).
        enemy.drift = enemy.drift + ENEMY_DRIFT_FREQUENCY * dt
        enemy.x = enemy.baseX + math.sin(enemy.drift) * ENEMY_DRIFT_AMPLITUDE

        enemy.frameTimer = enemy.frameTimer + dt
        if enemy.frameTimer >= ENEMY_FRAME_DURATION then
            enemy.frameTimer = enemy.frameTimer - ENEMY_FRAME_DURATION
            enemy.frameIndex = enemy.frameIndex % #enemyQuads + 1
        end

        enemy.fireTimer = enemy.fireTimer - dt
        if enemy.fireTimer <= 0 then
            enemyFireBullet(enemy)
            enemy.fireTimer = love.math.random() * (ENEMY_FIRE_MAX_INTERVAL - ENEMY_FIRE_MIN_INTERVAL) + ENEMY_FIRE_MIN_INTERVAL
        end

        if enemy.y - enemyHalfH > HEIGHT then
            table.remove(enemies, i)
        end
    end
end

local function updateEnemyBullets(dt)
    for i = #enemyBullets, 1, -1 do
        local bullet = enemyBullets[i]
        bullet.x = bullet.x + bullet.vx * dt
        bullet.y = bullet.y + bullet.vy * dt
        -- Aimed shots can drift sideways now, not just down, so check
        -- every edge rather than just the bottom.
        if bullet.y > HEIGHT + ENEMY_BULLET_H or bullet.y < -ENEMY_BULLET_H
            or bullet.x < -ENEMY_BULLET_W or bullet.x > WIDTH + ENEMY_BULLET_W then
            table.remove(enemyBullets, i)
        end
    end
end

local function updateInvincibility(dt)
    invincibleRemaining = math.max(0, invincibleRemaining - dt)
    if invincibleRemaining > 0 then
        flickerTimer = flickerTimer + dt
        if flickerTimer >= INVINCIBLE_FLICKER_INTERVAL then
            flickerTimer = flickerTimer - INVINCIBLE_FLICKER_INTERVAL
            shipVisible = not shipVisible
        end
    else
        shipVisible = true
    end
end

local function updateCollisions()
    local enemyHalfW = (ENEMY_FRAME_W * ENEMY_SCALE) / 2
    local enemyHalfH = (ENEMY_FRAME_H * ENEMY_SCALE) / 2
    local shipHalfW = (SHIP_FRAME_W * SHIP_SCALE) / 2
    local shipHalfH = (SHIP_FRAME_H * SHIP_SCALE) / 2
    local enemyBulletHalfW, enemyBulletHalfH = ENEMY_BULLET_W / 2, ENEMY_BULLET_H / 2

    -- Enemy bullets vs. player.
    for i = #enemyBullets, 1, -1 do
        local bullet = enemyBullets[i]
        local overlapX = math.abs(bullet.x - shipX) < (enemyBulletHalfW + shipHalfW)
        local overlapY = math.abs(bullet.y - shipY) < (enemyBulletHalfH + shipHalfH)
        if overlapX and overlapY then
            table.remove(enemyBullets, i)
            playerHit()
        end
    end

    -- Enemies ramming the player directly.
    for i = #enemies, 1, -1 do
        local enemy = enemies[i]
        local overlapX = math.abs(enemy.x - shipX) < (enemyHalfW + shipHalfW)
        local overlapY = math.abs(enemy.y - shipY) < (enemyHalfH + shipHalfH)
        if overlapX and overlapY then
            spawnExplosion(enemy.x, enemy.y)
            table.remove(enemies, i)
            killCount = killCount + 1
            score = score + POINTS_PER_KILL
            playerHit()
        end
    end

    -- Player bullets vs. enemies.
    local bulletHalfW, bulletHalfH = BULLET_W / 2, BULLET_H / 2
    for bi = #bullets, 1, -1 do
        local bullet = bullets[bi]
        for ei = #enemies, 1, -1 do
            local enemy = enemies[ei]
            local overlapX = math.abs(bullet.x - enemy.x) < (bulletHalfW + enemyHalfW)
            local overlapY = math.abs(bullet.y - enemy.y) < (bulletHalfH + enemyHalfH)
            if overlapX and overlapY then
                spawnExplosion(enemy.x, enemy.y)
                table.remove(enemies, ei)
                table.remove(bullets, bi)
                killCount = killCount + 1
                score = score + POINTS_PER_KILL
                break
            end
        end
    end
end

local function updateExplosions(dt)
    for i = #explosions, 1, -1 do
        local explosion = explosions[i]
        explosion.frameTimer = explosion.frameTimer + dt
        if explosion.frameTimer >= EXPLOSION_FRAME_DURATION then
            explosion.frameTimer = explosion.frameTimer - EXPLOSION_FRAME_DURATION
            explosion.frameIndex = explosion.frameIndex + 1
            if explosion.frameIndex > EXPLOSION_FRAME_COUNT then
                table.remove(explosions, i)
            end
        end
    end
end

local function updateParticles(dt)
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.vx = p.vx - p.vx * p.drag * dt
        p.vy = p.vy - p.vy * p.drag * dt
        if p.kind == "debris" then
            p.vy = p.vy + DEBRIS_GRAVITY * dt
        end
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
end

function playing.update(dt)
    totalElapsedTime = totalElapsedTime + dt
    recordPlayerPosition()

    updateBackground(dt)
    updateStructures(dt)
    updateShip(dt)
    updatePlayerBullets(dt)
    updateEnemies(dt)
    updateEnemyBullets(dt)
    updateInvincibility(dt)
    updateCollisions()
    updateExplosions(dt)
    updateParticles(dt)
end

function playing.draw()
    -- Plain black backdrop for stage 1 -- reads cleaner against the
    -- structures/stars than the nebula image did. Later stages may bring
    -- bgImage back once there's a real per-stage background system.
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)

    love.graphics.setColor(1, 1, 1)
    for _, structure in ipairs(structures) do
        love.graphics.draw(
            structure.image, structure.x, structure.y,
            0, STRUCTURE_SCALE, STRUCTURE_SCALE
        )
    end

    for _, star in ipairs(stars) do
        local brightness = 0.5 + 0.5 * math.sin(star.twinklePhase)
        love.graphics.setColor(1, 1, 1, brightness)
        love.graphics.rectangle("fill", star.x, star.y, star.size, star.size)
    end

    love.graphics.setColor(1, 1, 1)
    local enemyDrawW = ENEMY_FRAME_W * ENEMY_SCALE
    local enemyDrawH = ENEMY_FRAME_H * ENEMY_SCALE
    for _, enemy in ipairs(enemies) do
        love.graphics.draw(
            enemyImage, enemyQuads[enemy.frameIndex],
            enemy.x - enemyDrawW / 2, enemy.y - enemyDrawH / 2,
            0, ENEMY_SCALE, ENEMY_SCALE
        )
    end

    love.graphics.setColor(1, 1, 1)
    for _, bullet in ipairs(bullets) do
        love.graphics.draw(bulletImage, bullet.x - BULLET_W / 2, bullet.y - BULLET_H / 2)
    end

    love.graphics.setColor(1, 1, 1)
    for _, bullet in ipairs(enemyBullets) do
        love.graphics.draw(enemyBulletImage, bullet.x - ENEMY_BULLET_W / 2, bullet.y - ENEMY_BULLET_H / 2)
    end

    love.graphics.setColor(1, 1, 1)
    local explosionDrawW = EXPLOSION_FRAME_W * EXPLOSION_SCALE
    local explosionDrawH = EXPLOSION_FRAME_H * EXPLOSION_SCALE
    for _, explosion in ipairs(explosions) do
        love.graphics.draw(
            explosion.image, explosionQuads[explosion.frameIndex],
            explosion.x - explosionDrawW / 2, explosion.y - explosionDrawH / 2,
            0, EXPLOSION_SCALE, EXPLOSION_SCALE
        )
    end

    for _, p in ipairs(particles) do
        local alpha = math.max(0, p.life / p.maxLife)
        love.graphics.setColor(p.color[1], p.color[2], p.color[3], alpha)
        love.graphics.rectangle("fill", p.x - p.size / 2, p.y - p.size / 2, p.size, p.size)
    end

    if shipVisible then
        love.graphics.setColor(1, 1, 1)
        local shipDrawW = SHIP_FRAME_W * SHIP_SCALE
        local shipDrawH = SHIP_FRAME_H * SHIP_SCALE
        love.graphics.draw(
            shipImage, shipQuads[shipFrameIndex],
            shipX - shipDrawW / 2, shipY - shipDrawH / 2,
            0, SHIP_SCALE, SHIP_SCALE
        )
    end

    -- HUD: score/kills top-left, lives as small ship icons top-right.
    love.graphics.setFont(hudFont)
    love.graphics.setColor(1, 1, 1)
    love.graphics.print(string.format("SCORE  %06d", score), HUD_MARGIN, HUD_MARGIN)
    love.graphics.print(string.format("KILLS  %03d", killCount), HUD_MARGIN, HUD_MARGIN + 20)

    love.graphics.setColor(1, 1, 1)
    for i = 1, lives do
        local x = WIDTH - HUD_MARGIN - i * HUD_ICON_SPACING
        love.graphics.draw(shipImage, shipQuads[1], x, HUD_MARGIN, 0, HUD_SHIP_SCALE, HUD_SHIP_SCALE)
    end
end

return playing
