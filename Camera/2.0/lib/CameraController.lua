--[[
    Xander (Dec 2022, updated 2026)
    This is a script to help manipulate the camera and focus point.
    It will print out the location of the cam/focus each time it moves.
    Valid keys (case-sensitive):
        https://docs.google.com/document/d/1SWd-oAFBKsGmwUs0qGiOrk3zfX9wYHhi3x5aKPQS_o0/edit#bookmark=id.jcojkq7g066s

]]

local CameraController = {
    camera_speed = 10, -- units per frame
    focus_speed = 10, -- degrees per frame
    camera_target = nil,
    focus_target = nil
}

local PRINT_POSITIONS = false -- debug option

local PATH = debug.getinfo(1).source:sub(2):match("(.*\\)")
local Camera = dofile(PATH .. "Camera.lua")
local Vec = dofile(PATH .. "Math.lua")

if PRINT_POSITIONS then
  print("Initial camera position: " .. Vec.str(Camera.GetRenderPosition()))
end

if HotkeyManager == nil then
    HotkeyManager = dofile(PATH .. "HotkeyManager.lua")
end

HotkeyManager.AddHotkey(
    "Toggle Camera & Focus Hack",
    {"enter"},
    function()
        Camera.ToggleHack()
        Camera.Focus.ToggleHack()
        if PRINT_POSITIONS then
            local s = "Cam " .. (Camera.IsHacked and "enabled" or "disabled")
            s = s .. " Focus " .. (Camera.Focus.IsHacked and "enabled" or "disabled")
            print(s)
        end
    end,
    true
)

HotkeyManager.AddHotkey(
    "Toggle Camera Hack",
    {"O"},
    function()
        Camera.ToggleHack()
        if PRINT_POSITIONS then
            print("Cam " .. (Camera.IsHacked and "enabled" or "disabled"))
        end
    end,
    true
)

HotkeyManager.AddHotkey(
    "Toggle Focus Hack",
    {"P"},
    function()
        Camera.Focus.ToggleHack()
        if PRINT_POSITIONS then
            print("Focus " .. (Camera.Focus.IsHacked and "enabled" or "disabled"))
        end
    end,
    true
)

HotkeyManager.AddHotkey(
    "Camera Left",
    {"A"},
    function()
        if not Camera.IsHacked then return end
        local pos = Camera.GetRenderPosition()
        local forward = Vec.difference(Camera.Focus.GetRenderPosition(), pos)
        local left = Vec.dir(Vec.cross(forward, {0, 1, 0}))
        local new_pos = Vec.add(pos, Vec.scale(left, CameraController.camera_speed))
        Camera.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then
            print("C: " .. Vec.str(new_pos) .. " " .. Vec.str(left))
        end
    end
)

HotkeyManager.AddHotkey(
    "Camera Right",
    {"D"},
    function()
        if not Camera.IsHacked then return end
        local pos = Camera.GetRenderPosition()
        local forward = Vec.difference(Camera.Focus.GetRenderPosition(), pos)
        local right = Vec.dir(Vec.cross({0, 1, 0}, forward))
        local new_pos = Vec.add(pos, Vec.scale(right, CameraController.camera_speed))
        Camera.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then
            print("C: " .. Vec.str(new_pos) .. " " .. Vec.str(right))
        end
    end
)

HotkeyManager.AddHotkey(
    "Camera Up",
    {"space"},
    function()
        if not Camera.IsHacked then return end
        local new_pos = Vec.add(Camera.GetRenderPosition(), {0, CameraController.camera_speed, 0})
        Camera.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then
            print("C: " .. Vec.str(new_pos))
        end
    end
)

HotkeyManager.AddHotkey(
    "Camera Down",
    {"shift"},
    function()
        if not Camera.IsHacked then return end
        local new_pos = Vec.add(Camera.GetRenderPosition(), {0, -CameraController.camera_speed, 0})
        Camera.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then
            print("C: " .. Vec.str(new_pos))
        end
    end
)

HotkeyManager.AddHotkey(
	"Camera Backwards",
    {"S"},
    function()
        if not Camera.IsHacked then return end
        local pos = Camera.GetRenderPosition()
        local away = Vec.dir(Vec.difference(pos, Camera.Focus.GetRenderPosition()))
        local new_pos = Vec.add(pos, Vec.scale(away, CameraController.camera_speed))
        Camera.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then
            print("C: " .. Vec.str(new_pos))
        end
    end
)

