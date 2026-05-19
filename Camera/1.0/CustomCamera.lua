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

    Ideas (ToDo):
        FOV Control
        Points in separate file
        Allow freeze frames to have middle points (not just a start and an end point)
]]

--[[
    Points
    x,y,z: coordinates in 3D space (y = height)
    vx,vy,vz: the velocity of the camera at that point
    f: the frame you want to arrive at the point
    d: the duration it takes to arrivate at that point (only for freeze frames)
]]

local function point(x, y, z, vx, vy, vz, f, d)
	-- point(x, y, z, d)
	if vx ~= nil and vy == nil and vz == nil and f == nil then
		d = vx
		vx = 0
		vy = 0
		vz = 0
	end
    return {
        pos = {x, y, z},
        vel = {vx, vy, vz},
        frame = f,
        duration = d
    }
end

-- Add your points here!
-- The following points are used with the HMC Swimming Beast TAS
local points = {
    point(-7308.4, 5792.7,  9694.2, 0,0,0, 29),
    point(-9380.9, 5015.5,  7751.3, 0,0,0,  65),
    point(-9830.5, 4976.1,  1060.8, 0,0,0, 200),
    point(-7250.6, 2568.0, -1022.3, 0,0,0, 245),
    point(-6626.2, 2458.7,  -888.9, 0,0,0, 275)
}

-- Note: you can give the focus points velocities as well
-- Ex: point(-6574.4, 1608.8, 1517.3, 10, -10, 20, nil, 200-65)
local focus_points = {
    point(-7152.0, 3150.0, 7181.0, 29), -- first point duration = starting frame
    point(-7135.4, 2285.5, 7164.4, 65-29), -- next point duration = how long to reach next point
    point(-6574.4, 1608.8, 1517.3, 200-65),
    point(-5786.3, 1558.1, 0722.3, 130+63)
}
-- {start, stop, real_frames_per_ingame_frame} (inclusive numbers)
local SLOWMO_RANGES = { -- you can list multiple
    {263,275,10}
}

PATH = debug.getinfo(1).source:sub(2):match("(.*\\)") -- cwd of script
dofile(PATH .. "Camera.lua")
dofile(PATH .. "CurveFitter.lua")
dofile(PATH .. "STHandler.lua")

local current_point = 1
local current_focus_point = 1
local iteration = -1
local total_frame_count = 0 -- increase by 1 per iteration or frame (tick count)
local focus_recalculate_iteration = -1 -- the frame to recalculate focus stuff
local p1 = {}
local p2 = {}
local position = nil
local focus_position = nil
local stFileHandle = nil
local SLOWMODE = {}
local REAL_FRAMES_PER_FRAME = 2
local file_delete_stack = {}
local file_delete_stack_len = 0

-- Parse points to find the frames where it needs to savestate for freeze frames
local num_pts = #points
local save_frame = {}
for i, p in pairs(points) do
    if points[i - 1] and p.frame == points[i - 1].frame then
        save_frame[p.frame - 1] = true
    end
end

-- Parse the slow-mo frame ranges and set it to save accordingly
for k, range in pairs(SLOWMO_RANGES) do
	for f = range[1], range[2] do
		SLOWMODE[f] = range[3]
		save_frame[f - 1] = true
	end
end

