--[[
    Xander (Dec 2022)
    This is a script to help manipulate the camera and focus point.
    It will print out the location of the cam/focus each time it moves.
    Valid keys (case-sensitive):
        https://docs.google.com/document/d/1SWd-oAFBKsGmwUs0qGiOrk3zfX9wYHhi3x5aKPQS_o0/edit#bookmark=id.jcojkq7g066s

]]

local controls = {
    ["toggle"] = {hotkeys = {"enter"}, toggle = true}, -- toggle both at once
    ["toggle cam"] = {hotkeys = {"O"}, toggle = true},
    ["toggle focus"] = {hotkeys = {"P"}, toggle = true},

    ["cam left"] = {hotkeys = {"A"}},
    ["cam right"] = {hotkeys = {"D"}},
    ["cam up"] = {hotkeys = {"space"}},
    ["cam down"] = {hotkeys = {"shift"}},
	["cam back"] = {hotkeys = {"S"}},
	["cam forward"] = {hotkeys = {"W"}},
    
    ["focus left"] = {hotkeys = {"left"}},
    ["focus right"] = {hotkeys = {"right"}},
    ["focus up"] = {hotkeys = {"up"}},
    ["focus down"] = {hotkeys = {"down"}},
    ["focus closer"] = {hotkeys = {"numpad0"}},
    ["focus further"] = {hotkeys = {"numpad2"}}
}

PATH = debug.getinfo(1).source:sub(2):match("(.*\\)") -- cwd of script
dofile(PATH .. "Camera.lua")

local CAM_SPEED = 10 -- units per frame
local FOCUS_SPEED = 10 -- degrees per frame

-- vector math

local sqrt = math.sqrt
local atan = math.atan
local acos = math.acos
local sin = math.sin
local cos = math.cos


local function str(v)
    return string.format("(%.1f, %.1f, %.1f)", v[1], v[2], v[3])
end

print(str(Cam.GetCamPos()))

-- +y = "up" (swap y and z)
local function swap_vector(v)
    return {v[1], v[3], v[2]}
end

local function cross(u, v)
    u = swap_vector(u)
    v = swap_vector(v)
    local product = {u[2]*v[3]-u[3]*v[2], u[3]*v[1]-u[1]*v[3], u[1]*v[2]-u[2]*v[1]}
    return swap_vector(product) -- swap back
end

local function mag(v)
    return sqrt(v[1]*v[1] + v[2]*v[2] + v[3]*v[3])
end

local function scale(v, s)
    return {s*v[1], s*v[2], s*v[3]}
end

local function dir(v) 
    local m = mag(v)
    if m == 0 then
        return v
    end
    return scale(v, 1/m)
end

local function difference(u, v) -- (u-v)
    return {u[1]-v[1], u[2]-v[2], u[3]-v[3]}
end

local function add(u, v)
    local res = {u[1]+v[1], u[2]+v[2], u[3]+v[3]}
    --print(string.format("%s + %s = %s", str(u), str(v), str(res)))
    return res
end

-- {x, y, z} -> {r, phi, theta}
local function spherical_coords(pos)
    local m = mag(pos)
    if m == 0 then
        return {0, 0, 0}
    end
    return {m, atan(pos[2], pos[1]), acos(pos[3] / m)}
end

-- {r, phi, theta} -> {x, y, z}
local function cartesian_coords(pos)
    return scale({
        sin(pos[3]) * cos(pos[2]),
        sin(pos[2]) * sin(pos[3]),
        cos(pos[2])
    }, pos[1])
end

local function rotate_up(pos, phi)
    pos = spherical_coords(swap_vector(pos))
    pos[2] = pos[2] + phi
    return swap_vector(cartesian_coords(pos))
end

local function rotate_cw(pos, theta)
    pos = spherical_coords(swap_vector(pos))
    pos[3] = pos[3] + theta
    return swap_vector(cartesian_coords(pos))
end

-- functions

local cam_hacked = false
local focus_hacked = false

local function fix_camera_hack()
    Cam.RemoveCameraHack()
    if cam_hacked then
        Cam.ApplyCameraHack(0, nil)
    end
    if focus_hacked then
        Cam.ApplyCameraHack(nil, 0)
    end
end

controls["toggle"].run = function()
    cam_hacked = not cam_hacked
    focus_hacked = not focus_hacked
    fix_camera_hack()
    print("Cam " .. (cam_hacked and "enabled" or "disabled") .. " Focus " .. (focus_hacked and "enabled" or "disabled"))
end

controls["toggle cam"].run = function()
    cam_hacked = not cam_hacked
    fix_camera_hack()
    print("Cam " .. (cam_hacked and "enabled" or "disabled"))
end

controls["toggle focus"].run = function()
    focus_hacked = not focus_hacked
    fix_camera_hack()
    print("Focus " .. (focus_hacked and "enabled" or "disabled"))
end

controls["cam left"].run = function()
    if not cam_hacked then return end
    local pos = Cam.GetCamPos()
    local forward = difference(Cam.GetFocusPos(), pos)
    local left = dir(cross(forward, {0, 1, 0}))
    local new_pos = add(pos, scale(left, CAM_SPEED))
    Cam.SetCamPos(new_pos)
    print("C: " .. str(new_pos) .. " " .. str(left))
end

