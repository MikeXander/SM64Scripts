--[[

    Author: Xander
    Date: July 2020

    This was used to get an ideal scenario for the Timed Jumps on Moving Bars TAS.
    After narrowing down the possibilities, RNG values needed to be tested manually
    to check if the final RNG call for the bar at the end was good or not.

]]

local RNG = require "RNG"
RNG.setRange(1160, RNG.max)
RNG.setCustomValueList("D:/ttc_rng_r1.txt")
-- 27655 had interesting conveyor movement

-- constants
local mario_addr = 0x00B3B170
local Mario = {
    x = mario_addr + 0x3C,
    y = mario_addr + 0x40,
    z = mario_addr + 0x44,
    action = mario_addr + 0xC,
    angle = mario_addr + 0x2E
}
local stars = 0x00B3B21A
local object_addr = 0xB3D488
local offset = 0x260
local graphicsOffset = 0x14
local actionOffset = 0x14C

-- use case specific constants
local path = "D:/lua.st" -- star select savestate to load
local wk_action = 0x03000886

local start_frame = 70 -- set this to be the frame that's loaded on the savestate
local frame = 0
local restart = true

-- hardcoded because something strange was happening with the relative addrs
local pendulum_angle = 0x8033E880 --pendulum + 0xF8
local pendulum_accel = 0x8033E888 --pendulum + 0x100
local goal_angle = 6300

local function output(frame)
    local accel = memory.readfloat(pendulum_accel)
    local data = "{\"rng\":"..RNG.value..",\"tj\":"..frame..",\"accel\":"..accel.."},"
    print(data)

    local file = io.open("output.txt", "a")
    io.output(file)
    io.write(data.."\n")
    io.close(file)

    restart = true
end

--[[

    The triple jump is only possible when the pendulum passes a certain angle.
    This records that frame as well as the speed data for the pendulum.

]]
function tj_frame()

    if (restart) then
        restart = false
        frame = start_frame

        RNG.advance()

        if RNG.isComplete() then
            print ("All values tested")
            goal_angle = 1000000 -- unreachable
        end

        savestate.loadfile(path)

    elseif (frame == start_frame + 1) then
        memory.writeword(RNG.address, RNG.value)
        memory.writeword(stars, RNG.value)

    elseif (280 < frame and frame < 390 and memory.readfloat(pendulum_angle) >= goal_angle) then
        output(frame)

    elseif (frame >= 390) then
        output(400) -- really separate these as outliers (but still include them)

    end

    frame = frame + 1
end

--[[

    If Mario makes it up to the cog, and wall kicks within a certain angle,
    this will output information about a pendulum which will be used next.

]]
function wk_angle_search()

    if (restart) then
        restart = false
        frame = start_frame

        RNG.advance()

        if RNG.isComplete() then
            print ("All values tested")
            frame = 251
        end

        savestate.loadfile(path)

    elseif (frame == start_frame + 1) then
        memory.writeword(RNG.address, RNG.value)
        memory.writeword(stars, RNG.value)

    elseif (frame == 183) then -- conveyor check
        if (memory.readdword(Mario.action) ~= wk_action) then
            restart = true
        end

    elseif (frame == 250) then -- cog check
        local angle = memory.readword(Mario.angle)
        if (memory.readdword(Mario.action) == wk_action) and (2000 < angle) and (angle < 8000) then

            local slot = 10 -- always loads the same
            local pendulum = object_addr + offset * slot
            local accel = memory.readfloat(pendulum + 0x100) -- 13 slow, 42 fast
            local speed = memory.readfloat(pendulum + 0xFC) -- positive speed moves "right"
            local p_angle = memory.readfloat(pendulum + 0xF8)
            local waitingtimer = memory.readbyte(pendulum + 0x104) -- if frozen: how long until it moves

            -- Estimate: pendulum will likely need to be moving left, not having past angle 0 yet
            local str = "{"
            str = str .. "rng=" .. RNG.value .. ","
            str = str .. "wk_angle=" .. angle .. ","
            str = str .. "speed=" .. speed .. ","
            str = str .. "accel=" .. accel .. ","
            str = str .. "angle=" .. p_angle .. "}"
            print(str)

        end

        restart = true
    end

    frame = frame + 1
end

emu.atinput(tj_frame)
