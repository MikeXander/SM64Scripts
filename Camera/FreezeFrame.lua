--[[
    Author: Xander
    Date: July 2020

    === WARNING ===
    This loads the savestate frame, and then frame advances to the cam hacked frame
    Which means it rapidly switches cameras every frame.

    Start point frame doesnt matter:
    This travels between each point for (p2.frame - p1.frame) frames

    ToDo:
        Modify camera position inside frame.st before loading
        Break into modules (Cam.lua, CurveFit.lua)
]]

BASE = debug.getinfo(1).source:sub(2):match("(.*\\)")

dofile(BASE .. "Helper.lua")

local function point(x, y, z, vx, vy, vz, f)
    return {
        pos = {x, y, z},
        vel = {vx, vy, vz},
        frame = f
    }
end

local FREEZE_FRAME = 136

-- Add your points here!
local points = {
    point(1940, -4120, -880, 100, -50, 10, 0),
    point(1800, -4000, -2000, -1, -1, -1, 10),
    point(100, -1000, 500, -1, 50, -1, 40)
}

-- Math
-- Source: https://stackoverflow.com/questions/4362498/curve-fitting-points-in-3d-space

local Tf = 0

local a = {}
local function fa(X0, V0, Xf, Vf)
    return (6 * (Tf*Tf*V0 + Tf*Tf*Vf + 2*Tf*X0 - 2*Tf*Xf)) / (Tf*Tf*Tf*Tf)
end

local b = {}
local function fb(X0, V0, Xf, Vf)
    return (2 * (-2*Tf*Tf*Tf*V0 - Tf*Tf*Tf*Vf - 3*Tf*Tf*X0 + 3*Tf*Tf*Xf)) / (Tf*Tf*Tf*Tf)
end

local function x(a, b, t, X0, Xf)
    return (3*b*t*t*Tf + a*t*t*t*Tf - 3*b*t*Tf*Tf - a*t*Tf*Tf*Tf - 6*t*X0 + 6*Tf*X0 + 6*t*Xf) / (6*Tf)
end

local function getPositionFunction(p1, p2)
    Tf = p2.frame - p1.frame
    for i = 1,3 do
        a[i] = fa(p1.pos[i], p1.vel[i], p2.pos[i], p2.vel[i])
        b[i] = fb(p1.pos[i], p1.vel[i], p2.pos[i], p2.vel[i])
    end
    return function(frame)
        t = frame - p1.frame
        return {
            x(a[1], b[1], t, p1.pos[1], p2.pos[1]),
            x(a[2], b[2], t, p1.pos[2], p2.pos[2]),
            x(a[3], b[3], t, p1.pos[3], p2.pos[3])
        }
    end
end

