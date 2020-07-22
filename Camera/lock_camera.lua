--[[
	Author: Xander
	Date: June 2020
	
	This was used to get the custom camera for this: https://youtu.be/cPj-bbvW_Nc
	It was all trial and error hardcoding...
	
	Special Thanks to MKDasher for ApplyCameraHack() and WriteRenderCamera()
]]

local path = "D:/lua.st"
local frame = 295
local restart = true

function ApplyCameraHack(pos, angle)
	if pos ~= nil then memory.writedword(0x00A87cf0, pos) end
	if angle ~= nil then memory.writedword(0x00A87d08, angle) end
	memory.recompilenextall()
end

function WriteRenderCamera(camstruct)
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

function cam(x, y, z, xfocus, yfocus, zfocus)
    return {
        x = x,
        y = y,
        z = z,
        xfocus = xfocus,
        yfocus = yfocus,
        zfocus = zfocus
    }
end

function SetCamPos(x, y, z)
	WriteRenderCamera(cam(x, y, z, nil, nil, nil))
end


local c1 = cam(6834, -1767, 2359, 6037, -1593, 2497)
local c2 = cam(6300, -2100, 1600, 5700, -1960, 1912)
local c3 = cam(3811, -2201, 1043, 3515, -2000, 1350)
local c4 = cam(4700, -2300, 950, 4400, -2200, 1100)
local c5 = cam(4910, -960, 910, 4310, -900, 1370)

local z1 = cam(3200, -820, 1750, 2530, -550, 2100)
local z2 = cam(2000, 1010, 1200, 1600, 720, 1950)
local z3 = cam(4500, -800, 1700, 3700, -980, 2000)

--[[
3200, -820, 1750
]]

local a = cam(5500, -300, 2400, 1400, -500, 3150)

local start = -400
local final = -1200

local f1 = 316
local f2 = 327

local dy = math.floor((final - start) / (f2 - f1))
local current_yfocus = start

function main()
	--print(frame)
	--if f1 < frame and frame < f2 then a.yfocus = a.yfocus + dy end
	--a.yfocus = -700
	--WriteRenderCamera(z3)
	SetCamPos(4000, -2700, 3000)
    ApplyCameraHack(0, nil)
	--frame = frame + 1
end

emu.atinput(main)
