--[[
    Naive input brute forcer
]]

local path = "D:/midlongjump.st"

local MarioAddr = 0x80339E00
local Mario = {
    X = MarioAddr + 0x3C,
    Y = MarioAddr + 0x40,
    Z = MarioAddr + 0x44,
    Action = MarioAddr + 0xC
}

local X = -128 -- [-128, 128)eZ
local Y = -127 -- (-128, 128]eZ
local restart = true

local function NextInput()
    X = X + 1
    if X == -6 then
        X = -128
        Y = Y + 1
        if Y == -6 then
            emu.speedmode("normal")
            emu.pause()
            print("Finished")
        end
    end
    savestate.loadfile(path)
end

local function tpMarioToFlag()
    local flag = {
        X = 3304,
        Y = 4293.175,
        Z = -4603
    }
    memory.writefloat(Mario.X, flag.X)
    memory.writefloat(Mario.Y, flag.Y)
    memory.writefloat(Mario.Z, flag.Z)
end

local function KoopaIsStopped()
    koopaHspd = memory.readfloat(0x8034CE30)
    return -0.1 < koopaHspd and koopaHspd < 0.1
end

local best = 999999
local function output(frame)
    local data = X..", "..Y.." -> "..frame
    if frame < best then
        print("New Best: "..data)
        best = frame
    end
    local file = io.open("output.txt", "a")
    io.output(file)
    io.write(data.."\n")
    io.close(file)
end

local TalkAction = 0x20001306
local TalkFrame = 23693 - 1
local WarpFrame = 24225
local startframe = 23684

local function main()

    frame = emu.samplecount()

    if startframe <= frame and frame < TalkFrame then
        joypad.set({X = X, Y = Y})

    elseif frame == TalkFrame and memory.readdword(Mario.Action) ~= TalkAction then
        NextInput()

    elseif frame == WarpFrame then
        tpMarioToFlag()

    elseif frame > WarpFrame and KoopaIsStopped() then
        output(frame)
        NextInput()
    end
end

--emu.speedmode("maximum")
emu.atinput(main)
