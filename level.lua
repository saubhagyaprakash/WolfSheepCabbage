local Class = require 'lib/middleclass'
local Level = Class('Level')

local Player = require 'player'
local Wolf = require 'wolf'
local Sheep = require 'sheep'
local Cabbage = require 'cabbage'
local overlay = require 'overlay'

local MAX_LEVEL_SIZE = 16

local TILE_IMAGE = love.graphics.newImage('asset/tile.png')
local TILES = {
    WATER = {
        love.graphics.newQuad(0, 0, 16, 16, TILE_IMAGE:getDimensions()),
        love.graphics.newQuad(16, 0, 16, 16, TILE_IMAGE:getDimensions()),
        love.graphics.newQuad(0, 16, 16, 16, TILE_IMAGE:getDimensions()),
        love.graphics.newQuad(16, 16, 16, 16, TILE_IMAGE:getDimensions()),
    },
    HBRIDGE = love.graphics.newQuad(16, 64, 16, 16, TILE_IMAGE:getDimensions()),
    VBRIDGE = love.graphics.newQuad(0, 64, 16, 16, TILE_IMAGE:getDimensions()),
    GROUND = {
        love.graphics.newQuad(0, 32, 16, 16, TILE_IMAGE:getDimensions()),
        love.graphics.newQuad(0, 32, 16, 16, TILE_IMAGE:getDimensions()),
        love.graphics.newQuad(0, 32, 16, 16, TILE_IMAGE:getDimensions()),
        love.graphics.newQuad(0, 32, 16, 16, TILE_IMAGE:getDimensions()),
        love.graphics.newQuad(16, 32, 16, 16, TILE_IMAGE:getDimensions()),
        love.graphics.newQuad(0, 48, 16, 16, TILE_IMAGE:getDimensions()),
        love.graphics.newQuad(16, 48, 16, 16, TILE_IMAGE:getDimensions()),
    }
}

local OVERLAYTEXT = {
    INCOMPLETE = {
        main = "",
        sub  = ""
    },
    CABBAGE_LOST = {
        main = "CABBAGE LOST",
        sub  = "PRESS R TO RESTART\nPRESS Z TO UNDO"
    },
    SHEEP_LOST = {
        main = "SHEEP LOST",
        sub  = "PRESS R TO RESTART\nPRESS Z TO UNDO"
    },
    COMPLETE = {
        main = "YOU WIN",
        sub  = "PRESS ANY KEY TO START NEXT LEVEL"
    }
}

local SOUNDS = {
    LOST = love.audio.newSource("asset/lost.wav", "static"),
    CLEAR = love.audio.newSource("asset/clear.wav", "static"),
}

local FONT = love.graphics.newFont('asset/monogram.ttf', 64)

function Level:initialize(name, data)
    self.height = #data
    self.width = #data[1]
    self.tiles = {}

    self.objects = {
        Wolf = {},
        Sheep = {},
        Cabbage = {},
        Player = {}
    }

    self.goals = {
        Wolf = {},
        Sheep = {},
        Cabbage = {}
    }

    self.history = {}

    self.progress = "INCOMPLETE"

    self.pushCount = 0
    self.moveCount = 0

    self.events = {}

    self.waterCanvas = love.graphics.newCanvas(16*MAX_LEVEL_SIZE, 16*MAX_LEVEL_SIZE)
    self.groundCanvas = love.graphics.newCanvas(16*self.width, 16*self.height)

    self.levelNameText = love.graphics.newText(FONT)
    self.levelNameText:set(name)
    self.movesText = love.graphics.newText(FONT)

    for r=1, self.height do
        self.tiles[r] = {}
        for c=1, self.width do
            local s = data[r]:sub(c, c)
            local t = nil

            if s == '.' then
                t = "WATER"
            elseif s == '=' then
                t = "HBRIDGE"
            elseif s == '|' then
                t = "VBRIDGE"
            elseif s == '-' then
                t = "GROUND"
            elseif s == 'W' then
                t = "GROUND"
                table.insert(self.objects.Wolf, Wolf(self, r, c))
            elseif s == 'w' then
                t = "GROUND"
                table.insert(self.goals.Wolf, {r=r, c=c})
            elseif s == 'S' then
                t = "GROUND"
                table.insert(self.objects.Sheep, Sheep(self, r, c))
            elseif s == 's' then
                t = "GROUND"
                table.insert(self.goals.Sheep, {r=r, c=c})
            elseif s == 'C' then
                t = "GROUND"
                table.insert(self.objects.Cabbage, Cabbage(self, r, c))
            elseif s == 'c' then
                t = "GROUND"
                table.insert(self.goals.Cabbage, {r=r, c=c})
            elseif s == 'P' then
                t = "GROUND"
                table.insert(self.objects.Player, Player(self, r, c))
            end

            self.tiles[r][c] = t
        end
    end
end

function Level:getTileAt(r, c)
    if 1 <= r and r <= self.height and 1 <= c and c <= self.width then
        return self.tiles[r][c]
    end

    return "WATER"
end

function Level:getObjectAt(r, c)
    for type, _ in pairs(self.objects) do
        for i, o in ipairs(self.objects[type]) do
            if o.r == r and o.c == c then
                return o
            end
        end
    end

    return nil
end

function Level:removeObjectAt(r, c)
    for type, _ in pairs(self.objects) do
        for i, o in ipairs(self.objects[type]) do
            if o.r == r and o.c == c then
                return table.remove(self.objects[type], i)
            end
        end
    end

    return nil
end

