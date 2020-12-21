--[[

    Author: Xander
    Date: December 2020

    Makes sure that the movement kills the goomba
    Then checks how far away the coin is

    Note: provided savestates are on the ghost race v2 hack

]]

local RNG = require "RNG"
RNG.setRange(RNG.max, 0)
--RNG.setCustomValueList("./Viable RNG.txt")
--known to hit goomba: 13892

-- constants
local mario_addr = 0x00B3B170
local Mario = {
    x = mario_addr + 0x3C,
    y = mario_addr + 0x40,
    z = mario_addr + 0x44
}
local stars = 0x00B3B21A
local object_addr = 0xB3D488
local offset = 0x260
local graphicsOffset = 0x14
local actionOffset = 0x14C
local mario_action_addr = 0x8033B17C --0x00BC40DC

-- use case specific constants
local path = "D:/lua.st" -- star select savestate to load
local goomba_graphic = 0x8018CEF0
local hit_action = 101
local goomba_dist_frame = 574
local goomba_hit_frame = 581

local coin_graphic = 0x800F8AA4
local coin_dist_frame = 682

local start_frame = 44 -- set this to be the frame that's loaded on the savestate
local frame = 0
local restart = true

local distances = {{rng = -1, goomba_dist = -1, hit = false, coin_dist = -1}}
local current_info = {rng = -1, goomba_dist = -1, hit = false, coin_dist = -1}

local function output(info)
    local data = ""
    if info.hit == true then
        data = "{\"rng\":"..info.rng..",\"gdist\":"..info.goomba_dist..",\"hit\":1,\"cdist\":"..info.coin_dist.."},"
    else
        data = "{\"rng\":"..info.rng..",\"gdist\":"..info.goomba_dist..",\"hit\":0,\"cdist\":"..info.coin_dist.."},"
    end

    print(data)
    table.insert(distances, info)
    current_info = {rng = -1, goomba_dist = -1, hit = false, coin_dist = -1}

    local file = io.open("output.txt", "a")
    io.output(file)
    io.write(data.."\n")
    io.close(file)
    restart = true
end

function main()

    if (restart) then
        restart = false
        frame = start_frame

        RNG.advance()

        if RNG.isComplete() then
            print ("All values tested")
            frame = coin_dist_frame + 1 -- prevent subsequent tests
            --table.sort(distances, function(a, b) return a.dist < b.dist end)
            --print(distances)
        end

        savestate.loadfile(path)

    elseif (frame == start_frame + 1) then
        memory.writeword(RNG.address, RNG.value)
        memory.writeword(stars, RNG.value)

    elseif (memory.readdword(mario_action_addr) == 0x00020338) then -- shocked
        restart = true

    elseif (frame == goomba_dist_frame) then

        local min_dist = 9999999 -- arbitrary

        for slot=0,240 do
            obj = object_addr + offset * slot
            if (memory.readdword(obj + graphicsOffset) == goomba_graphic) then -- identifyer
                min_dist = min(obj_dist(slot), min_dist)
            end
        end

        current_info.rng = RNG.value
        current_info.goomba_dist = min_dist

    elseif (frame == goomba_hit_frame) then
        hit = false
        for slot=0,240 do
            obj = object_addr + offset * slot
            if (memory.readdword(obj + graphicsOffset) == goomba_graphic) then -- identifyer
                if (memory.readdword(obj + actionOffset) == hit_action) then
                    hit = true
                    break
                end
            end
        end
        current_info.hit = hit
        if not hit then
            output(current_info)
        end

    elseif (frame == coin_dist_frame) then
        local min_dist = 9999999 -- arbitrary

        for slot=0,240 do
            obj = object_addr + offset * slot
            if (memory.readdword(obj + graphicsOffset) == coin_graphic) then -- identifyer
                min_dist = min(obj_dist(slot), min_dist)
            end
        end

        current_info.coin_dist = min_dist
        output(current_info)

    end

    frame = frame + 1
end

function obj_dist(slot)
    local obj = object_addr + offset * slot
    return dist(
        memory.readfloat(Mario.x),
        memory.readfloat(Mario.y),
        memory.readfloat(Mario.z),
        memory.readfloat(obj + 0xA0), -- X
        memory.readfloat(obj + 0xA4), -- Y
        memory.readfloat(obj + 0xA8) -- Z
    )
end

function dist(x1, y1, z1, x2, y2, z2)
	dx = x2-x1
	dy = y2-y1
    dz = z2-z1
	return math.sqrt(dx*dx + dy*dy + dz*dz)
end

function min(a, b)
    if a < b then
        return a
    else
        return b
    end
end

emu.atinput(main)
