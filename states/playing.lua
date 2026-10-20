local playing = {}

local WIDTH, HEIGHT = love.graphics.getWidth(), love.graphics.getHeight()

-- Background: resized/mirrored from the user-provided back.png (see
-- tools/generate_background.py history) -- native 800px width, seamless
-- vertical loop via mirroring.
local BG_SCROLL_SPEED = 40
local bgImage = love.graphics.newImage("assets/bg_space.png")
bgImage:setFilter("linear", "linear")
local _, bgHeight = bgImage:getDimensions()
local bgOffset = 0

-- Drifting, twinkling star layer -- same technique as the title screen's
-- starfield, but faster (closer) with a twinkle so it reads as a distinct
-- layer in front of the nebula backdrop.
local NUM_STARS = 60
local stars = {}
for i = 1, NUM_STARS do
    stars[i] = {
        x = love.math.random(0, WIDTH),
        y = love.math.random(0, HEIGHT),
        speed = love.math.random(80, 160),
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

function playing.enter()
    shipX, shipY = WIDTH / 2, HEIGHT - 100
    shipVelX, shipVelY = 0, 0
    shipFrameIndex = 1
    shipFrameTimer = 0
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

function playing.update(dt)
    bgOffset = (bgOffset + BG_SCROLL_SPEED * dt) % bgHeight

    for _, star in ipairs(stars) do
        star.y = star.y + star.speed * dt
        if star.y > HEIGHT then
            star.y = 0
            star.x = love.math.random(0, WIDTH)
        end
        star.twinklePhase = star.twinklePhase + star.twinkleSpeed * dt
    end

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
end

function playing.draw()
    local y = bgOffset - bgHeight
    while y < HEIGHT do
        love.graphics.setColor(1, 1, 1)
        love.graphics.draw(bgImage, 0, y)
        y = y + bgHeight
    end

    for _, star in ipairs(stars) do
        local brightness = 0.5 + 0.5 * math.sin(star.twinklePhase)
        love.graphics.setColor(1, 1, 1, brightness)
        love.graphics.rectangle("fill", star.x, star.y, star.size, star.size)
    end

    love.graphics.setColor(1, 1, 1)
    local shipDrawW = SHIP_FRAME_W * SHIP_SCALE
    local shipDrawH = SHIP_FRAME_H * SHIP_SCALE
    love.graphics.draw(
        shipImage, shipQuads[shipFrameIndex],
        shipX - shipDrawW / 2, shipY - shipDrawH / 2,
        0, SHIP_SCALE, SHIP_SCALE
    )
end

function playing.keypressed(key)
    -- Temporary debug trigger until phase 6 adds real collision/death --
    -- lets us confirm the playing -> game over transition works.
    if key == "escape" then
        changeState("gameover")
    end
end

return playing
