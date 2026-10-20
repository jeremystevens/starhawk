local playing = {}

function playing.enter()
end

function playing.update(dt)
end

function playing.draw()
    local width = love.graphics.getWidth()
    love.graphics.printf("PLAYING", 0, 280, width, "center")
end

function playing.keypressed(key)
    -- Temporary debug trigger until phase 6 adds real collision/death --
    -- lets us confirm the playing -> game over transition works.
    if key == "escape" then
        changeState("gameover")
    end
end

return playing
