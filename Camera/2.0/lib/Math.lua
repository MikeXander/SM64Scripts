local Vec = {}

local abs = math.abs
local acos = math.acos
local atan2 = math.atan2
local floor = math.floor
local cos = math.cos
local sin = math.sin
local sqrt = math.sqrt
local RAD_TO_SHORT = 32768 / math.pi

function Vec.str(v)
    return string.format("(%.1f, %.1f, %.1f)", v[1], v[2], v[3])
end

-- +y = "up" (swap y and z)
function Vec.swap_vector(v)
    return {v[1], v[3], v[2]}
end

function Vec.cross(u, v)
    u = Vec.swap_vector(u)
    v = Vec.swap_vector(v)
    local product = {u[2]*v[3]-u[3]*v[2], u[3]*v[1]-u[1]*v[3], u[1]*v[2]-u[2]*v[1]}
    return Vec.swap_vector(product) -- swap back
end

function Vec.mag(v)
    return sqrt(v[1]*v[1] + v[2]*v[2] + v[3]*v[3])
end

function Vec.scale(v, s)
    return {s*v[1], s*v[2], s*v[3]}
end

function Vec.dir(v) 
    local m = Vec.mag(v)
    if m == 0 then
        return v
    end
    return Vec.scale(v, 1/m)
end

function Vec.difference(u, v) -- (u-v)
    return {u[1]-v[1], u[2]-v[2], u[3]-v[3]}
end

function Vec.add(u, v)
    local res = {u[1]+v[1], u[2]+v[2], u[3]+v[3]}
    return res
end

-- {x, y, z} -> Yaw, Pitch (in Mario angles)
function Vec.AnglesFromVec(v)
    local x, y, z = v[1], v[2], v[3]
    local pitch = atan2(y, sqrt(x*x + z*z))
    local yaw = atan2(x, z)
    return floor(yaw * RAD_TO_SHORT) % 65536, floor(pitch * RAD_TO_SHORT)
end

-- Yaw, Pitch -> unit {x, y, z} (y+=up, z+=0, x+=pi/2)
function Vec.FromAngles(yaw, pitch)
    yaw = yaw / 32768 * math.pi
    pitch = pitch / 32768 * math.pi
    local cos_pitch = abs(cos(pitch))
    return {
        sin(yaw) * cos_pitch, sin(pitch), cos(yaw) * cos_pitch
    }
end

return Vec
