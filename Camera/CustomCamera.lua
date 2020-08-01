--[[
    Author: Xander
    Date: July 2020

    Custom Curve Fit for camera movement given points with position/velocity/time.
    The points need to be found and entered manually.
    This uses the frame number of a TAS during playback.

    If only 1 point is given, it will lock the camera to that point

    If 2 points are given on the same frame, the 2nd point needs to have
    a "duration" for how long it should take to travel between those 2 points

    ToDo:
        Custom focus (also curve fit maybe?)
]]

--[[
    Points
    x,y,z: coordinates in 3D space (y = height)
    vx,vy,vz: the velocity of the camera at that point
    f: the frame you want to arrive at the point
    d: the duration it takes to arrivate at that point (only for freeze frames)
]]

local function point(x, y, z, vx, vy, vz, f, d)
    return {
        pos = {x, y, z},
        vel = {vx, vy, vz},
        frame = f,
        duration = d
    }
end

-- Add your points here!
local points = {
    point(2200, -4500, -500, 0, 0, 0, 74),
    point(1940, -4120, -880, 20, -50, -10, 137),
    point(1500, -4000, -1800, -1, -1, -1, 137, 30),
    point(100, -1000, 500, -1, 50, -1, 180)
}

--[[
    These are sample point arrays
    They test the different transition cases
]]
--[[
local points_cam_path = {
    point(1940, -4120, -880, 100, -50, 10, 74),
    point(1800, -4000, -2000, -1, -1, -1, 170),
    point(100, -1000, 500, -1, 50, -1, 260)
}
local points_path_freeze_path = {
    point(2200, -4500, -500, 0, 0, 0, 74),
    point(1940, -4120, -880, 20, -50, -10, 137),
    point(1500, -4000, -1800, -1, -1, -1, 137, 30),
    point(100, -1000, 500, -1, 50, -1, 180)
}
local points_freeze = {
    point(1940, -4120, -880, 20, -50, -10, 137),
    point(1500, -4000, -1800, -1, -1, -1, 137, 40) -- on the same frame as previous, lasts 40 frames
}
]]

PATH = debug.getinfo(1).source:sub(2):match("(.*\\)") -- cwd of script
dofile(PATH .. "Camera.lua")
dofile(PATH .. "CurveFitter.lua")
dofile(PATH .. "STHandler.lua")

local current_point = 1
local iteration = -1
local p1 = {}
local p2 = {}
local position = nil
local stFileHandle = nil

--[[
    Parse points to find:
        the number of points
        the frames where it needs to savestate for freeze frames
]]
local num_pts = 0
local save_frame = {}
for i,p in pairs(points) do
    num_pts = num_pts + 1
    if num_pts > 1 and p.frame == points[i - 1].frame then
        save_frame[p.frame - 1] = true
    end
end

-- set the right function and flag to move the camera
local function recalculate()
    p1 = points[current_point]
    p2 = points[current_point + 1]
    print(p1.frame..": {"..p1.pos[1]..","..p1.pos[2]..","..p1.pos[3].."} -> "..p2.frame..": {"..p2.pos[1]..","..p2.pos[2]..","..p2.pos[3].."}")

    if p1.frame == p2.frame then -- freeze frame
        position = Curve.getPositionFunction(p1, p2, p2.duration)
        iteration = 1

    else -- move camera
        position = Curve.getPositionFunction(p1, p2, p2.frame - p1.frame)
        iteration = -1
    end
end

function main()
    if current_point > num_pts - 1 then
        --Cam.RemoveCameraHack()
        return -- no more points
    end

    frame = emu.samplecount()

    if save_frame[frame] then
        Cam.ApplyCameraHack(0, nil)
        savestate.savefile(PATH .. "frame.st")
        print("Saved state - frame " .. frame)
        return

    elseif save_frame[frame - 1] then -- needs 1 frame to create file
        File.ExtractSTFileWith7z(PATH .. "frame.st")
        stFileHandle = io.open(PATH .. "frame.st", "r+b")
        save_frame[frame - 1] = false -- only extract once
        if p1.frame < frame then
            current_point = current_point + 1
            recalculate()
        end

    elseif frame < points[1].frame - 1 then
        return -- before hacked cam starts
    end

    -- move the camera position
    if iteration == -1 then
        Cam.ApplyCameraHack(0, nil) -- ensure the camera is moved
        Cam.SetCamPos(position(frame))

    else -- freeze frame
        File.SetCamPosToFile(stFileHandle, position(iteration + p1.frame))
        iteration = iteration + 1
		stFileHandle:close()
        savestate.loadfile(PATH .. "frame.st")
		stFileHandle = io.open(PATH .. "frame.st", "r+b")
    end

    -- advance to next sequence
    --print(frame.." "..iteration.." "..p2.frame)
    if (iteration <= 1 and frame == p2.frame) or iteration == p2.duration then
        current_point = current_point + 1

        if current_point > num_pts - 1 then
            print("Finished")

        else -- setup next function
            recalculate()
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
    recalculate()
    emu.atinput(main)
end
