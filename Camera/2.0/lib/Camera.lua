--[[
    Handle Camera in RAM
    Special Thanks:
		MKDasher for original code
		pfedak for proper pointer paths
]]

Camera = {
	IsHacked = false,
	_cached_pos = {0,0,0},
	Focus = {
		IsHacked = false,
		_cached_pos = {0,0,0}
	},
	HUD = {}
}

-- detect the ROM for appropriate pointers
local ROM = memory.readdword(0x802F0000)
if ROM == 0xC58400A4 then
	ROM = "U"
elseif ROM == 0x27BD0020 then
	ROM = "J"
else
	ROM = nil
end

local CAMERA_X_ADDR = ({U = 0x8033C6A4, J = 0x8033B334})[ROM]
local FOCUS_X_ADDR = ({U = 0x8033C698, J = 0x8033B328})[ROM]

-- Camera update instruction location
local Create_Camera = {
	U = 0x287be0,
	J = 0x2875f8,
	offset = 0x800110
}

-- remember the original instructions to revert later
local OriginalPosCode = memory.readdword(Create_Camera[ROM] + Create_Camera.offset)
local OriginalFocusCode = memory.readdword(Create_Camera[ROM] + Create_Camera.offset + 0x18)

local HUD = {
	U = 0x8033b26a,
	J = 0x80339efa
}

local LEVEL_INDEX = {
	U = 0x8033BAC6,
	J = 0x8033A756
}

local OriginalLevelIndex = 0

local LEVEL_OF_DETAIL = {
	U = 0x8027BE20,
	J = 0x8027B870
}

local gCurrentArea = ({U = 0x8032DDCC, J = 0x8032CE6C})[ROM]

function Camera.RemoveUpdateCode()
	Camera.IsHacked = true
	memory.writedword(Create_Camera[ROM] + Create_Camera.offset, 0)
	memory.recompilenextall()
end

function Camera.RestoreUpdateCode()
	Camera.IsHacked = false
	memory.writedword(Create_Camera[ROM] + Create_Camera.offset, OriginalPosCode)
	memory.recompilenextall()
end

function Camera.ToggleHack()
	if Camera.IsHacked then
		Camera.RestoreUpdateCode()
	else
		Camera.RemoveUpdateCode()
	end
end

function Camera.Focus.RemoveUpdateCode()
	Camera.Focus.IsHacked = true
	memory.writedword(Create_Camera[ROM] + Create_Camera.offset + 0x18, 0)
	memory.recompilenextall()
end

function Camera.Focus.RestoreUpdateCode()
	Camera.Focus.IsHacked = false
	memory.writedword(Create_Camera[ROM] + Create_Camera.offset + 0x18, OriginalFocusCode)
	memory.recompilenextall()
end

function Camera.Focus.ToggleHack()
	if Camera.Focus.IsHacked then
		Camera.Focus.RestoreUpdateCode()
	else
		Camera.Focus.RemoveUpdateCode()
	end
end

emu.atloadstate(function()
	local x = memory.readdword(Create_Camera[ROM] + Create_Camera.offset)
	Camera.IsHacked = (x == 0)
	x = memory.readdword(Create_Camera[ROM] + Create_Camera.offset + 0x18)
	Camera.Focus.IsHacked = (x == 0)
end)

function Camera.GetRenderCameraAddress()
	if not ROM then return end
	local offset = 0x00800000 - 0x80000000
	local area = memory.readdword(gCurrentArea + offset) + offset
	local root = memory.readdword(area + 0x04) + offset
	local addr = memory.readdword(root + 0x24) + offset + 0x1c
	return addr
end

local function WriteRenderCamera(camstruct)
	if not ROM then return end
	local addr = Camera.GetRenderCameraAddress()
	if camstruct.x ~= nil then
		memory.writefloat(addr, camstruct.x)
		Camera._cached_pos[1] = camstruct.x
	end
	if camstruct.y ~= nil then
		memory.writefloat(addr + 4, camstruct.y)
		Camera._cached_pos[2] = camstruct.y
	end
	if camstruct.z ~= nil then
		memory.writefloat(addr + 8, camstruct.z)
		Camera._cached_pos[3] = camstruct.z
	end
	if camstruct.xfocus ~= nil then
		memory.writefloat(addr + 12, camstruct.xfocus)
		Camera.Focus._cached_pos[1] = camstruct.xfocus
	end
	if camstruct.yfocus ~= nil then
		memory.writefloat(addr + 16, camstruct.yfocus)
		Camera.Focus._cached_pos[2] = camstruct.yfocus
	end
	if camstruct.zfocus ~= nil then
		memory.writefloat(addr + 20, camstruct.zfocus)
		Camera.Focus._cached_pos[3] = camstruct.zfocus
	end
