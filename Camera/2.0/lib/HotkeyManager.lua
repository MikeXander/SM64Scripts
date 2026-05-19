local HotkeyManager = {
    _controls = {},
    _previous_input = {},
    enabled = true
}

emu.atinterval(function()
    if not HotkeyManager.enabled then
        return
    end
	
    local keyboard = input.get(1)
    for name, control in pairs(HotkeyManager._controls) do
        if #control.hotkeys > 0 then
            local all_pressed = true
			for i,key in pairs(control.hotkeys) do
                -- if the button is a hotkey, don't trigger it continuously
                if control.toggle and (not keyboard[key] or HotkeyManager._previous_input[key]) then
					all_pressed = false
                elseif not control.toggle and not keyboard[key] then
                    all_pressed = false
				end
			end
            if all_pressed and control.run ~= nil then
                control.run()
            end
        end
    end
    HotkeyManager._previous_input = keyboard
end)

-- Ex: AddHotkey("Save", {"control", "S"}, function() ... end, true)
function HotkeyManager.AddHotkey(action_name, hotkey_list, action_func, is_toggle)
    HotkeyManager._controls[action_name] = {
        toggle = is_toggle or false, -- when false, apply action_func continuously
        hotkeys = hotkey_list,
        run = action_func
    }
end

-- change existing hotkey combinations
-- Ex: SetHotkeys({"Save" = {"control", "shift", "S"}})
function HotkeyManager.SetHotkeys(hotkeys)
    for action_name, hotkey_list in pairs(hotkeys) do
        if HotkeyManager._controls[action_name] == nil then
            HotkeyManager._controls[action_name] = {}
        end
        HotkeyManager._controls[action_name].hotkeys = hotkey_list
    end
end

return HotkeyManager
