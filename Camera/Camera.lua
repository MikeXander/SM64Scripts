--[[
    Handle Camera in RAM
    Special Thanks: MKDasher
]]

local Cam = {}

-- to be able to change the position this needs to be called with pos=0
function Cam.ApplyCameraHack(pos, angle)
	if pos ~= nil then memory.writedword(0x00A87cf0, pos) end
	if angle ~= nil then memory.writedword(0x00A87d08, angle) end
	memory.recompilenextall()
end

local function WriteRenderCamera(camstruct)
	local pointeraddr = 0x00A06BDC
	local addr = memory.readdword(pointeraddr)
	if addr > 0x80000000 and addr < 0x80300000 then
		addr = addr - 0x80000000 + 0x80001C
		if camstruct.x ~= nil then memory.writefloat(addr, camstruct.x) end
		if camstruct.y ~= nil then memory.writefloat(addr + 4, camstruct.y) end
		if camstruct.z ~= nil then memory.writefloat(addr + 8, camstruct.z) end
		if camstruct.xfocus ~= nil then memory.writefloat(addr + 12, camstruct.xfocus) end
		if camstruct.yfocus ~= nil then memory.writefloat(addr + 16, camstruct.yfocus) end
		if camstruct.zfocus ~= nil then memory.writefloat(addr + 20, camstruct.zfocus) end
	end
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

return Cam
