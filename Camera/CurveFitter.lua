--[[
    Source: https://stackoverflow.com/questions/4362498/curve-fitting-points-in-3d-space
    Note: T0 = 0 simplifies things a little
    ToDo: Optimize function calls: x(a[1], b[1], t, p1.pos[1], p2.pos[1]) -> x(t)
]]

Curve = {}

local function fa(X0, V0, Xf, Vf, Tf)
    return (6 * (Tf*Tf*V0 + Tf*Tf*Vf + 2*Tf*X0 - 2*Tf*Xf)) / (Tf*Tf*Tf*Tf)
end

local function fb(X0, V0, Xf, Vf, Tf)
    return (2 * (-2*Tf*Tf*Tf*V0 - Tf*Tf*Tf*Vf - 3*Tf*Tf*X0 + 3*Tf*Tf*Xf)) / (Tf*Tf*Tf*Tf)
end

local function x(a, b, t, X0, Xf, Tf) -- position given time
    return (3*b*t*t*Tf + a*t*t*t*Tf - 3*b*t*Tf*Tf - a*t*Tf*Tf*Tf - 6*t*X0 + 6*Tf*X0 + 6*t*Xf) / (6*Tf)
end

-- p1, p2 = {pos = {n,n,n}, vel = {n,n,n}, frame = n}
-- duration = the time between each point
function Curve.getPositionFunction(p1, p2, duration)
    local a = {}
    local b = {}
    for i = 1,3 do -- solve for coefficients
        a[i] = fa(p1.pos[i], p1.vel[i], p2.pos[i], p2.vel[i], duration)
        b[i] = fb(p1.pos[i], p1.vel[i], p2.pos[i], p2.vel[i], duration)
    end
    return function(frame)
        local t = frame - p1.frame
        return {
            x(a[1], b[1], t, p1.pos[1], p2.pos[1], duration),
            x(a[2], b[2], t, p1.pos[2], p2.pos[2], duration),
            x(a[3], b[3], t, p1.pos[3], p2.pos[3], duration)
        }
    end
end