-- set the right function and flag to move the camera
local function recalculate(focus)
	if focus then
		focus_recalculate_iteration = total_frame_count + focus_points[current_focus_point+1].duration
		focus_points[current_focus_point].frame = total_frame_count -- used in curve fitter
		focus_position = Curve.getPositionFunction(
			focus_points[current_focus_point],
			focus_points[current_focus_point + 1],
			focus_points[current_focus_point + 1].duration
		)
        local fp1 = focus_points[current_focus_point]
        local fp2 = focus_points[current_focus_point + 1]
        print("F: {"..fp1.pos[1]..","..fp1.pos[2]..","..fp1.pos[3].."} -> {"..fp2.pos[1]..","..fp2.pos[2]..","..fp2.pos[3].."} ("..fp2.duration..")")
		return
	end
	
    if stFileHandle ~= nil then
        stFileHandle:close()
        stFileHandle = nil
		file_delete_stack[file_delete_stack_len + 1] = PATH..p1.frame..".st"
		file_delete_stack_len = file_delete_stack_len + 2 -- 1f buffer
    end

    p1 = points[current_point]
    p2 = points[current_point + 1]
    print("C "..p1.frame..": {"..p1.pos[1]..","..p1.pos[2]..","..p1.pos[3].."} -> "..p2.frame..": {"..p2.pos[1]..","..p2.pos[2]..","..p2.pos[3].."}")

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
	if file_delete_stack_len then -- clean-up files
		if file_delete_stack[file_delete_stack_len] then
			os.remove(file_delete_stack[file_delete_stack_len])
		end
		file_delete_stack_len = file_delete_stack_len - 1
	end
	
    if current_point > num_pts - 1 then -- no more points
        --Cam.RemoveCameraHack()
        return
    end

    HD()
    frame = emu.samplecount()
	REAL_FRAMES_PER_FRAME = SLOWMODE[frame] or 0

	--[[print(string.format(
		"f%d: iter:%d/%d save:%d slow:%d file:%d",
		frame, iteration, REAL_FRAMES_PER_FRAME,
		save_frame[frame] and 1 or 0,
		SLOWMODE[frame] or 0,
		stFileHandle and 1 or 0
	))]]

	-- needs 1 frame to create file
    if save_frame[frame] and (
		iteration < 0 or
		(p2.duration and iteration == p2.duration-1) or
		(SLOWMODE[frame+1] and iteration == REAL_FRAMES_PER_FRAME-1)
	) then
        -- ensure camera is hacked, always hack cam, hack focus accordingly
        Cam.ApplyCameraHack(0, current_focus_point < #focus_points and 0 or nil)
        savestate.savefile(PATH .. (frame + 1) .. ".st")
    end

    -- needs to be checked separately for consecutive freeze frames
    if save_frame[frame - 1] then
        File.ExtractSTFileWithLibDeflate(frame)
        save_frame[frame - 1] = false -- only extract once
        stFileHandle = io.open(PATH .. frame .. ".st", "r+b")
		if SLOWMODE[frame] then
			iteration = 0
		end
    end

    if frame < points[1].frame - 1 then -- before hacked cam starts
        return -- side effect is that focus points must occur after cam points
    end
	
	if #focus_points > 0 and frame == focus_points[1].duration then -- duration of first = start frame
		total_frame_count = frame
		recalculate(true)
	end

    -- surprisingly it doesn't matter if it's loading a file or not... ?
    if #focus_points and focus_position then -- edit focus in RAM
        Cam.ApplyCameraHack(nil, 0) -- ensure focus is moved
        Cam.SetFocus(focus_position(total_frame_count))
    end

    -- move the camera position
    if iteration == -1 then
        Cam.ApplyCameraHack(0, nil) -- ensure the camera is moved
		local t = frame
		-- on the last frame of a slowmo frame, iter = -1 + no file loaded
		if SLOWMODE[frame] then
			t = frame + (REAL_FRAMES_PER_FRAME - 1) / REAL_FRAMES_PER_FRAME
		end
        Cam.SetCamPos(position(t))

    elseif stFileHandle ~= nil then -- bullet time cam
		local t = 0
		if SLOWMODE[frame] then
			t = frame + iteration / REAL_FRAMES_PER_FRAME
		else -- p2.duration ~= nil
			t = p1.frame + iteration
		end
        File.SetCamPosToFile(stFileHandle, position(t))
        iteration = iteration + 1
        stFileHandle:close()
        savestate.loadfile(PATH .. frame .. ".st")
        stFileHandle = io.open(PATH .. frame .. ".st", "r+b")
    end

    -- advance to next sequence
    if (iteration <= 1 and frame == p2.frame - 1) or iteration == p2.duration then
        current_point = current_point + 1

        if current_point > num_pts - 1 then
            if stFileHandle ~= nil then
                stFileHandle:close()
            end
            print("Finished Cam Movement")

        else -- setup next function
            recalculate()
        end
	elseif SLOWMODE[frame] and iteration == REAL_FRAMES_PER_FRAME - 1 then
		iteration = -1
		stFileHandle:close()
		stFileHandle = nil
		file_delete_stack[file_delete_stack_len + 1] = PATH..frame..".st"
		file_delete_stack_len = file_delete_stack_len + 2 -- 1f buffer
    end
	
	-- advance to next sequence for focus points
	total_frame_count = total_frame_count + 1
	if #focus_points and total_frame_count == focus_recalculate_iteration then
		current_focus_point = current_focus_point + 1
		
		if current_focus_point == #focus_points then
			focus_recalculate_iteration = -1
			focus_position = nil
			print("Finished Focus Movement")
		else
			recalculate(true)
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
