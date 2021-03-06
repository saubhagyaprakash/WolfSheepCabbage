local Class = require 'lib/middleclass'
local Manager = Class('Manager')
local Level = require 'level'

local currentLevelIndex = 1
local currentLevel = nil
local filenames = nil

function Manager:initialize()
    filenames = love.filesystem.getDirectoryItems('level')
    table.sort(filenames)

    self:loadLevel(currentLevelIndex)
end

function Manager:loadLevel()
    local s = "./level/"..filenames[currentLevelIndex]:sub(0, -5)
    package.loaded[s] = nil
    local l = require(s)
    currentLevel = Level(l.name, l.data)
end

function Manager:nextLevel()
    if currentLevelIndex == #filenames then return end
    currentLevelIndex = currentLevelIndex + 1
    self:loadLevel()
end

function Manager:prevLevel()
    if currentLevelIndex == 1 then return end
    currentLevelIndex = (currentLevelIndex - 1)
    self:loadLevel()
end

function Manager:keypressed(key)
    if key and currentLevel.progress == "COMPLETE" then
        self:nextLevel()
        return
    elseif key == '[' then
        self:prevLevel()
    elseif key == ']' then
        self:nextLevel()
    end

    currentLevel:keypressed(key)
end

function Manager:update(dt)
    currentLevel:update(dt)
end

function Manager:draw()
    currentLevel:draw()
end

return Manager()