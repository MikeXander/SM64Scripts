--[[
    Author: Xander
    Custom Curve Fit for camera movement based on start/end position/velocity/time
    Only runs during playback of a TAS

    ToDo: Go through an arbitrary number of points
]]

p1 = {
    pos = {1940, -4120, -880},
    vel = {-10, -50, -10},
    frame = 74
}

p2 = {
    pos = {-100, -3500, -800},
    vel = {-1, 1, -1},
    frame = 170
}

-- Math
-- Source: https://stackoverflow.com/questions/4362498/curve-fitting-points-in-3d-space

T0 = 0
Tf = p2.frame - p1.frame

a = {}
local function fa(X0, V0, Xf, Vf)
    return (6 * (Tf*Tf*V0 - 2*T0*Tf*Vf + Tf*Tf*Vf - 2*T0*X0 + 2*Tf*X0 + 2*T0*Xf - 2*Tf*Xf)) / (Tf*Tf * (3*T0*T0 - 4*T0*Tf + Tf*Tf))
end

b = {}
local function fb(X0, V0, Xf, Vf)
    return (2 * (-2*Tf*Tf*Tf*V0 + 3*T0*T0*Tf*Vf - Tf*Tf*Tf*Vf + 3*T0*T0*X0 - 3*Tf*Tf*X0 - 3*T0*T0*Xf + 3*Tf*Tf*Xf)) / (Tf*Tf * (3*T0*T0 - 4*T0*Tf + Tf*Tf))
end

local function x(a, b, t, X0, Xf)
    return (3*b*t*t*Tf + a*t*t*t*Tf - 3*b*t*Tf*Tf - a*t*Tf*Tf*Tf - 6*t*X0 + 6*Tf*X0 + 6*t*Xf) / (6*Tf)
end

local function getPositionFunction()
    for i = 1,3 do
        a[i] = fa(p1.pos[i], p1.vel[i], p2.pos[i], p2.vel[i])
        b[i] = fb(p1.pos[i], p1.vel[i], p2.pos[i], p2.vel[i])
    end
    return function(t)
        return {
            x(a[1], b[1], t, p1.pos[1], p2.pos[1]),
            x(a[2], b[2], t, p1.pos[2], p2.pos[2]),
            x(a[3], b[3], t, p1.pos[3], p2.pos[3])
        }
    end
end

position = getPositionFunction()

-- Camera --

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

function SetCamPos(pos)
    WriteRenderCamera({
        x = pos[1],
        y = pos[2],
        z = pos[3],
        xfocus = nil,
        yfocus = nil,
        zfocus = nil
    })
end

ApplyCameraHack(0, nil)

function main()
    ApplyCameraHack(0, nil)
    frame = emu.samplecount()
    if p1.frame <= frame and frame <= p2.frame then
        p = position(frame - p1.frame)
        print("p("..frame..") = {"..p[1] .. ", " .. p[2] .. ", "..p[3].."}")
        SetCamPos(p)
    end
end

emu.atinput(main)