HotkeyManager.AddHotkey(
    "Camera Forwards",
    {"W"},
    function()
        if not Camera.IsHacked then return end
        local pos = Camera.GetRenderPosition()
        local away = Vec.dir(Vec.difference(pos, Camera.Focus.GetRenderPosition()))
        local new_pos = Vec.add(pos, Vec.scale(away, -CameraController.camera_speed))
        Camera.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then
            print("C: " .. Vec.str(new_pos))
        end
    end
)

-- focus rotations use the camera position as the origin
HotkeyManager.AddHotkey(
    "Focus Left",
    {"left"},
    function()
        if not Camera.Focus.IsHacked then return end
        local pos = Camera.Focus.GetRenderPosition()
        local away = Vec.difference(pos, Camera.GetRenderPosition())
        local left = Vec.dir(Vec.cross({0,1,0}, away))
        local new_pos = Vec.add(pos, Vec.scale(left, -CameraController.focus_speed))
        Camera.Focus.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then
            print("F: " .. Vec.str(new_pos) .. " " .. Vec.str(left))
        end
    end
)

HotkeyManager.AddHotkey(
    "Focus Right",
    {"right"},
    function()
        if not Camera.Focus.IsHacked then return end
        local pos = Camera.Focus.GetRenderPosition()
        local away = Vec.difference(pos, Camera.GetRenderPosition())
        local left = Vec.dir(Vec.cross({0,1,0}, away))
        local new_pos = Vec.add(pos, Vec.scale(left, CameraController.focus_speed))
        Camera.Focus.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then 
            print("F: " .. Vec.str(new_pos))
        end
    end
)

HotkeyManager.AddHotkey(
    "Focus Up",
    {"up"},
    function()
        if not Camera.Focus.IsHacked then return end
        local new_pos = Vec.add(
            Vec.scale({0,1,0}, CameraController.focus_speed),
            Camera.Focus.GetRenderPosition()
        )
        Camera.Focus.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then
            print("F: " .. Vec.str(new_pos))
        end
    end
)

HotkeyManager.AddHotkey(
    "Focus Down",
    {"down"},
    function()
        if not Camera.Focus.IsHacked then return end
        local new_pos = Vec.add(
            Vec.scale({0,-1,0}, CameraController.focus_speed),
            Camera.Focus.GetRenderPosition()
        )
        Camera.Focus.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then
            print("F: " .. Vec.str(new_pos))
        end
    end
)

HotkeyManager.AddHotkey(
    "Focus Closer",
    {"numpad1"},
    function()
        if not Camera.Focus.IsHacked then return end
        local focus = Camera.Focus.GetRenderPosition()
        local towards = Vec.difference(Camera.GetRenderPosition(), focus)
        local new_pos = Vec.add(focus, Vec.scale(Vec.dir(towards), CameraController.focus_speed))
        Camera.Focus.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then
            print(string.format(
                "F: " .. Vec.str(new_pos) .. " %.1f",
                Vec.mag(Vec.difference(new_pos, Camera.GetRenderPosition()))
            ))
        end
    end
)

HotkeyManager.AddHotkey(
    "Focus Further",
    {"numpad2"},
    function()
        if not Camera.Focus.IsHacked then return end
        local focus = Camera.Focus.GetRenderPosition()
        local away = Vec.difference(focus, Camera.GetRenderPosition())
        local new_pos = Vec.add(focus, Vec.scale(Vec.dir(away), CameraController.focus_speed))
        Camera.Focus.SetRenderPosition(new_pos)
        if PRINT_POSITIONS then
            print(string.format(
                "F: " .. Vec.str(new_pos) .." %.1f",
                Vec.mag(Vec.difference(new_pos, Camera.GetRenderPosition()))
            ))
        end
    end
)


emu.atvi(function()
    -- handle RAM edits
    if CameraController.camera_target ~= nil and Camera.IsHacked then
        Camera.SetRenderPosition(CameraController.camera_target)
        CameraController.camera_target = nil
    end
    if CameraController.focus_target ~= nil and Camera.Focus.IsHacked then
        Camera.Focus.SetRenderPosition(CameraController.focus_target)
        CameraController.focus_target = nil
    end
end)

emu.atstop(Camera.RemoveCameraHack)

function CameraController.SetCameraSpeed(n)
    n = tonumber(n)
    if n == nil then
        return
    elseif n < 1 then
        n = 1
    end
    CameraController.camera_speed = n
end

function CameraController.SetFocusSpeed(n)
    n = tonumber(n)
    if n == nil then
        return
    elseif n < 1 then
        n = 1
    end
    CameraController.focus_speed = n
end

function CameraController.SetCameraTarget(x, y, z)
    CameraController.camera_target = {x, y, z}
end

function CameraController.SetFocusTarget(x, y, z)
    CameraController.focus_target = {x, y, z}
end

return CameraController
