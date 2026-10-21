local title = {}

local WIDTH, HEIGHT = love.graphics.getWidth(), love.graphics.getHeight()

local titleFont = love.graphics.newFont(56)
local subtitleFont = love.graphics.newFont(14)
local creditFont = love.graphics.newFont(12)
local promptFont = love.graphics.newFont(20)

-- Spinning ship display, under the title.
local SHIP_FRAME_W, SHIP_FRAME_H = 16, 24
local SHIP_COLS, SHIP_ROWS = 5, 2
local SHIP_SCALE = 2
local SHIP_FRAME_DURATION = 0.15
local SHIP_Y = 270

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

local music = love.audio.newSource("assets/title.mp3", "stream")
music:setLooping(true)

-- A lightweight drifting starfield for atmosphere -- not the gameplay
-- scrolling background (that's its own thing, later), just title-screen
-- ambiance using plain rectangles rather than sprite assets.
local NUM_STARS = 80
local stars = {}
for i = 1, NUM_STARS do
    stars[i] = {
        x = love.math.random(0, WIDTH),
        y = love.math.random(0, HEIGHT),
        speed = love.math.random(10, 40),
        size = love.math.random(1, 2),
    }
end

local blinkTimer = 0
local showPrompt = true
local BLINK_INTERVAL = 0.5

function title.enter()
    blinkTimer = 0
    showPrompt = true
    music:play()
end

function title.update(dt)
    for _, star in ipairs(stars) do
        star.y = star.y + star.speed * dt
        if star.y > HEIGHT then
            star.y = 0
            star.x = love.math.random(0, WIDTH)
        end
    end

    blinkTimer = blinkTimer + dt
    if blinkTimer >= BLINK_INTERVAL then
        blinkTimer = 0
        showPrompt = not showPrompt
    end

    shipFrameTimer = shipFrameTimer + dt
    if shipFrameTimer >= SHIP_FRAME_DURATION then
        shipFrameTimer = shipFrameTimer - SHIP_FRAME_DURATION
        shipFrameIndex = shipFrameIndex % #shipQuads + 1
    end
end

function title.draw()
    love.graphics.setColor(1, 1, 1)
    for _, star in ipairs(stars) do
        love.graphics.rectangle("fill", star.x, star.y, star.size, star.size)
    end

    -- Simple drop-shadow effect: dim orange offset behind bright cyan.
    love.graphics.setFont(titleFont)
    love.graphics.setColor(1, 0.55, 0.1)
    love.graphics.printf("STARHAWK", 3, 163, WIDTH, "center")
    love.graphics.setColor(0.1, 0.8, 1)
    love.graphics.printf("STARHAWK", 0, 160, WIDTH, "center")

    love.graphics.setFont(subtitleFont)
    love.graphics.setColor(0.6, 0.6, 0.6)
    love.graphics.printf("VENGEANCE FROM ABOVE", 0, 230, WIDTH, "center")

    love.graphics.setColor(1, 1, 1)
    local shipDrawW = SHIP_FRAME_W * SHIP_SCALE
    love.graphics.draw(
        shipImage, shipQuads[shipFrameIndex],
        WIDTH / 2 - shipDrawW / 2, SHIP_Y,
        0, SHIP_SCALE, SHIP_SCALE
    )

    if showPrompt then
        love.graphics.setFont(promptFont)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("PRESS ENTER TO START", 0, 370, WIDTH, "center")
    end

    -- Credit, tucked in the corner as a footer rather than stacked into
    -- the main title/tagline/ship/prompt flow -- keeps that stack clean.
    love.graphics.setFont(creditFont)
    love.graphics.setColor(0.4, 0.4, 0.4)
    love.graphics.printf("CREATED BY JEREMY STEVENS", 0, HEIGHT - 24, WIDTH - 12, "right")

    love.graphics.setColor(1, 1, 1)
end

function title.keypressed(key)
    if key == "return" then
        music:stop()
        changeState("playing")
    end
end

return title