end

function Camera.SetRenderPosition(pos)
    WriteRenderCamera({
        x = pos[1],
        y = pos[2],
        z = pos[3],
        xfocus = nil,
        yfocus = nil,
        zfocus = nil
    })
end

function Camera.SetPosition(pos)
	if pos[1] ~= nil then memory.writefloat(CAMERA_X_ADDR, pos[1]) end
	if pos[2] ~= nil then memory.writefloat(CAMERA_X_ADDR + 0x4, pos[2]) end
	if pos[3] ~= nil then memory.writefloat(CAMERA_X_ADDR + 0x8, pos[3]) end
end

function Camera.GetPosition()
	return {
		memory.readfloat(CAMERA_X_ADDR),
		memory.readfloat(CAMERA_X_ADDR + 0x4),
		memory.readfloat(CAMERA_X_ADDR + 0x8)
	}
end

-- sets both render focus and actual camera focus
-- So, when the focus is no longer overwritten, the game will handle
-- making it ease back into its intended position
function Camera.Focus.SetRenderPosition(pos)
	WriteRenderCamera({
        x = nil,
        y = nil,
        z = nil,
        xfocus = pos[1],
        yfocus = pos[2],
        zfocus = pos[3]
    })
	-- this is so that visualize-position.lua will actually see the change
	if ROM == nil then return end
	local addr = ({U = 0x8033C698, J = 0x8033B328})[ROM]
	if pos[1] ~= nil then memory.writefloat(addr + 0x0, pos[1]) end
	if pos[2] ~= nil then memory.writefloat(addr + 0x4, pos[2]) end
	if pos[3] ~= nil then memory.writefloat(addr + 0x8, pos[3]) end
end

function Camera.GetRenderPosition()
	local addr = Camera.GetRenderCameraAddress()
	return {
		memory.readfloat(addr),
		memory.readfloat(addr + 4),
		memory.readfloat(addr + 8)
	}
end

-- no RAM read version
function Camera.GetCachedRenderPosition()
	return Camera._cached_pos
end

function Camera.Focus.GetRenderPosition()
	local addr = Camera.GetRenderCameraAddress()
	return {
		memory.readfloat(addr + 12),
		memory.readfloat(addr + 16),
		memory.readfloat(addr + 20)
	}
end

function Camera.Focus.GetCachedRenderPosition()
	return Camera.Focus._cached_pos
end

function Camera.Focus.SetPosition(pos)
	if pos[1] ~= nil then memory.writefloat(FOCUS_X_ADDR, pos[1]) end
	if pos[2] ~= nil then memory.writefloat(FOCUS_X_ADDR + 0x4, pos[2]) end
	if pos[3] ~= nil then memory.writefloat(FOCUS_X_ADDR + 0x8, pos[3]) end
end

function Camera.Focus.GetPosition()
	return {
		memory.readfloat(FOCUS_X_ADDR),
		memory.readfloat(FOCUS_X_ADDR + 0x4),
		memory.readfloat(FOCUS_X_ADDR + 0x8)
	}
end

function Camera.HUD.Hide()
	memory.writeword(HUD[ROM], 0x0) -- stars, lives, cam
	OriginalLevelIndex = memory.readword(LEVEL_INDEX[ROM])
	memory.writeword(LEVEL_INDEX[ROM], 0) -- coins
end

function Camera.HUD.Show()
	memory.writeword(HUD[ROM], 0x3F)
	memory.writeword(LEVEL_INDEX[ROM], OriginalLevelIndex)
end

-- 0 is high poly mode
-- 8 is low poly mode
function Camera.SetLevelOfDetail(val)
	if val ~= 0 and val ~= 8 then return end
	memory.writeword(LEVEL_OF_DETAIL[ROM], val)
end

function Camera.SetFOV(val)
	if val == nil then val = 45 end
	if ROM == nil then
		return
	elseif ROM == "U" then
		memory.writefloat(0x8033C5A4, val)
	elseif ROM == "J" then
		memory.writefloat(0x80189FC0, val)
	end
end

return Camera
