local gameover = {}

function gameover.enter()
end

function gameover.update(dt)
end

function gameover.draw()
    local width = love.graphics.getWidth()
    love.graphics.printf("GAME OVER", 0, 250, width, "center")
    love.graphics.printf("PRESS ENTER FOR TITLE", 0, 300, width, "center")
end

function gameover.keypressed(key)
    if key == "return" then
        changeState("title")
    end
end

return gameover
