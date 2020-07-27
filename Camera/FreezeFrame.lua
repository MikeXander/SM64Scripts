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
    point(1800, -4000, -2000, -1, -1, -1, 10),
    point(100, -1000, 500, -1, 50, -1, 40)
}

local Cam = require "Camera"
local Curve = require "CurveFitter"

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
        position = Curve.getPositionFunction(p1, p2)
        recalculate = false
    end


    if started then
        Cam.ApplyCameraHack(0, nil) -- ensure the camera is moved
        Cam.SetCamPos(position(iteration + p1.frame))
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
