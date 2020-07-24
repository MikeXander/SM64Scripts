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
    point(1800, -4000, b-2000, -1, -1, -1, 10),
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

-- Camera --

local function ApplyCameraHack(pos, angle)
	if pos ~= nil then memory.writedword(0x00A87cf0, pos) end
	if angle ~= nil then memory.writedword(0x00A87d08, angle) end
	memory.recompilenextall()
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

-- Main --

local current_point = 1
local recalculate = false
local position = nil
local iteration = 0
local load_flag = false
local started = false

local num_pts = 0
for k,v in pairs(points) do
    num_pts = num_pts + 1
end

function main()
    if current_point > num_pts - 1 then
        return -- no more points
    end

    frame = emu.samplecount()

    if frame == FREEZE_FRAME - 3 and not started then
        savestate.savefile("./frame.st")
        print("saved state")
    elseif frame == FREEZE_FRAME - 1 and not started then
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
        ApplyCameraHack(0, nil) -- ensure the camera is moved
        SetCamPos(position(iteration + p1.frame))
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

    if load_flag then
        iteration = iteration + 1
        savestate.loadfile("./frame.st")
    end
end

if num_pts < 2 then
    print("Error: must enter at least 2 points")

elseif num_pts > 1 then
    print(string.format("Moving between %d points", num_pts))
    emu.atinput(main)
end
