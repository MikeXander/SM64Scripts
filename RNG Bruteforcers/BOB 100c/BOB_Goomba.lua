--[[

    Author: Xander
    Date: July 2020

    4 Plush <3
    Uses JP RAM Addresses

    Purpose: to find different starting RNG values with specific goomba movement
    to give more possibilities for the coin RNG later in the level.
    Plush was right, the goomba movement was very rare... 2/65114 = 1/32557

    Special Thanks: Alexpalix, IsaacA

]]

local RNG = require "RNG"
RNG.setRange(RNG.max, 43690)

-- constants
local mario_addr_us = 0x00B3B170
local mario_addr = 0x80339E00
local Mario = {
    x = 0x80339E3C,--mario_addr + 0x3C,
    y = mario_addr + 0x40,
    z = mario_addr + 0x44,
    action = mario_addr + 0xC,
    angle = mario_addr + 0x2E
}
local stars_jp = 0x80339EAA

local path = "D:/starselect.st"
local restart = true
local complete = false

--local goal_pos = {"-3033.5700683594", "295.888671875", "5802.732421875"}
local goal_pos = {x="-3033.57", y="295.89", z="5802.73"}
local bounce_frame = 23882

-- hacky way to check if floats match...
local function pos_matches()
    x = string.format("%.2f", memory.readfloat(Mario.x))
    y = string.format("%.2f", memory.readfloat(Mario.y))
    z = string.format("%.2f", memory.readfloat(Mario.z))
    return x == goal_pos.x and y == goal_pos.y and z == goal_pos.z
end

local function output(frame)
    print(RNG.value)
    local file = io.open("output.txt", "a")
    io.output(file)
    io.write(RNG.value.."\n")
    io.close(file)
end

--[[

    Checks to see if Mario bounces off a goomba near the start of the koopa race

]]
function goomba_bounce()
    if complete then return end

    frame = emu.samplecount()

    if (restart) then
        restart = false
        RNG.advance()

        if RNG.isComplete() then
            print ("All values tested")
            complete = true
        end

        savestate.loadfile(path)

    elseif (frame == 23585) then
        memory.writeword(RNG.address, RNG.value)
        memory.writeword(stars_jp, RNG.value)

    elseif (frame == bounce_frame) then
        if pos_matches() then output(frame) end
        restart = true
    end

    frame = frame + 1
end

emu.atinput(goomba_bounce)
