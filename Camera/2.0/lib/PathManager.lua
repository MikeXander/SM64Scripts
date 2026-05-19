local PATH = debug.getinfo(1).source:sub(2):match("(.*\\)")
local json = dofile(PATH .. "utils\\json.lua")
local PathManager = {}

--[[
    Source: https://stackoverflow.com/questions/4362498/curve-fitting-points-in-3d-space
    Note: T0 = 0 simplifies things a little
    TODO: Optimize function calls: x(a[1], b[1], t, p1.pos[1], p2.pos[1]) -> x(t)
]]

local function fa(X0, V0, Xf, Vf, Tf)
    return (6 * (Tf*Tf*V0 + Tf*Tf*Vf + 2*Tf*X0 - 2*Tf*Xf)) / (Tf*Tf*Tf*Tf)
end

local function fb(X0, V0, Xf, Vf, Tf)
    return (2 * (-2*Tf*Tf*Tf*V0 - Tf*Tf*Tf*Vf - 3*Tf*Tf*X0 + 3*Tf*Tf*Xf)) / (Tf*Tf*Tf*Tf)
end

local function ft(a, b, t, X0, Xf, Tf) -- position given time
    return (3*b*t*t*Tf + a*t*t*t*Tf - 3*b*t*Tf*Tf - a*t*Tf*Tf*Tf - 6*t*X0 + 6*Tf*X0 + 6*t*Xf) / (6*Tf)
end

local function makef(a, b, X0, Xf, Tf, DEBUG)
    local c = {
        X0,
        (Xf - X0)/Tf - a*Tf*Tf/6 - b*Tf/2,
        b / 2,
        a / 6
    }
    return function(t)
        if DEBUG ~= nil then
            print(string.format(
                DEBUG.."(t) = %.3f + %.3f*t + %.3f*t^2 + %.3f*t^3",
                c[1], c[2], c[3], c[4]
            ))
        end
        return c[1] + c[2]*t + c[3]*t*t + c[4]*t*t*t
    end
end

-- p1, p2 = {pos = {n,n,n}, vel = {n,n,n}, frame = n}
-- duration = the time between each point
function PathManager.Interpolate(p1, p2, duration, DEBUG)
    local a = {}
    local b = {}
    for i = 1,3 do -- solve for coefficients
        a[i] = fa(p1.pos[i], p1.vel[i], p2.pos[i], p2.vel[i], duration)
        b[i] = fb(p1.pos[i], p1.vel[i], p2.pos[i], p2.vel[i], duration)
    end
    if DEBUG then
        print(p1)
        print(p2)
        print(duration)
        print("")
    end
    local x = makef(a[1], b[1], p1.pos[1], p2.pos[1], duration, DEBUG and "x" or nil)
    local y = makef(a[2], b[2], p1.pos[2], p2.pos[2], duration, DEBUG and "y" or nil)
    local z = makef(a[3], b[3], p1.pos[3], p2.pos[3], duration, DEBUG and "z" or nil)
    return function(frame)
        local t = frame - p1.frame
        if DEBUG then print("t="..t) end
        local v = {x(t), y(t), z(t)}
        if DEBUG then print("") end
        return v
    end
end

--[[
Consider a 1D example:
path = {points = {
    {f=1, x=1},
    {f=10, x=10}
}}
path(-1) = 1
path(7) = 7
path(42) = 10

Consider a 1D freeze frame example:
path = {points = {
    {f=1, x=1},
    {f=1, x=10, d=10},
    {f=1, x=20, d=5}
}}
path(1) = 1
path(1, 7) = 7
path(1, 11) = 12
path(1, 10000) = 20
path(2) = 20
]]

