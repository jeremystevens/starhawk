-- Standalone dev-only preview: animates a ship sprite sheet large on
-- screen so it can be visually reviewed before committing. Not part of
-- the real game. Run with: love tools/preview

local IMAGE_PATH = "assets/ship.png"
local FRAME_W, FRAME_H = 16, 24
local COLS, ROWS = 5, 2
local SCALE = 10
local FRAME_DURATION = 0.15 -- seconds per frame

local sheet
local quads = {}
local frameIndex = 1
local frameTimer = 0

function love.load()
    love.window.setTitle("Ship Preview")
    sheet = love.graphics.newImage(IMAGE_PATH)
    sheet:setFilter("nearest", "nearest")

    for row = 0, ROWS - 1 do
        for col = 0, COLS - 1 do
            table.insert(quads, love.graphics.newQuad(
                col * FRAME_W, row * FRAME_H, FRAME_W, FRAME_H,
                sheet:getDimensions()
            ))
        end
    end
end

function love.update(dt)
    frameTimer = frameTimer + dt
    if frameTimer >= FRAME_DURATION then
        frameTimer = frameTimer - FRAME_DURATION
        frameIndex = frameIndex % #quads + 1
    end
end

function love.draw()
    local width, height = love.graphics.getDimensions()
    local drawW, drawH = FRAME_W * SCALE, FRAME_H * SCALE
    love.graphics.draw(
        sheet, quads[frameIndex],
        width / 2 - drawW / 2, height / 2 - drawH / 2,
        0, SCALE, SCALE
    )

    love.graphics.printf(
        "SHIP PREVIEW (" .. IMAGE_PATH .. ") -- frame "
            .. frameIndex .. "/" .. #quads,
        0, 20, width, "center"
    )
    love.graphics.printf("ESC to quit", 0, height - 40, width, "center")
end

function love.keypressed(key)
    if key == "escape" then
        love.event.quit()
    end
end
