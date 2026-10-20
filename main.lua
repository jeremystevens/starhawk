local states = {
    title = require("states.title"),
    playing = require("states.playing"),
    gameover = require("states.gameover"),
}

local currentState = nil

-- Global by design: each state module calls this to request a transition
-- without needing a reference back to main.lua.
function changeState(name)
    currentState = states[name]
    if currentState.enter then
        currentState.enter()
    end
end

function love.load()
    love.window.setTitle("Starhawk")
    changeState("title")
end

function love.update(dt)
    if currentState.update then
        currentState.update(dt)
    end
end

function love.draw()
    if currentState.draw then
        currentState.draw()
    end
end

function love.keypressed(key)
    if currentState.keypressed then
        currentState.keypressed(key)
    end
end
