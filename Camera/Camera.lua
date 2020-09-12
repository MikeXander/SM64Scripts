--[[
    Handle Camera in RAM

    Special Thanks:
		MKDasher for original code
		pfedak for proper pointer paths
]]

Cam = {}

-- detect the ROM for appropriate pointers
local ROM_list = {
	addr = 0x802F0000,
	U = 0xC58400A4,
	J = 0x27BD0020
}

local ROM = memory.readdword(ROM_list.addr)

if ROM == ROM_list.U then
	ROM = "U"
	print("U ROM detected")
elseif ROM == ROM_list.J then
	ROM = "J"
	print("J ROM detected")
else
	ROM = nil
	print("Error: ROM must be U or J")
end

-- Camera update instruction location
local Create_Camera = {
	U = 0x287be0,
	J = 0x2875f8,
	offset = 0x800110
}

-- remember the original instructions to revert later
local OriginalPos = memory.readdword(Create_Camera[ROM] + Create_Camera.offset)
local OriginalFocus = memory.readdword(Create_Camera[ROM] + Create_Camera.offset + 0x18)

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

function Cam.GetRenderCameraAddress()
	if not ROM then return end

	local offset = 0x00800000 - 0x80000000
	gCurrentArea = {
		U = 0x8032ddcc,
		J = 0x8032ce6c
	}
	area = memory.readdword(gCurrentArea[ROM] + offset) + offset
	root = memory.readdword(area + 0x04) + offset
	addr = memory.readdword(root + 0x24) + offset + 0x1c

	return addr
end

local function WriteRenderCamera(camstruct)
	if not ROM then return end
	local addr = Cam.GetRenderCameraAddress()

	if camstruct.x ~= nil then memory.writefloat(addr, camstruct.x) end
	if camstruct.y ~= nil then memory.writefloat(addr + 4, camstruct.y) end
	if camstruct.z ~= nil then memory.writefloat(addr + 8, camstruct.z) end
	if camstruct.xfocus ~= nil then memory.writefloat(addr + 12, camstruct.xfocus) end
	if camstruct.yfocus ~= nil then memory.writefloat(addr + 16, camstruct.yfocus) end
	if camstruct.zfocus ~= nil then memory.writefloat(addr + 20, camstruct.zfocus) end
end

-- Passing 0 as an argument prevents the camera from updating
-- Which allows us to manually edit the cam position
function Cam.ApplyCameraHack(pos, focus)
	if not ROM then return end
	if pos ~= nil then memory.writedword(Create_Camera[ROM] + Create_Camera.offset, pos) end
	if focus ~= nil then memory.writedword(Create_Camera[ROM] + Create_Camera.offset + 0x18, focus) end
	memory.recompilenextall()
end

function Cam.RemoveCameraHack()
	memory.writedword(Create_Camera[ROM] + Create_Camera.offset, OriginalPos)
	memory.writedword(Create_Camera[ROM] + Create_Camera.offset + 0x18, OriginalFocus)
	memory.recompilenextall()
end

function Cam.SetCamPos(pos)
    WriteRenderCamera({
        x = pos[1],
        y = pos[2],
        z = pos[3],
        xfocus = nil,
        yfocus = nil,
        zfocus = nil
    })
end

function Cam.SetFocus(pos)
	WriteRenderCamera({
        x = nil,
        y = nil,
        z = nil,
        xfocus = pos[1],
        yfocus = pos[2],
        zfocus = pos[3]
    })
end

function Cam.HideHUD()
	memory.writeword(HUD[ROM], 0x0) -- stars, lives, cam
	OriginalLevelIndex = memory.readword(LEVEL_INDEX[ROM])
	memory.writeword(LEVEL_INDEX[ROM], 0) -- coins
end

function Cam.ShowHUD()
	memory.writeword(HUD[ROM], 0x3F)
	memory.writeword(LEVEL_INDEX[ROM], OriginalLevelIndex)
end

-- 0 is high poly mode
-- 8 is low poly mode
function Cam.SetLevelOfDetail(val)
	if val ~= 0 and val ~= 8 then return end
	memory.writeword(LEVEL_OF_DETAIL[ROM], val)
end
