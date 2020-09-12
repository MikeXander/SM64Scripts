--[[
    Author: Xander
    Date: July 2020

    Custom Curve Fit for camera movement given points with position/velocity/time.
    The points need to be found and entered manually.
    This uses the frame number of a TAS during playback.

    If only 1 point is given, it will lock the camera to that point.
    If a velocity is specified for that point, it will be used as the focus point.

    If 2 points are given on the same frame, the 2nd point needs to have
    a "duration" for how long it should take to travel between those 2 points

    Ideas:
        Custom focus (also curve fit maybe?)
        Automatic slowdown (parse points and gradually decrease speed before freeze)
        Remove savestate files
        FOV Control
        Points in separate file

    Issue (?)
        During consecutive freeze frames it attempts to save a state every frame.
        This might not be an issue since it actually takes 1 frame to write the file.
        Freeze frame can only have a start and an end point, no middle points.
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
local points = { -- Points used for VCutM demo
    point(-2250,-860,-3080, 5, 0, -20, 395),
    point(-2000, -2000, -5900, 20, 10, -40, 433),
    point(-2000, -2000, -5900, -90, -30, -40, 434),
    point(-1000, -1800, -7000, 50, 20, 10, 445),
    point(-1000, -1800, -7000, 50, -10, -20, 446),
    point(1500, -100, -7000, 40, 0, 20, 505),
    point(2500,  -800, -6900, 60, 10, 5, 530),
    point(3300, 0, -6700, 50, 0, 10, 549),
    point(3630, 100, -6000, -10, 30, -10, 560)
}

--[[ Points used for TTC Timed Jumps on Moving Bars showcase
local points = {
    point(800, -3800, 0, 80, 30, 15, 74),
    point(1500, -4500, -1750, -70, 30, -30, 159),
    point(1500, -4500, -1750, -50, -10, -70, 160),
    point(-800, -3500, -1500, 20, 50, 60, 160, 60),
    point(-563, -2914, -998, 19, 48, 25, 172),
    point(5, -2128, -1065, 17, 18, -17, 200),
    point(0, -1700, -800, 0, 10, 5, 240),
    point(0, -1700, -800, 50, 0, -20, 241),
    point(-300, -300, -1000, 10, 20, 30, 260),
    point(-1900, -200, -600, -20, 30, -5, 280),
    point(-1900, 400, -600, -10, 50, -10, 294),
    point(-1900, 400, -600, -40, 0, -10, 298),
    point(-900, 400, -2700, 100, 0, -10, 298, 60),
    point(-900, 400, -2700, 80, -30, -20, 299),
    point(300, 1500, -1700, -30, 50, 50, 345),
    point(300, 1500, -1700, 30, 50, 50, 346),
    point(-100, 3000, -1500, 0, 30, 0, 370)
}
]]

--[[
    These are sample point arrays
    They test different transition cases
]]
--[[
local points_cam_path = {
    point(1940, -4120, -880, 100, -50, 10, 74),
    point(1800, -4000, -2000, -1, -1, -1, 170),
    point(100, -1000, 500, -1, 50, -1, 260)
}
local points_freeze_freeze = {
    point(500, -5000, 250, 50, 20, 70, 136),
    point(2538, -4072, -868, -38, -48, -12, 136, 30), -- on the same frame as previous, lasts 30 frames
    point(2500, -4120, -880, -40, -50, -10, 137),
    point(1500, -4000, -1800, -1, -1, -1, 137, 30),
}
local points_path_freeze_path_freeze = {
    point(2200, -4500, -500, 0, 0, 0, 74),
    point(1940, -4120, -880, 20, -50, -10, 137),
    point(1500, -4000, -1800, -1, -1, -1, 137, 30),
    point(100, -1000, 500, -1, 50, -1, 180),
    point(100, -500, 500, -1, 50, -1, 180, 10)
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
local loadNextFile = nil

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
    if stFileHandle ~= nil then
        stFileHandle:close()
        stFileHandle = nil
    end

    if loadNextFile ~= nil then
        stFileHandle = io.open(PATH .. loadNextFile .. ".st")
        loadNextFile = nil
    end

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

function HD()
    Cam.HideHUD()
    Cam.SetLevelOfDetail(0)
end

function main()
    if current_point > num_pts - 1 then
        --Cam.RemoveCameraHack()
        return -- no more points
    end

    HD()
    frame = emu.samplecount()

    if 553 < frame and frame < 560 then
        --Cam.ApplyCameraHack(nil, 0)
        --Cam.SetFocus({3358,-240,-5948})
    end

    if save_frame[frame] then -- needs 1 frame to create file
        Cam.ApplyCameraHack(0, nil)
        savestate.savefile(PATH .. (frame + 1) .. ".st")
    end

    -- needs to be checked separately for consecutive freeze frames
    if save_frame[frame - 1] then
        if p1.frame < frame then
            current_point = current_point + 1
            recalculate()
        end
        File.ExtractSTFileWith7z(frame)
        save_frame[frame - 1] = false -- only extract once
        if iteration == 1 then
            stFileHandle = io.open(PATH .. frame .. ".st", "r+b")
        else
            loadNextFile = frame -- load this file once next points are loaded
        end
    end

    if frame < points[1].frame - 1 then
        return -- before hacked cam starts
    end

    -- move the camera position
    if iteration == -1 then
        Cam.ApplyCameraHack(0, nil) -- ensure the camera is moved
        Cam.SetCamPos(position(frame))

    elseif stFileHandle ~= nil then -- bullet time cam
        File.SetCamPosToFile(stFileHandle, position(iteration + p1.frame))
        iteration = iteration + 1
        stFileHandle:close()
        savestate.loadfile(PATH .. frame .. ".st")
        stFileHandle = io.open(PATH .. frame .. ".st", "r+b")
    end

    -- advance to next sequence
    if (iteration <= 1 and frame == p2.frame) or iteration == p2.duration then
        current_point = current_point + 1

        if current_point > num_pts - 1 then
            if stFileHandle ~= nil then
                stFileHandle:close()
            end
            print("Finished")

        else -- setup next function
            recalculate()
        end
    end
end

-- Keep the camera in 1 location
function lockPos()
    HD()
    Cam.ApplyCameraHack(0, nil)
    Cam.SetCamPos({points[1].pos[1], points[1].pos[2], points[1].pos[3]})
    if (points[1].vel[1] ~= nil) then -- use velocity as focus point
        Cam.ApplyCameraHack(nil, 0)
        Cam.SetFocus({points[1].vel[1], points[1].vel[2], points[1].vel[3]})
    end
    --memory.writefloat(0x80189FC0, 60)
    --memory.writefloat(0x8033C5A4, 60) -- fix wide FOV on U
end

if num_pts < 1 then
    print("No points entered. Hiding HUD and forcing high detail")
    emu.atinput(HD)

elseif num_pts == 1 then
    if points[1].pos[1] == points[1].vel[1] and points[1].pos[3] == points[1].vel[3] then
        -- emulation stops when it tries to do this. I dont know why
        print("Error: cannot look straight up or down")
    else
        print("Locking position to point")
        emu.atinput(lockPos)
    end

elseif num_pts > 1 then
    print(string.format("Following %d points", num_pts))
    recalculate()
    emu.atinput(main)
end
