local PATH = debug.getinfo(1).source:sub(2):match("(.*\\)")
local LIBPATH = PATH .. "lib\\"
local SAVEPATH = PATH .. "save\\"

local Camera = dofile(LIBPATH .. "Camera.lua")
emu.atstop(Camera.RestoreUpdateCode)
emu.atstop(Camera.Focus.RestoreUpdateCode)

local CONFIG = dofile(PATH .. "Config.lua")
if CONFIG.TASFILE:sub(1,2) == "./" or CONFIG.TASFILE:sub(1,2) == ".\\" then
    CONFIG.TASFILE = PATH .. CONFIG.TASFILE:sub(3)
end

local File = dofile(LIBPATH .. "SavestateHandler.lua")
File.Savepath = SAVEPATH
File.Extract = File.ExtractSavestateWithLibDeflate
local has_7z = os.execute("7z.exe")
if has_7z then
    print("7zip found on path. Fast extraction enabled.")
    File.Extract = File.ExtractSavestateWith7z
else
    print("Warning: 7zip not found on path. Savestate extraction will be slow.")
end

-- load saved points

local json = dofile(LIBPATH .. "utils\\json.lua")
local PathManager = dofile(LIBPATH .. "PathManager.lua")
local camera_path = PathManager.Load(SAVEPATH .. "camera_points.json")
local focus_path = PathManager.Load(SAVEPATH .. "focus_points.json")
local f = assert(io.open(SAVEPATH .. "slowmo_points.json", "r"))
local s = f:read("*all")
f:close()
slowmo_points = json.decode(s)

print(string.format("Following %d camera points", #camera_path.points))
print(string.format("Following %d focus points", #focus_path.points))
print(string.format("With %d slow-mo ranges", #slowmo_points))

-- determine when savestates need to be created

local savestate_file = nil
local delete_stack = {}
local N = 0
local SAVE_FRAME = {}

local function MarkSavestateForDelete(frame)
    if savestate_file == nil then
        return
    end
    delete_stack[N + 1] = SAVEPATH .. frame .. ".st"
    N = N + 2 -- extra 1f buffer
    savestate_file:close()
    savestate_file = nil
end

local function CleanUpSavestates()
    if N then
        if delete_stack[N] then
            os.remove(delete_stack[N])
        end
        N = N - 1
    end
end

for i, p in pairs(camera_path.points) do
    if i > 1 and p.frame == camera_path.points[i - 1].frame then
        SAVE_FRAME[p.frame - 1] = true
    end
end

local SLOWMODE = {}
for i, p in pairs(slowmo_points) do
    for f = p.frame, p.frame + p.duration - 1 do
        SLOWMODE[f] = p.speed
        SAVE_FRAME[f - 1] = true
    end
end

-- track frames

local ROM = memory.readdword(0x802F0000)
local GLOBAL_TIMER_ADDR = ({
    [0xC58400A4] = 0x00B2D5D4,
    [0x27BD0020] = 0x00B2C694
})[ROM]

local f = 0 -- actual frame
local ff = 0 -- freeze frame
local sf = 0 -- slowmo frame

function main()
    CleanUpSavestates()

    -- ensure camera is hacked

    Camera.HUD.Hide()
    Camera.SetLevelOfDetail(0)
    Camera.RemoveUpdateCode()
    Camera.Focus.RemoveUpdateCode()

    local gt = memory.readdword(GLOBAL_TIMER_ADDR)
    if gt <= camera_path.points[1].frame then
        f = gt
    end

    local REAL_FRAMES_PER_FRAME = SLOWMODE[f] or 0
    local p1, p2
    p1, p2 = PathManager.GetCurrentPoints(camera_path, f, ff)

    -- handle loading savestates

    if SAVE_FRAME[f] and ( -- creating a savestate takes 1 frame
        ff == 0 and sf == 0 or
        p2 ~= nil and ff == p2.duration - 1 or
        SLOWMODE[f + 1] and (sf == REAL_FRAMES_PER_FRAME)
    ) then
        savestate.savefile(SAVEPATH .. (f + 1) .. ".st")
    end

    if SAVE_FRAME[f - 1] then -- checked separately for consecutive saves
        File.Extract(f)
        SAVE_FRAME[f - 1] = false -- only extract once
        savestate_file = io.open(SAVEPATH .. f .. ".st", "r+b")
		if SLOWMODE[f] then
			sf = 1
		end
    end

    -- set position along path

    local t = f
    if REAL_FRAMES_PER_FRAME > 0 then
        t = t + (sf - 1) / REAL_FRAMES_PER_FRAME
    end
    local camera_pos = camera_path(t, ff)
    local focus_pos = focus_path(t, ff)
    if savestate_file ~= nil then
        File.SetRenderPosition(savestate_file, camera_pos, focus_pos)
        savestate_file:close()
        savestate.loadfile(SAVEPATH .. f .. ".st")
        savestate_file = io.open(SAVEPATH .. f .. ".st", "r+b")
        Camera.RemoveUpdateCode()
        Camera.Focus.RemoveUpdateCode()
    end
    Camera.SetPosition(focus_pos)
    Camera.SetRenderPosition(camera_pos)
    Camera.Focus.SetPosition(focus_pos)
    Camera.Focus.SetRenderPosition(focus_pos)

    -- frame advance

    if ff > 0 or PathManager.HasFreezeFrameOnFrame(camera_path, f) then
        f, ff = PathManager.NextFrame(camera_path, f, ff)
        sf = 0
        if ff == p2.duration then
            MarkSavestateForDelete(f)
        end
    elseif sf > 0 then
        sf = sf + 1
        ff = 0
        if sf == REAL_FRAMES_PER_FRAME then
            MarkSavestateForDelete(f)
        elseif sf > REAL_FRAMES_PER_FRAME then
            f = f + 1
            sf = 0
        end
    else
        f = f + 1
        ff = 0
        sf = 0
    end

    if sf == 0 and SLOWMODE[f] then
        sf = 1
    end
end

emu.atinput(main)
