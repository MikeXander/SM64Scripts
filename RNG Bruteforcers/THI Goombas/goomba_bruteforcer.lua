--[[

    Author: Xander
    Date: June 2020

    This was used to get good movement for the 3 starting goombas in THI 100c.
    With the test inputs, at best Mario would hit 2/3 goombas so the data was
    then sorted by distance to the 3rd goomba. A handfull of values tied here.
    The resulting list of values allow for different coin RNG later in the level.

]]

local RNG = require "RNG"
RNG.setRange(0, RNG.max)
RNG.setCustomValueList("./Viable RNG.txt")

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
local big_goomb_graphic = 0x8019008C
local gp_action = 0x008008A9
local squished_action = 102
local end_condition_frame = 118

local start_frame = 5 -- set this to be the frame that's loaded on the savestate
local frame = 0
local restart = true

local distances = {{rng = -1, dist = -1}}

function main()

    if (restart) then
        restart = false
        frame = start_frame

        RNG.advance()

        if RNG.isComplete() then
            print ("All values tested")
            frame = end_condition_frame + 1 -- prevent subsequent tests
            --table.sort(distances, function(a, b) return a.dist < b.dist end)
            --print(distances)
        end

        savestate.loadfile(path)

    elseif (frame == start_frame + 1) then
        memory.writeword(RNG.address, RNG.value)
        memory.writeword(stars, RNG.value)

    elseif (frame == end_condition_frame) then

        local num_squished = 0
        local min_dist = 9999999 -- arbitrary

        for slot=0,240 do
            obj = object_addr + offset * slot
            if (memory.readdword(obj + graphicsOffset) == big_goomb_graphic) then -- identifyer
                if (memory.readdword(obj + actionOffset) == squished_action) then
                    num_squished = num_squished + 1
                else
                    min_dist = min(obj_dist(slot), min_dist) -- dont look at the ones already squished
                end
            end
        end

        --table.insert(distances, {rng = RNG.value, dist = min_dist})
        --print("RNG: "..RNG.value.." Dist: "..min_dist)

        --[[
        if (memory.readdword(mario_action_addr) ~= gp_action) then num_squished = 0 end
        if (num_squished == 3) then
            print(RNG.value.." !!!")
        elseif (num_squished == 2) then
            print("2: "..RNG.value)
        end]]

        restart = true
    end

    frame = frame + 1
end

function obj_dist(slot)
    local obj = object_addr + offset * slot
    return dist(
        memory.readfloat(Mario.x),
        memory.readfloat(Mario.z),
        memory.readfloat(obj + 0xA0), -- X
        memory.readfloat(obj + 0xA8) -- Z
    )
end

function dist(x1, y1, x2, y2)
	dx = x2-x1
	dy = y2-y1
	return math.sqrt(dx*dx + dy*dy)
end

function min(a, b)
    if a < b then
        return a
    else
        return b
    end
end

emu.atinput(main)