function Level:pushState()
    local s = {
        Wolf = {},
        Sheep = {},
        Cabbage = {},
        Player = {}
    }

     for type, _ in pairs(self.objects) do
        for i, o in ipairs(self.objects[type]) do
            table.insert(s[type], {r=o.r, c=o.c})
        end
    end

    table.insert(self.history, s)
end

function Level:popState()
    if #self.history == 0 then return end

    local s = table.remove(self.history, #self.history)
    local objs = {
        Wolf = {},
        Sheep = {},
        Cabbage = {},
        Player = {}
    }

    for type, _ in pairs(s) do
        local cls = nil
        if     type == "Player"  then cls = Player
        elseif type == "Wolf"    then cls = Wolf
        elseif type == "Sheep"   then cls = Sheep
        elseif type == "Cabbage" then cls = Cabbage
        end

        for i, o in ipairs(s[type]) do
            table.insert(objs[type], cls(self, o.r, o.c))
        end
    end

    self.objects = objs
    self:updateProgess()
end

function Level:controlPlayer(dir)
    if self.progress ~= "INCOMPLETE" then return end

    self:pushState()

    local player = self.objects.Player[1]
    if player:push(dir) then
        self.pushCount = self.pushCount + 1
    end

    if player:move(dir) then
        self.moveCount = self.moveCount + 1
    end

    local prevPlayer = self.history[#self.history].Player[1]
    if prevPlayer.r == player.r and prevPlayer.c == player.c then
        self:popState()
    end
end

function Level:updateProgess()
    if #self.objects.Sheep ~= #self.goals.Sheep then
        self.progress = "SHEEP_LOST"
        SOUNDS["LOST"]:play()
        return
    end

    if #self.objects.Cabbage ~= #self.goals.Cabbage then
        self.progress = "CABBAGE_LOST"
        SOUNDS["LOST"]:play()
        return
    end

    local complete = true
    for type, _ in pairs(self.goals) do
        for _, pos in ipairs(self.goals[type]) do
            local o = self:getObjectAt(pos.r, pos.c)
            if o == nil then
                complete = false
            elseif o.class.name ~= type then
                complete = false
            end
        end
    end

    if complete then
        SOUNDS["CLEAR"]:play()
        self.progress = "COMPLETE"
    else
        self.progress = "INCOMPLETE"
    end
end

function Level:keypressed(key)
    if key == 'w' or key == 'up' then
        table.insert(self.events, "UP")
    elseif key == 's' or key == 'down' then
        table.insert(self.events, "DOWN")
    elseif key == 'a' or key == 'left' then
        table.insert(self.events, "LEFT")
    elseif key == 'd' or key == 'right' then
        table.insert(self.events, "RIGHT")
    elseif key == 'r' then
        table.insert(self.events, "RESET")
    elseif key == 'z' then
        table.insert(self.events, "UNDO")
    end
end

function Level:update(dt)
    for _, e in ipairs(self.events) do
        if e == "RIGHT" then
            self:controlPlayer(1)
        elseif e == "DOWN" then
            self:controlPlayer(2)
        elseif e == "LEFT" then
            self:controlPlayer(3)
        elseif e == "UP" then
            self:controlPlayer(4)
        elseif e == "RESET" then
            while #self.history > 0 do self:popState() end
        elseif e == "UNDO" then
            self:popState()
        end
    end

    self.events = {}

    for type, _ in pairs(self.objects) do
        for i, o in ipairs(self.objects[type]) do
            o:update(dt)
        end
    end

    overlay:setText(OVERLAYTEXT[self.progress].main, OVERLAYTEXT[self.progress].sub)
    overlay:update(dt)

    if self.progress == "INCOMPLETE" then self:updateProgess() end
end

function Level:draw()
    love.graphics.setCanvas(self.waterCanvas)
    for r=1, MAX_LEVEL_SIZE do
        for c=1, MAX_LEVEL_SIZE do
            love.graphics.draw(TILE_IMAGE, TILES.WATER[r%2*2+c%2+1], c*16-16, r*16-16)
        end
    end

    love.graphics.setCanvas(self.groundCanvas)
    for r=1, self.height do
        for c=1, self.width do
            local t = self.tiles[r][c]
            local q = nil

            if t == "WATER" then
                -- pass
            elseif t == "GROUND" then
                love.graphics.draw(TILE_IMAGE, TILES[t][r*c*r%7+1], c*16-16, r*16-16)
            else
                love.graphics.draw(TILE_IMAGE, TILES[t], c*16-16, r*16-16)
            end
        end
    end

    for type, _ in pairs(self.objects) do
        for i, o in ipairs(self.objects[type]) do
            o:draw()
        end
    end

    for type, _ in pairs(self.goals) do
        for i, g in ipairs(self.goals[type]) do
            local o = self:getObjectAt(g.r, g.c)

            if o ~= nil and o.class.name == type then --skip
            elseif type == "Sheep"   then Sheep  .static.drawGoal(g.r, g.c)
            elseif type == "Wolf"    then Wolf   .static.drawGoal(g.r, g.c)
            elseif type == "Cabbage" then Cabbage.static.drawGoal(g.r, g.c)
            end
        end
    end

    love.graphics.setCanvas()

    love.graphics.draw(self.waterCanvas, 0, 0, 0, 2, 2)
    love.graphics.draw(
        self.groundCanvas,
        math.floor(MAX_LEVEL_SIZE/2-self.width/2)*32,
        math.floor(MAX_LEVEL_SIZE/2-self.height/2)*32,
        0, 2, 2
    )

    self.movesText:set("MOVES: "..tostring(#self.history))
    love.graphics.draw(self.levelNameText, 32, 512+8)
    love.graphics.draw(self.movesText, 32, 512+64)

    overlay:draw()
end

return Level