controls["cam right"].run = function()
    if not cam_hacked then return end
    local pos = Cam.GetCamPos()
    local forward = difference(Cam.GetFocusPos(), pos)
    local right = dir(cross({0, 1, 0}, forward))
    local new_pos = add(pos, scale(right, CAM_SPEED))
    Cam.SetCamPos(new_pos)
    print("C: " .. str(new_pos) .. " " .. str(right))
end

controls["cam up"].run = function()
    if not cam_hacked then return end
    local new_pos = add(Cam.GetCamPos(), {0, CAM_SPEED, 0})
    Cam.SetCamPos(new_pos)
    print("C: " .. str(new_pos))
end

controls["cam down"].run = function()
    if not cam_hacked then return end
    local new_pos = add(Cam.GetCamPos(), {0, -CAM_SPEED, 0})
    Cam.SetCamPos(new_pos)
    print("C: " .. str(new_pos))
end

controls["cam back"].run = function()
	if not cam_hacked then return end
	local pos = Cam.GetCamPos()
	local away = dir(difference(pos, Cam.GetFocusPos()))
	local new_pos = add(pos, scale(away, CAM_SPEED))
    Cam.SetCamPos(new_pos)
    print("C: " .. str(new_pos))
end

controls["cam forward"].run = function()
	if not cam_hacked then return end
	local pos = Cam.GetCamPos()
	local away = dir(difference(pos, Cam.GetFocusPos()))
	local new_pos = add(pos, scale(away, -CAM_SPEED))
    Cam.SetCamPos(new_pos)
    print("C: " .. str(new_pos))
end

controls["focus closer"].run = function()
    if not focus_hacked then return end
    local focus = Cam.GetFocusPos()
    local towards = difference(Cam.GetCamPos(), focus)
    local new_pos = add(focus, scale(dir(towards), FOCUS_SPEED))
    Cam.SetFocus(new_pos)
    print("F: " .. str(new_pos) .. string.format(" %.1f", mag(difference(new_pos, Cam.GetCamPos()))))
end

controls["focus further"].run = function()
    if not focus_hacked then return end
    local focus = Cam.GetFocusPos()
    local away = difference(focus, Cam.GetCamPos())
    local new_pos = add(focus, scale(dir(away), FOCUS_SPEED))
    Cam.SetFocus(new_pos)
    print("F: " .. str(new_pos) .. string.format(" %.1f", mag(difference(new_pos, Cam.GetCamPos()))))
end

-- use CamPos as origin
controls["focus left"].run = function()
    if not focus_hacked then return end
    local pos = Cam.GetFocusPos()
    local away = difference(pos, Cam.GetCamPos())
    local left = dir(cross({0,1,0}, away))
	local new_pos = add(pos, scale(left, -FOCUS_SPEED))
    Cam.SetFocus(new_pos)
    print("F: " .. str(new_pos) .. " " .. str(left))
end

controls["focus right"].run = function()
    if not focus_hacked then return end
    local pos = Cam.GetFocusPos()
    local away = difference(pos, Cam.GetCamPos())
    local left = dir(cross({0,1,0}, away))
	local new_pos = add(pos, scale(left, FOCUS_SPEED))
    Cam.SetFocus(new_pos)
    print("F: " .. str(new_pos))
end

controls["focus up"].run = function()
    if not focus_hacked then return end
    local new_pos = add(scale({0,1,0}, FOCUS_SPEED), Cam.GetFocusPos())
    Cam.SetFocus(new_pos)
    print("F: " .. str(new_pos))
end
controls["focus down"].run = function()
    if not focus_hacked then return end
    local new_pos = add(scale({0,-1,0}, FOCUS_SPEED), Cam.GetFocusPos())
    Cam.SetFocus(new_pos)
    print("F: " .. str(new_pos))
end

-- hotkey detection

local previous_input = {}
local ROM = ({[0xC58400A4] = "U", [0x27BD0020] = "J"})[memory.readdword(0x802F0000)]

emu.atinterval(function()
	-- extra camera manipulation
	Cam.SetFOV(45)
	--print(Cam.GetFocusPos())
	-- setting focus point (not rendered focus point) so the tracker works
	-- as long as either is being edited keep it there
	if focus_hacked or cam_hacked then
		local pos = Cam.GetFocusPos()
		if pos[1] ~= nil then memory.writefloat(({U = 0x8033C698, J = 0x8033B328})[ROM], pos[1]) end
		if pos[2] ~= nil then memory.writefloat(({U = 0x8033C69C, J = 0x8033B32C})[ROM], pos[2]) end
		if pos[3] ~= nil then memory.writefloat(({U = 0x8033C6A0, J = 0x8033B330})[ROM], pos[3]) end
	end
	
	-- hotkeys
    local keyboard = input.get(1)
    for name, control in pairs(controls) do
        if #control.hotkeys > 0 then
            local all_pressed = true
			for i,key in pairs(control.hotkeys) do
                -- if the button is a hotkey, don't trigger it continuously
                if control.toggle and (not keyboard[key] or previous_input[key]) then
					all_pressed = false
                elseif not control.toggle and not keyboard[key] then
                    all_pressed = false
				end
			end
            if all_pressed then
                control.run()
            end
        end
    end
    previous_input = keyboard
end)

emu.atstop(Cam.RemoveCameraHack)
