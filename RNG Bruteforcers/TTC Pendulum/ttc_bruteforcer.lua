--[[

    Author: Xander
    Date: July 2020

]]

local RNG = require "RNG"
RNG.setRange(0, RNG.max)
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

local bar_slot = 22
local bar = object_addr + offset * bar_slot
local bar_x = 0x803404A8 --bar + 0xA0
local bar_xspd = bar + 0xAC
local extended_x = -1141.24
local retracted_x = -1319
local bar_check_frame = 370

local pendulum_slot = 10
local pendulum = object_addr + offset * pendulum_slot
local pendulum_angle = 0x8033E880 --pendulum + 0xF8
local goal_angle = 6300
local passed_angle = false
local tj_frame = 0

--[[

    The triple jump is only possible when the pendulum passes a certain angle.
    This notes that frame, and then gets data on a bar's position and speed.

]]
function bar_data()

    if (restart) then
        restart = false
        frame = start_frame
        passed_angle = false
        tj_frame = 0

        RNG.advance()

        if RNG.isComplete() then
            print ("All values tested")
            frame = bar_check_frame + 1
            io.close(file)
        end

        savestate.loadfile(path)

    elseif (frame == start_frame + 1) then
        memory.writeword(RNG.address, RNG.value)
        memory.writeword(stars, RNG.value)

    elseif (frame == bar_check_frame) then
        local x = memory.readfloat(bar_x)
        local spd = memory.readfloat(bar_xspd)

        local data = "{rng:"..RNG.value..",tj:"..tj_frame..",x:"..x..",spd:"..spd.."}"
        print(data)

        local file = io.open("output.txt", "a")
        io.output(file)
        io.write(data.."\n")
        io.close(file)

        restart = true

    elseif (passed_angle == false and frame > 280 and memory.readfloat(pendulum_angle) >= goal_angle) then
        passed_angle = true
        tj_frame = frame
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

emu.atinput(bar_data)
