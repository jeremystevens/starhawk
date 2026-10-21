local gameover = {}

local WIDTH, HEIGHT = love.graphics.getWidth(), love.graphics.getHeight()

local titleFont = love.graphics.newFont(48)
local statsFont = love.graphics.newFont(22)
local promptFont = love.graphics.newFont(20)

-- A short (~11s) one-shot sting, not a loop -- plays once on entry, unlike
-- title.mp3/stage1.mp3 which loop. "static" (not "stream") since it's
-- short and only ever one copy plays at a time.
local music = love.audio.newSource("assets/gameover.mp3", "static")

-- No dedicated UI sound yet -- reuses the player bullet sfx, pitched down,
-- as a stand-in "confirm" blip rather than leaving the transition silent.
local confirmSound = love.audio.newSource("assets/norm_bullet.wav", "static")
confirmSound:setPitch(0.8)

-- A lightweight drifting starfield, same technique as the title screen.
local NUM_STARS = 60
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

local finalScore = 0
local finalKills = 0

function gameover.enter(score, kills)
    finalScore = score or 0
    finalKills = kills or 0
    blinkTimer = 0
    showPrompt = true
    music:stop()  -- restart from the top even if a prior run's sting was cut off
    music:play()
end

function gameover.update(dt)
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

function gameover.draw()
    love.graphics.setColor(0, 0, 0)
    love.graphics.rectangle("fill", 0, 0, WIDTH, HEIGHT)

    love.graphics.setColor(1, 1, 1)
    for _, star in ipairs(stars) do
        love.graphics.rectangle("fill", star.x, star.y, star.size, star.size)
    end

    -- Same drop-shadow treatment as the title screen's logo, but red/orange
    -- instead of cyan -- reads as "you lost" rather than reusing the
    -- title's palette.
    love.graphics.setFont(titleFont)
    love.graphics.setColor(0.5, 0.05, 0.05)
    love.graphics.printf("GAME OVER", 3, 183, WIDTH, "center")
    love.graphics.setColor(1, 0.25, 0.2)
    love.graphics.printf("GAME OVER", 0, 180, WIDTH, "center")

    love.graphics.setFont(statsFont)
    love.graphics.setColor(0.85, 0.85, 0.85)
    love.graphics.printf(string.format("FINAL SCORE  %06d", finalScore), 0, 260, WIDTH, "center")
    love.graphics.printf(string.format("KILLS  %03d", finalKills), 0, 292, WIDTH, "center")

    if showPrompt then
        love.graphics.setFont(promptFont)
        love.graphics.setColor(1, 1, 1)
        love.graphics.printf("PRESS ENTER FOR TITLE", 0, 370, WIDTH, "center")
    end

    love.graphics.setColor(1, 1, 1)
end

function gameover.keypressed(key)
    if key == "return" then
        music:stop()
        love.audio.play(confirmSound:clone())
        changeState("title")
    end
end

return gameover