local pathmt = {
    __call = function(path, t, t2)
        if #path.points == 0 then
            print("Error: path does not contain any points")
            return nil
        end
        if t < path.points[1].frame then
            return path.points[1].pos
        end

        local found_freeze_frame = false
        for i = 1, #path.points - 1 do
            local f0 = path.points[i].frame
            local f1 = path.points[i + 1].frame
            if f0 == t and t == f1 then
                found_freeze_frame = true
                local d = path.points[i + 1].duration
                if t2 <= d then
                    -- TODO: precompute curves
                    return PathManager.Interpolate(
                        path.points[i],
                        path.points[i + 1],
                        path.points[i + 1].duration,
                        path.DEBUG
                    )(f0 + t2)
                end
                t2 = t2 - d -- accumulate duration
            elseif f0 < t and found_freeze_frame then
                -- duration beyond the freeze frame
                return path.points[i].pos
            elseif f0 == t then
                return path.points[i].pos
            elseif f0 < t and t < f1 then
                return PathManager.Interpolate(
                    path.points[i],
                    path.points[i + 1],
                    f1 - f0,
                    path.DEBUG
                )(t)
            end
        end
        
        return path.points[#path.points].pos
    end
}

function _addposition(path)
    path.position = function(f, ff)
        if path._frame_idx_map[f] ~= nil and ff == 0 then
            local i = path._frame_idx_map[f]
            return path.points[i].pos
        end
        return path(f, ff)
    end
end

function _addvelocity(path)
    path.velocity = function(f, ff)
        -- shortcut to return point velocity
        if path._frame_idx_map[f] ~= nil then
            local i = path._frame_idx_map[f]
            if ff == 0 then
                return path.points[i].vel
            end
            local j = ff
            while i < #path.points and j > 0 do
                i = i + 1
                j = j - path.points[i].duration
            end
            if j == 0 and i <= #path.points then
                return path.points[i].vel
            end
        end
        -- compute difference
        local p1 = path(f, ff)
        f, ff = PathManager.NextFrame(path, f, ff, false)
        local p2 = path(f, ff)
        return {p2[1]-p1[1], p2[2]-p1[2], p2[3]-p1[3]}
    end
end

function PathManager.NewPath()
    local path = {
        _frame_idx_map = {}, -- first index in points that has frame=key
        _has_ff = {},
        points = {}
    }
    setmetatable(path, pathmt)
    _addposition(path)
    _addvelocity(path)
    return path
end

-- returns the index of the new point added
-- enforces a minimum duration of 1 for freeze frames
function PathManager.AddPoint(path, frame, position, duration)
    local p = {
        pos = {position[1], position[2], position[3]},
        vel = {0, 0, 0},
        frame = frame,
        duration = duration or 0
    }
    for i = 1, #path.points do
        if path.points[i].frame > frame then
            table.insert(path.points, i, p)
            if path._frame_idx_map[frame] == nil then
                path._frame_idx_map[frame] = i
            else
                path._has_ff[frame] = true
                if p.duration == 0 then
                    p.duration = 1
                end
            end
            return i
        end
    end
    if #path.points > 0 and path.points[#path.points].frame == frame then
        -- adding freeze frame at the end
        if path._frame_idx_map[frame] == nil then
            path._frame_idx_map[frame] = #path.points
        end
        path._has_ff[frame] = true
        if p.duration == 0 then
            p.duration = 1
        end
    else
        path._frame_idx_map[frame] = #path.points + 1
    end
    table.insert(path.points, p)
    return #path.points
end

-- removes and returns the point on path at index i
function PathManager.RemovePointAt(path, i)
    local p = path.points[i]
    if path._has_ff[p.frame] then
        -- _frame_idx_map[p.frame] doesn't change in any case
        -- verify if it still has a freeze frame
        if not ((i > 1 and path.points[i - 1].frame == p.frame) or
            (i < #path.points and path.points[i + 1].frame == p.frame)) then
            path._has_ff[p.frame] = nil
        end
    else
        path._frame_idx_map[p.frame] = nil
    end
    -- all points after p need to have their index reduced by one
    for k, v in pairs(path._frame_idx_map) do
        if k > p.frame then
            path._frame_idx_map[k] = v - 1
        end
    end
    table.remove(path.points, i)
    return p
end

-- return the two points you're between
-- either may be nil
function PathManager.GetCurrentPoints(path, f, ff)
    if #path.points == 0 then
        return nil, nil
    end
    if f < path.points[1].frame then
        return nil, path.points[1]
    end
    local found_freeze_frame = false
    for i = 1, #path.points - 1 do
        local f0 = path.points[i].frame
        local f1 = path.points[i + 1].frame
        if f0 == f and f == f1 then
            found_freeze_frame = true
            local d = path.points[i + 1].duration
            if ff <= d then
                return path.points[i], path.points[i + 1]
            end
            ff = ff - d -- accumulate duration
        elseif (f0 < f and found_freeze_frame or
            f0 == f or f0 < f and f < f1) then
            return path.points[i], path.points[i + 1]
        end
    end
    return path.points[#path.points], nil
end

function PathManager.HasPointOnFrame(path, f)
    return path._frame_idx_map[f] ~= nil
end

function PathManager.HasFreezeFrameOnFrame(path, f)
    return path._has_ff[f] == true
end

-- given a path, a frame f, and a freeze frame delay ff,
-- return f, ff that advances to the next point on the path
function PathManager.NextFrame(path, f, ff, DEBUG)
    if path._has_ff[f] == nil then
        return f+1, 0
    end
    if DEBUG then
        print(path._has_ff)
        print(path._frame_idx_map)
    end
    local acc = ff
    for i = path._frame_idx_map[f], #path.points do
        if acc < path.points[i].duration then
            if DEBUG then print("a") end
            return f, ff+1
        elseif acc == path.points[i].duration and i < #path.points then
            if path.points[i+1].frame > f then
                if DEBUG then print("b") end
                return f+1, 0
            end
            if DEBUG then print("c") end
            return f, ff+1
        end
        acc = acc - path.points[i].duration
    end
    -- surpassed the final point, simply frame advance
    return f+1, 0
end

-- same as above but in reverse
function PathManager.PreviousFrame(path, f, ff)
    if ff > 0 then
        return f, ff-1
    end
    if path._has_ff[f-1] then
        -- accumulate all durations to get final ff delay
        ff = 0
        local i = path._frame_idx_map[f-1]
        while i <= #path.points and path.points[i].frame == f-1 do
            ff = ff + path.points[i].duration
            i = i + 1
        end
        return f-1, ff
    end
    return f-1, 0
end

function PathManager.Export(path, filepath)
    local fmap = path._frame_idx_map
    local ffmap = path._has_ff
    path._frame_idx_map = nil
    path._has_ff = nil
    path.position = nil
    path.velocity = nil
    path.__call = nil
    setmetatable(path, nil)
    local s = json.encode(path)
    path._frame_idx_map = fmap
    path._has_ff = ffmap
    setmetatable(path, pathmt)
    _addposition(path)
    _addvelocity(path)
    local f = assert(io.open(filepath, "w"))
    f:write(s)
    f:close()
end

function PathManager.Load(filepath)
    local f = assert(io.open(filepath, "r"))
    local s = f:read("*all")
    f:close()
    local path = json.decode(s)
    path._frame_idx_map = {}
    path._has_ff = {}
    for i = 1, #path.points do
        local f = path.points[i].frame
        if path._frame_idx_map[f] == nil then
            path._frame_idx_map[f] = i
        end
        if i > 1 and path.points[i - 1].frame == f then
            path._has_ff[f] = true
        end
    end
    setmetatable(path, pathmt)
    _addposition(path)
    _addvelocity(path)
    return path
end

return PathManager
