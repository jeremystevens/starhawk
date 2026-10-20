local title = {}

function title.enter()
end

function title.update(dt)
end

function title.draw()
    local width = love.graphics.getWidth()
    love.graphics.printf("STARHAWK", 0, 250, width, "center")
    love.graphics.printf("PRESS ENTER TO START", 0, 300, width, "center")
end

function title.keypressed(key)
    if key == "return" then
        changeState("playing")
    end
end

return title