local function FlipTable(t)
	local t2 = {}
	for i = #t, 1, -1 do
		t2[#t2 + 1] = t[i]
	end
	return t2
end

-- File functions --

-- You have to do open with r+b mode (or wb) for the filehandle
local function OverWriteByteArrayToFile(bytes, address, fileHandle)
	fileHandle:seek("set", address)
	for _, v in pairs(bytes) do
		fileHandle:write(string.char(v))
	end
end

local function OverWriteByteArrayToFileLittleEndian(bytes, address, fileHandle)
	bytes = FlipTable(bytes)
	fileHandle:seek("set", address)
	for _, v in pairs(bytes) do
		fileHandle:write(string.char(v))
	end
end

-- Camera --

local function ApplyCameraHack(pos, angle)
	if pos ~= nil then memory.writedword(0x00A87cf0, pos) end
	if angle ~= nil then memory.writedword(0x00A87d08, angle) end
	memory.recompilenextall()
end

-- stFileHandle has to be in r+b mode
local function ApplyCameraHackInFile(stFileHandle, pos, angle)
	if not stFileHandle then print("Error, st file handle is nil") return end

	if pos ~= nil then
		stFileHandle:seek("set", 0x287cf0 + 0x1b0)
	end
	
	if angle ~= nil then
		stFileHandle:seek("set", 0x287d08 + 0x1b0)
	end
end

local function WriteRenderCamera(camstruct)
	local pointeraddr = 0x00A06BDC
	local addr = memory.readdword(pointeraddr)
	if addr > 0x80000000 and addr < 0x80300000 then
		addr = addr - 0x80000000 + 0x80001C
		if camstruct.x ~= nil then memory.writefloat(addr, camstruct.x) end
		if camstruct.y ~= nil then memory.writefloat(addr + 4, camstruct.y) end
		if camstruct.z ~= nil then memory.writefloat(addr + 8, camstruct.z) end
		if camstruct.xfocus ~= nil then memory.writefloat(addr + 12, camstruct.xfocus) end
		if camstruct.yfocus ~= nil then memory.writefloat(addr + 16, camstruct.yfocus) end
		if camstruct.zfocus ~= nil then memory.writefloat(addr + 20, camstruct.zfocus) end
	end
end

-- stFileHandle has to be in r+b mode
local function WriteRenderCameraInFile(camstruct, stFileHandle)
	local addr = memory.readdword(0x00A06BDC)
	local tempWriteAddr = addr + 0x80001c - 0x80000000
	local originalTempAddrValue = memory.readfloat(tempWriteAddr)
	local fileWriteBaseOffset = 0x1b0
	local floatVarArray
	local writeContent = {
		camstruct.x,
		camstruct.y,
		camstruct.z,
		camstruct.xfocus,
		camstruct.yfocus,
		camstruct.zfocus,
	}
	
	for i, v in pairs(writeContent) do
		if v then
			-- hacky float to bytes conversion
			memory.writefloat(tempWriteAddr, v)
			floatVarArray = Helper.GetByteArray(memory.readdword(tempWriteAddr), 4, false, false)
			OverWriteByteArrayToFileLittleEndian(floatVarArray, fileWriteBaseOffset + addr - 0x80000000 + 0x1c + ((i - 1) * 4), stFileHandle)
		end
	end
	
	-- restore original value
	memory.writefloat(tempWriteAddr, originalTempAddrValue)
end

local function SetCamPos(pos)
    WriteRenderCamera({
        x = pos[1],
        y = pos[2],
        z = pos[3],
        xfocus = nil,
        yfocus = nil,
        zfocus = nil
    })
end

local function SetCamPosToFile(stFileHandle, pos)
    WriteRenderCameraInFile({
        x = pos[1],
        y = pos[2],
        z = pos[3],
        xfocus = nil,
        yfocus = nil,
        zfocus = nil
    }, stFileHandle)
end

-- 7z functions --

-- It replaces the st file with the uncompressed one
local function ExtractSTFileWith7z()
	-- extract it into dir "extracted"
	os.execute("\"\"" .. BASE .. "7z.exe\" e \"" .. BASE .. "frame.st\" -o\"" .. BASE .. "extracted/\" -aoa -y > nul\"")
	os.remove(BASE .. "frame.st")
	os.rename(BASE .. "extracted\\frame", BASE .. "frame.st")
	os.execute("\"RD /S /Q \"" .. BASE .. "extracted\" \"")
end

-- Main --

local current_point = 1
local recalculate = false
local position = nil
local iteration = 0
local load_flag = false
local started = false
local stFileHandle = nil

local num_pts = 0
for k,v in pairs(points) do
    num_pts = num_pts + 1
end

function main()
    if current_point > num_pts - 1 then
		if stFileHandle then stFileHandle:close() stFileHandle = nil end
        return -- no more points
    end

    frame = emu.samplecount()

    if frame == FREEZE_FRAME - 3 and not started then
		if stFileHandle then stFileHandle:close() stFileHandle = nil end
		ApplyCameraHack(0, nil)
        savestate.savefile(BASE .. "frame.st")
        print("saved state")
    elseif frame == FREEZE_FRAME - 1 and not started then
		ExtractSTFileWith7z(BASE .. "frame.st")
		stFileHandle = io.open(BASE .. "frame.st", "r+b")
        recalculate = true
        started = true
    end

    -- get new position function with next intended point
    if recalculate then
        p1 = points[current_point]
        p2 = points[current_point + 1]
        print("{"..p1.pos[1]..","..p1.pos[2]..","..p1.pos[3].."} -> {"..p2.pos[1]..","..p2.pos[2]..","..p2.pos[3].."}")
        position = getPositionFunction(p1, p2)
        recalculate = false
    end


    if started then
        -- ApplyCameraHackInFile(stFileHandle, 0, nil) -- ensure the camera is moved
        SetCamPosToFile(stFileHandle, position(iteration + p1.frame))
        load_flag = not load_flag
    end

    -- switch to next point
    if started and iteration == p2.frame - p1.frame then
        recalculate = true
        current_point = current_point + 1
        if current_point > num_pts - 1 then
            print("Path complete")
            started = false
        end
        iteration = 0
    end

    if started then
        iteration = iteration + 1
		stFileHandle:close()
		stFileHandle = nil
        savestate.loadfile(BASE .. "frame.st")
		stFileHandle = io.open(BASE .. "frame.st", "r+b")
    end
end

if num_pts < 2 then
    print("Error: must enter at least 2 points")

elseif num_pts > 1 then
    print(string.format("Moving between %d points", num_pts))
    emu.atinput(main)
end
