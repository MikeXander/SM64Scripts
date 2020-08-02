--[[
	Exports Mario's position (and frame number) across a specified frame window.
    This is meant to be used to get Mario's path for the visualizer.
    Only works during TAS playback.
]]

local startFrame = 74
local endFrame = 414

local mario_addr_us = 0x00B3B170
local mario_addr_jp = 0x80339E00

local mario_addr = mario_addr_us -- switch between U and J

local Mario = {
    X = mario_addr + 0x3C,
    Y = mario_addr + 0x40,
    Z = mario_addr + 0x44,
    action = mario_addr + 0xC,
    angle = mario_addr + 0x2E
}

local f = nil
local PATH = debug.getinfo(1).source:sub(2):match("(.*\\)")

local function main()
    local x = memory.readfloat(Mario.X)
    local y = memory.readfloat(Mario.Y)
    local z = memory.readfloat(Mario.Z)

    frame = emu.samplecount()
    data = string.format("[%.2f, %.2f, %.2f, %d]", x, y, z, frame)

    if frame == startFrame then
        print("Started")
        f = io.open(PATH .. "MarioPos.txt", "w")
        io.output(f)
        io.write("[\n"..data)
        print(data)

    elseif startFrame < frame and frame <= endFrame then
        io.write(",\n"..data)
        print(data)

    elseif frame == endFrame + 1 then
        io.write("\n]\n")
        io.close(f)
        print("Finished")
    end
end

emu.atinput(main)
