local title = {}

local WIDTH, HEIGHT = love.graphics.getWidth(), love.graphics.getHeight()

local titleFont = love.graphics.newFont(56)
local subtitleFont = love.graphics.newFont(14)
local promptFont = love.graphics.newFont(20)

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

    if showPrompt then
        love.graphics.setFont(promptFont)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("PRESS ENTER TO START", 0, 340, WIDTH, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

function title.keypressed(key)
    if key == "return" then
        changeState("playing")
    end
end

return title
