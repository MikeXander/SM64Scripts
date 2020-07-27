--[[
    Author: Xander
    Date: July 2020

    Custom Curve Fit for camera movement given points with position/velocity/time.
    The points need to be found and entered manually.
    This uses the frame number of a TAS during playback.

    If only 1 point is given, it will lock the camera to that point

    ToDo:
        Custom focus (also curve fit maybe?)
]]

local function point(x, y, z, vx, vy, vz, f)
    return {
        pos = {x, y, z},
        vel = {vx, vy, vz},
        frame = f
    }
end

-- Add your points here!
local points = {
    point(1940, -4120, -880, 100, -50, 10, 74),
    point(1800, -4000, -2000, -1, -1, -1, 170),
    point(100, -1000, 500, -1, 50, -1, 260)
}

local Cam = require "Camera"
local Curve = require "CurveFitter"

local current_point = 1
local recalculate = true
local position = nil

local num_pts = 0
for k,v in pairs(points) do
    num_pts = num_pts + 1
end

-- follow the curve created between multiple points
function followPath()
    if current_point > num_pts - 1 then
        return -- no more points
    end

    -- get new position function with next intended point
    if recalculate then
        p1 = points[current_point]
        p2 = points[current_point + 1]
        print("{"..p1.pos[1]..","..p1.pos[2]..","..p1.pos[3].."} -> {"..p2.pos[1]..","..p2.pos[2]..","..p2.pos[3].."}")
        position = Curve.getPositionFunction(p1, p2)
        recalculate = false
    end

    Cam.ApplyCameraHack(0, nil) -- ensure the camera is moved
    frame = emu.samplecount()
    Cam.SetCamPos(position(frame))

    -- advance to next sequence
    if frame == p2.frame then
        recalculate = true
        current_point = current_point + 1
        if current_point > num_pts - 1 then
            print("Path complete")
        end
    end
end

-- Keep the camera in 1 location
function lockPos()
    Cam.ApplyCameraHack(0, nil)
    Cam.SetCamPos({points[1].pos[1], points[1].pos[2], points[1].pos[3]})
end

if num_pts < 1 then
    print("Error: must enter at least 1 point")

elseif num_pts == 1 then
    print("Locking position to point")
    emu.atinput(lockPos)

elseif num_pts > 1 then
    print(string.format("Following %d points", num_pts))
    emu.atinput(followPath)
end
