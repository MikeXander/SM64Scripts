--[[
    Xander (June 2022)
    This script is to help you frame advance multiple frames at once, or frame advance
    until Mario changes action. If you add multiple keys to the hotkeys in controls,
    all the keys will need to be pressed to perform the operation.
    Valid keys (case-sensitive):
        https://docs.google.com/document/d/1SWd-oAFBKsGmwUs0qGiOrk3zfX9wYHhi3x5aKPQS_o0/edit#bookmark=id.jcojkq7g066s
]]
local controls = {
    ["advance to next action"] = {hotkeys = {"N"}},
    ["frame advance by x"] = {hotkeys = {"V"}},
    ["increment x"] = {hotkeys = {"up"}},
    ["decrement x"] = {hotkeys = {"down"}}
}

local x = 5
local target_frame = -2
local current_action = -2
local speed = 100

local Version = 2 -- U
if memory.readdword(0x00B22B24) == 1174429700 then
    Version = 1 -- J
end
ActionAddress = {
    0x00B39E0C, 0x00B3B17C
}

controls["advance to next action"].run = function()
    print("pause on next action")
    current_action = memory.readdword(ActionAddress[Version])
    if emu.getpause() then
        emu.pause(0)
    end
    speed = emu.getspeed()
    emu.speed(100)
end

controls["frame advance by x"].run = function()
    print("advance "..x)
    target_frame = emu.inputcount() + x
    if emu.getpause() then
        emu.pause(0)
    end
    speed = emu.getspeed()
    emu.speed(100)
end

controls["increment x"].run = function()
    x = x + 1
    print("x = " .. x)
end

controls["decrement x"].run = function()
    x = x - 1
    if x < 1 then x = 1 end
    print("x = " .. x)
end

emu.atvi(function()
    local current_frame = emu.inputcount()
    --print(current_frame)
    local action = memory.readdword(ActionAddress[Version])
    --print(action)
    if target_frame > current_frame or current_action == action then
        return -- "advancing"
    elseif (
        (target_frame == current_frame) or
        (current_action >= 0 and current_action ~= action)
        ) then
        emu.speed(speed)
        emu.pause()
        target_frame = -2
        current_action = -2
    end
end)

local previous_input = {}

emu.atinterval(function()
    local keyboard = input.get(1)
    for name, control in pairs(controls) do
        if #control.hotkeys > 0 then
            local all_pressed = true
			for i,key in pairs(control.hotkeys) do
				if not keyboard[key] or previous_input[key] then
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
