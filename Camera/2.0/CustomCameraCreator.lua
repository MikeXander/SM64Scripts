local PATH = debug.getinfo(1).source:sub(2):match("(.*\\)")
local LIBPATH = PATH .. "lib\\"

UGUI_QUIET = true
BreitbandGraphics = dofile(LIBPATH .. 'ui\\breitbandgraphics-amalgamated.lua')
local ugui = dofile(LIBPATH .. 'ui\\ugui-amalgamated.lua')

local ROM = memory.readdword(0x802F0000)
local GLOBAL_TIMER_ADDR = ({
    [0xC58400A4] = 0x00B2D5D4,
    [0x27BD0020] = 0x00B2C694
})[ROM]
local gt = 0
local freeze_delay = 0

local Timestop = dofile(LIBPATH .. "Timestop.lua")
emu.atvi(Timestop.atvi)

local Camera = dofile(LIBPATH .. "Camera.lua")
emu.atstop(Camera.RestoreUpdateCode)
emu.atstop(Camera.Focus.RestoreUpdateCode)

-- load initial camera controlling hotkey functions:
HotkeyManager = dofile(LIBPATH .. "HotkeyManager.lua")
local CameraController = dofile(LIBPATH .. "CameraController.lua")
local CONFIG = dofile(PATH .. "Config.lua")
HotkeyManager.SetHotkeys(CONFIG.HOTKEYS)
CameraController.SetCameraSpeed(CONFIG.CAMERA_SPEED)
CameraController.SetFocusSpeed(CONFIG.FOCUS_SPEED)

-- allow relative path
if CONFIG.TASFILE:sub(1,2) == "./" or CONFIG.TASFILE:sub(1,2) == ".\\" then
    CONFIG.TASFILE = PATH .. CONFIG.TASFILE:sub(3)
end

local Ghost = dofile(LIBPATH .. "Ghost.lua")
emu.atloadstate(Ghost.applyGhostHack)
local GHOST_ID_TAS = Ghost.loadGhost(CONFIG.TASFILE .. ".ghost")
Ghost.setTransparency(GHOST_ID_TAS, false)
local GTOFFSET = Ghost.getGlobalTimerOffset(GHOST_ID_TAS)
local LENGTH = Ghost.getGhostDataLength(GHOST_ID_TAS)
Ghost.setGlobalTimerOffset(GHOST_ID_TAS, 1) -- display is off by one

local GHOST_ID_FOCUS = GHOST_ID_TAS + 1
Ghost.createGhost(GHOST_ID_FOCUS)
Ghost.setTransparency(GHOST_ID_FOCUS, false)

local GHOST_ID_CAMERA = GHOST_ID_FOCUS + 1
Ghost.createGhost(GHOST_ID_CAMERA)
Ghost.setTransparency(GHOST_ID_CAMERA, false)

if CONFIG.GHOST_TAS_COLOR then
    local c = BreitbandGraphics.hex_to_color(CONFIG.GHOST_TAS_COLOR)
    Ghost.setColor(GHOST_ID_TAS, c)
end
if CONFIG.GHOST_CAMERA_COLOR then
    local c = BreitbandGraphics.hex_to_color(CONFIG.GHOST_CAMERA_COLOR)
    CONFIG.GHOST_CAMERA_COLOR = c
end
if CONFIG.GHOST_FOCUS_COLOR then
    local c = BreitbandGraphics.hex_to_color(CONFIG.GHOST_FOCUS_COLOR)
    CONFIG.GHOST_FOCUS_COLOR = c
end

local Vec = dofile(LIBPATH .. "Math.lua")
local abs = math.abs
local ANIM_ID_FLYING = 42
local ANIM_ID_FLIP = 111

function MakeFlyingGhost(position, direction)
    local yaw, pitch = Vec.AnglesFromVec(direction)
    local anim = ANIM_ID_FLYING
    if direction[1] == 0 and direction[2] == 0 and direction[3] == 0 then
        anim = ANIM_ID_FLIP
    end
    return {
        offset = 1,
        position = {
            x = position[1],
            y = position[2],
            z = position[3]
        },
        animationIndex = anim,
        animationFrame = 0,
        pitch = -pitch,
        yaw = yaw,
        roll = 0
    }
end

local Mario = dofile(LIBPATH .. "Mario.lua")
local mario_loaded = true
--[[emu.atloadstate(function()
    if not mario_loaded then
        Mario.unload()
    end
end)
emu.atstop(function()
    if not mario_loaded then
        Mario.reload()
    end
end)]]

local PathManager = dofile(LIBPATH .. "PathManager.lua")
local camera_path = PathManager.NewPath()
camera_path.selected_index = nil
camera_path.text_list = {}
local focus_path = PathManager.NewPath()
focus_path.selected_index = nil
focus_path.text_list = {}

local slowmo_points = {}
local slowmo_text_list = {}
local slowmo_selected = nil
local slowmo_delay = 0
local current_slowmo_index = nil -- maybe track point instead?

local last_point_type = "None"

function FixSlowmoIndex(start_idx)
    if current_slowmo_index ~= nil and current_slowmo_index < #slowmo_points then
        local f0 = slowmo_points[current_slowmo_index].frame
        local f1 = f0 + slowmo_points[current_slowmo_index].duration
        if f0 <= gt and gt <= f1 then
            return
        end
    end
    if start_idx == nil then
        start_idx = 1
    end
    current_slowmo_index = nil
    for i = start_idx, #slowmo_points do
        local f0 = slowmo_points[i].frame
        local f1 = f0 + slowmo_points[i].duration
        if f0 <= gt and gt < f1 then
            current_slowmo_index = i
            return
        end
    end
end

function SyncSelectedIndexByName(path, name)
    path.selected_index = nil
    for i = 1, #path.text_list do
        if path.text_list[i] == name then
            path.selected_index = i
            break
        end
    end
    slowmo_selected = nil
    for i = 1, #slowmo_text_list do
        if slowmo_text_list[i] == name then
            slowmo_selected = i
            break
        end
    end
end

function FixTextList(path)
    if path == nil then
        slowmo_text_list = {}
        for k, point in pairs(slowmo_points) do
            -- NOTE: GT DISPLAY OFFSET
            table.insert(slowmo_text_list, string.format("%d", point.frame - GTOFFSET))
        end
        return
    end
    path.text_list = {}
    if #path.points == 0 then
        return
    end
    -- NOTE: GT DISPLAY OFFSET
    table.insert(path.text_list, string.format("%d", path.points[1].frame - GTOFFSET))
    local acc = 0 -- accumulate freeze frame duration
    for i = 2, #path.points do
        -- NOTE: GT DISPLAY OFFSET
        local name = string.format("%d", path.points[i].frame - GTOFFSET)
        if path.points[i-1].frame == path.points[i].frame then
            acc = acc + path.points[i].duration
            name = name .. string.format(" (%d)", acc)
        else
            acc = 0
        end
        table.insert(path.text_list, name)
    end
end

function AddPoint(path, position)
    local i = PathManager.AddPoint(path, gt, position)
    -- NOTE: GT DISPLAY OFFSET
    local name = string.format("%d", gt - GTOFFSET)
    if i > 1 and path.points[i - 1].frame == gt then
        local n = 1
        for j = i, 2, -1 do
            if path.points[j - 1].frame ~= gt then
                break
            end
            n = n + 1
        end
        name = name .. string.format(" (#%d)", n)
    end
    table.insert(path.text_list, i, name)
    FixTextList(path)
    return i
end

local initial_size = wgui.info()
local WIDTH = 200
wgui.resize(initial_size.width + WIDTH, initial_size.height)
local mouse_wheel = 0
local key_events = {}


-----------------------
-- Button Operations --
-----------------------
-- These cannot modify memory directly since the UI calls them

local FIRST_RELOAD = true
--local ENABLE_SHOW_FOCUS = true
function Reload()
    savestate.loadfile(CONFIG.TASFILE .. ".st")
    if FIRST_RELOAD then
        -- these cause problems during level load...
        -- let the user turn these on manually
        --[[toggle_mario = true
        toggle_camera_hack = true
        toggle_focus_hack = true
        toggle_focus = true]]
    else
        mario_loaded = true
        Camera.IsHacked = false
        Camera.Focus.IsHacked = false
        --ENABLE_SHOW_FOCUS = true
    end
    FIRST_RELOAD = false
end

local restart = false
function Restart()
    restart = true
end

local paused = false
local enable_timestop = false
local disable_timestop = false
local advance_to = nil
function FrameReverse()
    if not paused then -- pause
        paused = true
        enable_timestop = true
        return
    end
    
    local p = slowmo_points[current_slowmo_index]
    if p ~= nil then
        if slowmo_delay == 0 then
            slowmo_delay = p.speed + 1
        end
        slowmo_delay = slowmo_delay - 1
        if slowmo_delay == 0 then
            advance_to = gt - 1
            gt = gt - 1
            slowmo_delay = p.speed
        end
        return
    end

    local f
    f, freeze_delay = PathManager.PreviousFrame(camera_path, gt, freeze_delay)
    if f < gt then
        advance_to = gt - 1
    end
end

function TogglePause()
    paused = not paused
    enable_timestop = paused
end

function FrameAdvance()
    if not paused then
        paused = true
        enable_timestop = true
        return
    end

    local p = slowmo_points[current_slowmo_index]
    if p ~= nil then
        slowmo_delay = slowmo_delay + 1
        if slowmo_delay > p.speed then
            slowmo_delay = 1
            advance_to = gt + 1
            gt = gt + 1
            disable_timestop = true
        end
        return
    end
    
    local f, ff
    f, ff = PathManager.NextFrame(camera_path, gt, freeze_delay)
    if f > gt then
        advance_to = gt + 1
        disable_timestop = true
        gt = gt + 1
        FixSlowmoIndex(current_slowmo_index)
        gt = gt - 1
        if current_slowmo_index ~= nil then
            slowmo_delay = 1
        end
    else
        freeze_delay = ff -- update immediately
    end
end

local loop_ghost = false
function ToggleLoopGhost()
    loop_ghost = not loop_ghost
end

local toggle_camera_hack = false
local toggle_focus_hack = false
function ApplyCameraHack()
    toggle_camera_hack = true
    toggle_focus_hack = true
end

local hide_hud = false
function HideHUD()
    hide_hud = true
end

local toggle_mario = false
function ToggleMario()
    toggle_mario = true
end

local warp_to_ghost = false
function WarpMarioToGhost()
    warp_to_ghost = true
end

local add_camera_point = false
function AddCameraKeyframe()
    add_camera_point = true
end

local toggle_camera_ghost = false
local show_camera_ghost = false
function ToggleCameraVisibility()
    toggle_camera_ghost = true
end

local lock_camera_to_path = false
function ToggleCameraPathLock()
    lock_camera_to_path = not lock_camera_to_path
end

local add_focus_point = false
function AddFocusKeyframe()
    add_focus_point = true
end

local toggle_focus_ghost = false
local show_focus_ghost = false
function ToggleFocusVisibility()
    toggle_focus_ghost = true
end

local lock_focus_to_path = false
function ToggleFocusPathLock()
    lock_focus_to_path = not lock_focus_to_path
end

local warp_focus_to_ghost = false
function WarpFocusToGhost()
    warp_focus_to_ghost = true
end

local warp_focus_to_camera = false
function WarpFocusToCamera()
    warp_focus_to_camera = true
end

function DeleteSelectedKeyframe()
    local path = camera_path
    local other_path = focus_path
    if last_point_type == "Focus" then
        path = focus_path
        other_path = camera_path
        if camera_path.selected_index ~= nil then
            SelectPoint("Camera", camera_path.selected_index)
        end
    elseif last_point_type == "Slowmo" then
        path = nil
        for i = slowmo_selected, #slowmo_points - 1 do
            local p = slowmo_points[i + 1]
            slowmo_points[i] = {
                frame = p.frame,
                duration = p.duration,
                speed = p.speed
            }
        end
        slowmo_points[#slowmo_points] = nil

        slowmo_selected = nil
        last_point_type = "None"
        if keyframe_view == 1 and focus_path.selected_index ~= nil then
            SelectPoint("Focus", focus_path.selected_index)
        elseif keyframe_view == 2 and camera_path.selected_index ~= nil then
            SelectPoint("Camera", camera_path.selected_index)
        end
    elseif focus_path.selected_index ~= nil then
        SelectPoint("Focus", focus_path.selected_index)
    end
    if path ~= nil then
        PathManager.RemovePointAt(path, path.selected_index)
        if path.selected_index > 1 then
            path.selected_index = path.selected_index - 1
            SyncSelectedIndexByName(other_path, path.text_list[path.selected_index])
        elseif other_path.selected_index ~= nil then
            SyncSelectedIndexByName(path, other_path.text_list[other_path.selected_index])
        end
    end
    FixTextList(path)
end

local json = dofile(LIBPATH .. "utils\\json.lua")

function SavePoints()
    local txt = camera_path.text_list
    local i = camera_path.selected_index
    camera_path.text_list = nil
    camera_path.selected_index = nil
    PathManager.Export(camera_path, PATH .. "save/camera_points.json")
    camera_path.text_list = txt
    camera_path.selected_index = i

    txt = focus_path.text_list
    i = focus_path.selected_index
    focus_path.text_list = nil
    focus_path.selected_index = nil
    PathManager.Export(focus_path, PATH .. "save/focus_points.json")
    focus_path.text_list = txt
    focus_path.selected_index = i

    local s = json.encode(slowmo_points)
    local f = assert(io.open(PATH .. "save/slowmo_points.json", "w"))
    f:write(s)
    f:close()
end

function LoadPoints()
    camera_path = PathManager.Load(PATH .. "save/camera_points.json")
    FixTextList(camera_path)
    camera_path.selected_index = nil

    focus_path = PathManager.Load(PATH .. "save/focus_points.json")
    FixTextList(focus_path)
    focus_path.selected_index = nil

    local f = assert(io.open(PATH .. "save/slowmo_points.json", "r"))
    local s = f:read("*all")
    f:close()
    slowmo_points = json.decode(s)
    FixTextList()
    slowmo_selected = nil
end

local keyframe_view = 0

-- cannot add more than one point on the same frame
function AddSlowmoPoint()
    local new_point = {
        frame = gt,
        duration = 10,
        speed = 2
    }
    last_point_type = "Slowmo"
    for i, point in pairs(slowmo_points) do
        if point.frame == new_point.frame then
            return
        elseif new_point.frame < point.frame then
            slowmo_selected = i
            table.insert(slowmo_points, i, new_point)
            return
        end
    end
    table.insert(slowmo_points, new_point)
    slowmo_selected = #slowmo_points
    return new_point
end


function SelectPoint(point_type, index)
    last_point_type = point_type
    freeze_delay = 0
    slowmo_delay = 0
    if point_type == "Camera" then
        camera_path.selected_index = index
        SyncSelectedIndexByName(focus_path, camera_path.text_list[index])
        gt = camera_path.points[index].frame
        while index > 1 and camera_path.points[index - 1].frame == gt do
            freeze_delay = freeze_delay + camera_path.points[index].duration
            index = index - 1
        end
    elseif point_type == "Focus" then
        focus_path.selected_index = index
        SyncSelectedIndexByName(camera_path, focus_path.text_list[index])
        gt = focus_path.points[index].frame
        while index > 1 and focus_path.points[index - 1].frame == gt do
            freeze_delay = freeze_delay + focus_path.points[index].duration
            index = index - 1
        end
    elseif point_type == "Slowmo" then
        slowmo_selected = index
        SyncSelectedIndexByName(camera_path, slowmo_text_list[index])
        SyncSelectedIndexByName(focus_path, slowmo_text_list[index])
        gt = slowmo_points[index].frame
    end
end


function begin_frame()
    local mupen_input = input.get()
    ugui.begin_frame({
        mouse_position = {
            x = mupen_input.xmouse,
            y = mupen_input.ymouse,
        },
        wheel = mouse_wheel,
        is_primary_down = mupen_input.leftclick,
        key_events = key_events,
        window_size = {
            x = initial_size.width + WIDTH,
            y = initial_size.height,
        },
        shift = mupen_input.shift,
    })
    mouse_wheel = 0
end

function end_frame()
    ugui.end_frame()
    key_events = {}
end

emu.atwindowmessage(function(_, msg_id, wparam, _)
    if msg_id == 522 then
        local scroll = math.floor(wparam / 65536)
        if scroll == 120 then
            mouse_wheel = 1
        elseif scroll == 65416 then
            mouse_wheel = -1
        end
    end
end)

emu.atkey(function(args)
    key_events[#key_events + 1] = args
end)

local function draw_text(data)
    data.rectangle.x = data.rectangle.x + initial_size.width
    if data.align_x == nil then
        data.align_x = BreitbandGraphics.alignment.start
    end
    if data.color == nil then
        data.color = {r = 0, g = 0, b = 0}
    end
    if data.font_name == nil then
        data.font_name = ugui.standard_styler.params.font_name
    end
    if data.font_size == nil then
        data.font_size = ugui.standard_styler.params.font_size
    end
    BreitbandGraphics.draw_text2(data)
end

emu.atdrawd2d(function()
    begin_frame()

    local value, meta, point

    BreitbandGraphics.fill_rectangle({
        x = initial_size.width,
        y = 0,
        width = WIDTH,
        height = initial_size.height
    }, "#ffcba0")

    local frame_str = ""
    -- NOTE: GT DISPLAY OFFSET
    if freeze_delay > 0 then
        frame_str = string.format("Frame: %d (%d) / %d", gt - GTOFFSET, freeze_delay, LENGTH)
    elseif slowmo_delay > 0 then
        local spd = slowmo_points[current_slowmo_index].speed
        frame_str = string.format("Frame: %d (%d/%d) / %d", gt - GTOFFSET, slowmo_delay, spd, LENGTH)
    else
        frame_str = string.format("Frame: %d / %d", gt - GTOFFSET, LENGTH)
    end
    draw_text({
        rectangle = {x = 5, y = 4, width = 200, height = 16},
        text = FIRST_RELOAD and "Click 'Reload' to begin" or frame_str,
    })

    -- Frame advance controls

    local y0 = 24
    draw_text({
        rectangle = {x = 5, y = y0, width = 200, height = 16},
        text = "Control ――――――――――――",
    })

    y0 = y0 + 20
    if (ugui.button({
        uid = 36, is_enabled = true,
        rectangle = {
            x = initial_size.width + 5, y = y0,
            width = 30, height = 30,
        },
        text = "[icon:reset_settings]",
        color = {r=0,g=0,b=0,a=1},
        styler_mixin = {icon_size = 30},
        tooltip = "Reload"
    })) then
        Reload()
    end

    if (ugui.button({
        uid = 6, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*1, y = y0,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = "[icon:videocam_alert]",
        tooltip = "Apply camera hack"
    })) then
        ApplyCameraHack()
    end

    if (ugui.button({
        uid = 39, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*2, y = y0,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = "[icon:remove_display]",
        tooltip = "Hide HUD",
    })) then
        HideHUD()
    end

    if (ugui.button({
        uid = 4, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*3, y = y0,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = mario_loaded and "[icon:remove_person]" or "[icon:add_person]",
        tooltip = mario_loaded and "Unload Mario" or "Revive Mario",
    })) then
        ToggleMario()
    end

    if (ugui.button({
        uid = 8, is_enabled = mario_loaded and not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*4, y = y0,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = "[icon:group]",
        tooltip = "Warp Mario to ghost",
    })) then
        WarpMarioToGhost()
    end


    y0 = y0 + 35
    if (ugui.button({
        uid = 1, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5, y = y0,
            width = 30, height = 30,
        },
        text = "[icon:first_page]",
        styler_mixin = {icon_size = 30},
        tooltip = "Restart"
    })) then
        Restart()
    end

    if (ugui.button({
        uid = 35, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*1, y = y0,
            width = 30, height = 30,
        },
        text = "[icon:keyboard_left]",
        styler_mixin = {icon_size = 30},
        tooltip =  "Previous Frame"
    })) then
        FrameReverse()        
    end

    if (ugui.button({
        uid = 2, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*2, y = y0,
            width = 30, height = 30,
        },
        text = paused and "[icon:play]" or "[icon:pause]",
        styler_mixin = {icon_size = 30},
        tooltip =  paused and "Play" or "Pause"
    })) then
        TogglePause()
    end

    if (ugui.button({
        uid = 3, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*3, y = y0,
            width = 30, height = 30,
        },
        text = "[icon:keyboard_right]",
        styler_mixin = {icon_size = 30},
        tooltip =  "Frame Advance"
    })) then
        FrameAdvance()
    end

    if (ugui.button({
        uid = 73, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*4, y = y0,
            width = 30, height = 30,
        },
        text = loop_ghost and "[icon:sync_disabled]" or "[icon:sync]",
        styler_mixin = {icon_size = 30},
        tooltip =  loop_ghost and "Disable loop ghost playback" or "Loop ghost playback"
    })) then
        ToggleLoopGhost()
    end

    


    
    y0 = y0 + 15
    draw_text({
        rectangle = {x = 5, y = y0+20, width = 200, height = 16},
        text = "Camera ――――――――――――",
    })
    
    y0 = y0 + 20
    point = Camera.GetCachedRenderPosition()
    draw_text({
        rectangle = {x = 5, y = y0 + 20, width = 200, height = 16},
        text = "X:",
    })
    value = ugui.textbox({
        uid = 61, text = string.format("%.1f", point[1]),
        rectangle = {
            x = initial_size.width + 17, y = y0 + 20,
            width = 45, height = 18
        }
    })
    value = tonumber(value)
    if value ~= nil and abs(value - point[1]) >= 0.1 then
        point[1] = value
        CameraController.SetCameraTarget(value, nil, nil)
    end

    draw_text({
        rectangle = {x = 5+65, y = y0 + 20, width = 200, height = 16},
        text = "Y:",
    })
    value = ugui.textbox({
        uid = 62, text = string.format("%.1f", point[2]),
        rectangle = {
            x = initial_size.width + 17+65, y = y0 + 20,
            width = 45, height = 18
        }
    })
    value = tonumber(value)
    if value ~= nil and abs(value - point[2]) >= 0.1 then
        point[2] = value
        CameraController.SetCameraTarget(nil, value, nil)
    end

    draw_text({
        rectangle = {x = 5+65*2, y = y0 + 20, width = 200, height = 16},
        text = "Z:",
    })
    value = ugui.textbox({
        uid = 63, text = string.format("%.1f", point[3]),
        rectangle = {
            x = initial_size.width + 17+65*2, y = y0 + 20,
            width = 45, height = 18
        }
    })
    value = tonumber(value)
    if value ~= nil and abs(value - point[3]) >= 0.1 then
        point[3] = value
        CameraController.SetCameraTarget(nil, nil, value)
    end

    draw_text({
        rectangle = {x = 5, y = y0 + 43, width = 200, height = 16},
        text = "Movement speed:",
    })
    value = ugui.textbox({
        uid = 75, text = string.format("%.1f", CameraController.camera_speed),
        rectangle = {
            x = initial_size.width + 105, y = y0 + 43,
            width = 55, height = 18
        }
    })
    value = tonumber(value)
    if value ~= nil and abs(value - CameraController.camera_speed) >= 0.1 then
        CameraController.SetCameraSpeed(value)
    end

    y0 = y0 + 5 + 23
    if (ugui.button({
        uid = 10, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5, y = y0+40,
            width = 30, height = 30
        },
        text = "[icon:camera]", styler_mixin = {icon_size = 30},
        tooltip = "Add camera keyframe"
    })) then
        AddCameraKeyframe()
    end
    
    if (ugui.button({
        uid = 46, is_enabled = not FIRST_RELOAD,-- and ENABLE_SHOW_FOCUS,
        rectangle = {
            x = initial_size.width + 5 + 35*1, y = y0+40,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = show_camera_ghost and "[icon:visible_off]" or "[icon:visible]",
        tooltip = show_camera_ghost and "Hide camera" or "Show camera",
    })) then
        ToggleCameraVisibility()
    end

    if (ugui.button({
        uid = 37, is_enabled = not FIRST_RELOAD and #camera_path.points > 0,
        rectangle = {
            x = initial_size.width + 5 + 35*2, y = y0+40,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = lock_camera_to_path and "[icon:unlocked]" or "[icon:locked]",
        tooltip = lock_camera_to_path and "Unlock camera" or "Lock camera to path",
    })) then
        ToggleCameraPathLock()
    end

    if (ugui.button({
        uid = 70, is_enabled = not FIRST_RELOAD and not lock_focus_to_path,
        rectangle = {
            x = initial_size.width + 5 + 35*3, y = y0 + 40,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = "[icon:ar_on_camera]",
        tooltip = "Warp focus to camera",
    })) then
        WarpFocusToCamera()
    end

    local copy_position = nil
    if (ugui.button({
        uid = 71, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*4, y = y0 + 40,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = "[icon:content_paste]",
        tooltip = "Copy camera position to point",
    })) then
        copy_position = {point[1], point[2], point[3]}
    end


    
    y0 = y0 + 78
    draw_text({
        rectangle = {x = 5, y = y0, width = 200, height = 16},
        text = "Focus ―――――――――――――",
    })

    point = Camera.Focus.GetCachedRenderPosition()
    draw_text({
        rectangle = {x = 5, y = y0 + 20, width = 200, height = 16},
        text = "X:",
    })
    value = ugui.textbox({
        uid = 64, text = string.format("%.1f", point[1]),
        rectangle = {
            x = initial_size.width + 17, y = y0 + 20,
            width = 45, height = 18
        }
    })
    value = tonumber(value)
    if value ~= nil and abs(value - point[1]) >= 0.1 then
        point[1] = value
        CameraController.SetFocusTarget(value, nil, nil)
    end

    draw_text({
        rectangle = {x = 5+65, y = y0 + 20, width = 200, height = 16},
        text = "Y:",
    })
    value = ugui.textbox({
        uid = 65, text = string.format("%.1f", point[2]),
        rectangle = {
            x = initial_size.width + 17+65, y = y0 + 20,
            width = 45, height = 18
        }
    })
    value = tonumber(value)
    if value ~= nil and abs(value - point[2]) >= 0.1 then
        point[2] = value
        CameraController.SetFocusTarget(nil, value, nil)
    end

    draw_text({
        rectangle = {x = 5+65*2, y = y0 + 20, width = 200, height = 16},
        text = "Z:",
    })
    value = ugui.textbox({
        uid = 66, text = string.format("%.1f", point[3]),
        rectangle = {
            x = initial_size.width + 17+65*2, y = y0 + 20,
            width = 45, height = 18
        }
    })
    value = tonumber(value)
    if value ~= nil and abs(value - point[3]) >= 0.1 then
        point[3] = value
        CameraController.SetFocusTarget(nil, nil, value)
    end

    draw_text({
        rectangle = {x = 5, y = y0 + 43, width = 200, height = 16},
        text = "Movement speed:",
    })
    value = ugui.textbox({
        uid = 76, text = string.format("%.1f", CameraController.focus_speed),
        rectangle = {
            x = initial_size.width + 105, y = y0 + 43,
            width = 55, height = 18
        }
    })
    value = tonumber(value)
    if value ~= nil and abs(value - CameraController.focus_speed) >= 0.1 then
        CameraController.SetFocusSpeed(value)
    end

    y0 = y0 + 45 + 23
    if (ugui.button({
        uid = 11, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5, y = y0,
            width = 30, height = 30,
        },
        text = "[icon:target]", styler_mixin = {icon_size = 30},
        tooltip = "Add focus keyframe"
    })) then
        AddFocusKeyframe()
    end

    if (ugui.button({
        uid = 5, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*1, y = y0,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = show_focus_ghost and "[icon:visible_off]" or "[icon:visible]",
        tooltip = show_focus_ghost and "Hide focus" or "Show focus",
    })) then
        ToggleFocusVisibility()
    end

    if (ugui.button({
        uid = 38, is_enabled = not FIRST_RELOAD and #focus_path.points > 0,
        rectangle = {
            x = initial_size.width + 5 + 35*2, y = y0,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = lock_focus_to_path and "[icon:unlocked]" or "[icon:locked]",
        tooltip = lock_focus_to_path and "Unlock focus" or "Lock focus to path",
    })) then
        ToggleFocusPathLock()
    end

    if (ugui.button({
        uid = 55, is_enabled = not FIRST_RELOAD and not lock_focus_to_path,
        rectangle = {
            x = initial_size.width + 5 + 35*3, y = y0,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = "[icon:ar_on_you]",
        tooltip = "Warp focus to Mario",
    })) then
        WarpFocusToGhost()
    end

    if (ugui.button({
        uid = 72, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*4, y = y0,
            width = 30, height = 30,
        },
        styler_mixin = {icon_size = 30},
        text = "[icon:content_paste]",
        tooltip = "Copy focus position to point",
    })) then
        copy_position = {point[1], point[2], point[3]}
    end


    -- point list management --
    y0 = y0 + 35
    draw_text({
        rectangle = {x = 5, y = y0, width = 200, height = 16},
        text = "Keyframes ―――――――――――",
    })

    local path = nil
    point = nil
    if last_point_type == "Camera" then
        path = camera_path
    elseif last_point_type == "Focus" then
        path = focus_path
    elseif last_point_type == "Slowmo" then
        point = slowmo_points[slowmo_selected]
    end
    if path ~= nil then
        point = path.points[path.selected_index]
        if copy_position ~= nil then
            point.pos = {copy_position[1], copy_position[2], copy_position[3]}
        end
    end

    if (ugui.button({
        uid = 77, is_enabled = not FIRST_RELOAD and point ~= nil,
        rectangle = {
            x = initial_size.width + 5 + 35*0, y = y0+20,
            width = 30, height = 30
        },
        text = "[icon:delete_forever]", styler_mixin = {icon_size = 30},
        tooltip = "Delete selected keyframe"
    })) then
        DeleteSelectedKeyframe()
        path = nil
        point = nil
    end

    if (ugui.button({
        uid = 78, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*1, y = y0+20,
            width = 30, height = 30
        },
        text = "[icon:file_open]", styler_mixin = {icon_size = 30},
        tooltip = "Load points"
    })) then
        LoadPoints()
    end

    if (ugui.button({
        uid = 79, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*2, y = y0+20,
            width = 30, height = 30
        },
        text = "[icon:save]", styler_mixin = {icon_size = 30},
        tooltip = "Save points"
    })) then
        SavePoints()
    end

    if (ugui.button({
        uid = 80, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*3, y = y0+20,
            width = 30, height = 30
        },
        text = "[icon:speed_2]", styler_mixin = {icon_size = 30},
        tooltip = "Add slowmo keyframe"
    })) then
        point = AddSlowmoPoint()
        FixTextList()
        FixSlowmoIndex()
        path = nil
        for i = 1, #slowmo_points do
            if slowmo_points[i] == point then
                SelectPoint("Slowmo", i)
                break
            end
        end
    end

    if (ugui.button({
        uid = 81, is_enabled = not FIRST_RELOAD,
        rectangle = {
            x = initial_size.width + 5 + 35*4, y = y0+20,
            width = 30, height = 30
        },
        text = "[icon:cycle]", styler_mixin = {icon_size = 30},
        tooltip = "Cycle keyframe view"
    })) then
        keyframe_view = (keyframe_view + 1) % 3
    end

    local point_type, list, selected
    if keyframe_view == 0 then
        point_type = "Camera"
        list = camera_path.text_list
        selected = camera_path.selected_index
    elseif keyframe_view == 1 then
        point_type = "Focus"
        list = focus_path.text_list
        selected = focus_path.selected_index
    elseif keyframe_view == 2 then
        point_type = "Slowmo"
        list = slowmo_text_list
        selected = slowmo_selected
    end

    y0 = y0 + 30
    draw_text({
        rectangle = {x = 5, y = y0+20, width = 90, height = 16},
        align_x = BreitbandGraphics.alignment.center,
        text = point_type .. " Points",
    })

    local index, meta = ugui.listbox({
        uid = 20,
        rectangle = {
            x = initial_size.width + 5, y = y0+37,
            width = 90, height = 80
        },
        items = list,
        selected_index = selected,
    })
    if meta.clicked --[[meta.signal_change == ugui.signal_change_states.started]] then
        SelectPoint(point_type, index)
    end

    
    if (keyframe_view + 1) % 3 == 0 then
        point_type = "Camera"
        list = camera_path.text_list
        selected = camera_path.selected_index
    elseif (keyframe_view + 1) % 3 == 1 then
        point_type = "Focus"
        list = focus_path.text_list
        selected = focus_path.selected_index
    elseif (keyframe_view + 1) % 3 == 2 then
        point_type = "Slowmo"
        list = slowmo_text_list
        selected = slowmo_selected
    end

    draw_text({
        rectangle = {x = 100, y = y0+20, width = 90, height = 16},
        align_x = BreitbandGraphics.alignment.center,
        text = point_type .. " Points",
    })
    local index, meta = ugui.listbox({
        uid = 30,
        rectangle = {
            x = initial_size.width + 100, y = y0+37,
            width = 90, height = 80
        },
        items = list or {},
        selected_index = selected,
    })
    if meta.clicked then
        SelectPoint(point_type, index)
    end

    ----------
    -- edit --
    ----------

    y0 = y0 + 120
    draw_text({
        rectangle = {x = 5, y = y0, width = 200, height = 16},
        text = "Edit ―――――――――――――",
    })
    
    local dir = {0, 0, 0}
    if point ~= nil and point.vel ~= nil then
        dir = Vec.dir(point.vel)
    end
    local yaw, pitch = Vec.AnglesFromVec(dir)
    local mag = 1
    if point ~= nil and point.speed ~= nil then
        mag = point.speed
    elseif point ~= nil and point.vel ~= nil then
        mag = math.floor(Vec.mag(point.vel)+0.5)
    end
    local updated = false

    draw_text({
        rectangle = {x = 5, y = y0 + 17, width = 200, height = 16},
        text = "Selected Point: " .. (point == nil and "None" or last_point_type),
    })

    draw_text({
        rectangle = {x = 5, y = y0 + 38, width = 200, height = 16},
        text = "Frame:",
    })
    value = ugui.textbox({
        -- NOTE: GT DISPLAY OFFSET
        uid = 40, text = point == nil and "" or string.format("%d", point.frame - GTOFFSET),
        rectangle = {
            x = initial_size.width + 45, y = y0 + 38,
            width = 40, height = 18
        }
    })
    value = tonumber(value)
    if point ~= nil and value ~= nil and point.frame ~= value then
        -- NOTE: GT DISPLAY OFFSET
        value = value + GTOFFSET
        point.frame = value
        FixTextList(path)
    end

    
    local IS_FREEZE_FRAME = (path ~= nil and
        path.selected_index ~= nil and path.selected_index > 1 and
        path.points[path.selected_index - 1].frame == point.frame)
    draw_text({
        rectangle = {x = 100, y = y0 + 38, width = 200, height = 16},
        text = "Length:",
    })
    value = ugui.textbox({
        uid = 41, text = point == nil and "" or string.format("%d", point.duration),
        rectangle = {
            x = initial_size.width + 145, y = y0 + 38,
            width = 40, height = 18
        }
    })
    value = tonumber(value)
    if point ~= nil and point.duration > 0 and value ~= nil and point.duration ~= value then
        point.duration = value
        FixTextList(path)
    end

    draw_text({
        rectangle = {x = 5, y = y0 + 60, width = 200, height = 16},
        text = "X:",
    })
    value = ""
    if point ~= nil and point.pos ~= nil then
        value = string.format("%.1f", point.pos[1])
    end
    value = ugui.textbox({
        uid = 50, text = value,
        rectangle = {
            x = initial_size.width + 17, y = y0 + 60,
            width = 45, height = 18
        }
    })
    value = tonumber(value)
    if point ~= nil and point.pos ~= nil and value ~= nil then
        point.pos[1] = value
    end

    draw_text({
        rectangle = {x = 5+65, y = y0 + 60, width = 200, height = 16},
        text = "Y:",
    })
    value = ""
    if point ~= nil and point.pos ~= nil then
        value = string.format("%.1f", point.pos[2])
    end
    value = ugui.textbox({
        uid = 51, text = value,
        rectangle = {
            x = initial_size.width + 17+65, y = y0 + 60,
            width = 45, height = 18
        }
    })
    value = tonumber(value)
    if point ~= nil and point.pos ~= nil and value ~= nil then
        point.pos[2] = value
    end

    draw_text({
        rectangle = {x = 5+65*2, y = y0 + 60, width = 200, height = 16},
        text = "Z:",
    })
    value = ""
    if point ~= nil and point.pos ~= nil then
        value = string.format("%.1f", point.pos[3])
    end
    value = ugui.textbox({
        uid = 52, text = value,
        rectangle = {
            x = initial_size.width + 17+65*2, y = y0 + 60,
            width = 45, height = 18
        }
    })
    value = tonumber(value)
    if point ~= nil and point.pos ~= nil and value ~= nil then
        point.pos[3] = value
    end

    draw_text({
        rectangle = {x = 5, y = y0 + 80, width = 200, height = 16},
        text = "Speed:",
    })
    value = ugui.textbox({
        uid = 56, text = string.format("%d", mag),
        rectangle = {
            x = initial_size.width + 43, y = y0 + 80,
            width = 45, height = 18
        }
    })
    value = tonumber(value)
    if point ~= nil and value ~= nil and value ~= mag then
        value = math.floor(value)
        if point.speed ~= nil then
            point.speed = value
        elseif point.vel ~= nil then
            point.vel = Vec.scale(dir, value)
        end
    end

    draw_text({
        rectangle = {x = 5, y = y0 + 100, width = 200, height = 16},
        text = "Yaw:",
    })
    draw_text({
        rectangle = {x = 5, y = y0 + 120, width = 200, height = 16},
        text = "Pitch:",
    })

    -- yaw [0, 65535]
    value = ugui.textbox({
        uid = 43, text = string.format("%d", yaw),
        rectangle = {
            x = initial_size.width + 37, y = y0 + 100,
            width = 40, height = 18
        }
    })
    value = tonumber(value)
    if value ~= nil and value ~= yaw then
        yaw = math.floor(value)
        updated = true
    end
    value, meta = ugui.scrollbar({
        uid = 42, value = yaw/65535, ratio = 0.2,
        rectangle = {
            x = initial_size.width + 85, y = y0 + 104,
            width = 100, height = 10
        }
    })
    value = math.floor(65536 * value)
    if value ~= yaw then
        yaw = value
        updated = true
    end

    -- pitch [-16384, 16383]
    value = ugui.textbox({
        uid = 45, text = string.format("%d", pitch),
        rectangle = {
            x = initial_size.width + 37, y = y0 + 120,
            width = 40, height = 18
        }
    })
    value = tonumber(value)
    if value ~= nil and value ~= pitch then
        pitch = value
        updated = true
    end
    value, meta = ugui.scrollbar({
        uid = 44, value = (pitch+16384)/32767, ratio = 0.2,
        rectangle = {
            x = initial_size.width + 85, y = y0 + 124,
            width = 100, height = 10
        }
    })
    value = math.floor(32767 * value) - 16384
    if value ~= pitch then
        pitch = value
        updated = true
    end

    if point ~= nil and point.vel ~= nil and updated then
        local update_direction = Vec.FromAngles(yaw, pitch)
        if mag < 1 then
            mag = 1
        end
        point.vel = Vec.scale(update_direction, mag)
    end


    y0 = y0 + 40
    


    end_frame()
end)

emu.atstop(function()
    local size = wgui.info()
    wgui.resize(size.width - 200, size.height)
    BreitbandGraphics.free()
end)

emu.atloadstate(function()
    if paused then
        gt = memory.readdword(GLOBAL_TIMER_ADDR)
    end
end)

-- additionally: prevent C inputs from messing with the camera:
local DISABLED_INPUT = {R=false, A=false, B=false, Cup=false, left=false, Cright=false, up=false, Cleft=false, X=0, Y=0, Z=false, Cdown=false, L=false, down=false, start=false, right=false}
emu.atinput(function()
    if mario_loaded == false then
        joypad.set(1, DISABLED_INPUT)
    end
end)

emu.atvi(function()
    if add_camera_point then
        local i = AddPoint(camera_path, Camera.GetRenderPosition())
        camera_path.selected_index = i
        last_point_type = "Camera"
        if not add_focus_point then
            SyncSelectedIndexByName(focus_path, camera_path.text_list[i])
        end
    end
    if add_focus_point then
        local i = AddPoint(focus_path, Camera.Focus.GetRenderPosition())
        focus_path.selected_index = i
        last_point_type = "Focus"
        if not add_camera_point then
            SyncSelectedIndexByName(camera_path, focus_path.text_list[i])
        end
    end
    add_camera_point = false
    add_focus_point = false

    if warp_to_ghost then
        warp_to_ghost = false
        if mario_loaded == false then
            --Mario.reload()
            --mario_loaded = true
        end
        local data = Ghost.getGhostData(GHOST_ID_TAS, gt)
        Mario.SetPosition(data.position)
        if mario_loaded == false then
            --Mario.unload()
        end
    end

    if toggle_mario then
        if mario_loaded then
            Mario.unload()
        else
            Mario.reload()
        end
        mario_loaded = not mario_loaded
        toggle_mario = false
    end

    if toggle_camera_hack then
        toggle_camera_hack = false
        Camera.RemoveUpdateCode()
        local pos = Camera.GetRenderPosition() -- cache the pos
        Camera.SetRenderPosition(pos)
    end
    
    if toggle_focus_hack then
        toggle_focus_hack = false
        Camera.Focus.RemoveUpdateCode()
        local pos = Camera.Focus.GetRenderPosition() -- cache the pos
        Camera.Focus.SetRenderPosition(pos)
    end

    if hide_hud then
        Camera.HUD.Hide()
        hide_hud = false
    end

    if disable_timestop then
        Timestop.disable()
        disable_timestop = false
    elseif enable_timestop then
        Timestop.enable()
    end

    if restart or (loop_ghost and gt > GTOFFSET + LENGTH) then
        gt = GTOFFSET
        FixSlowmoIndex()
        slowmo_delay = 0
        if current_slowmo_index ~= nil then
            slowmo_delay = 1
        end
        memory.writedword(GLOBAL_TIMER_ADDR, GTOFFSET)
        restart = false
    elseif paused then
        if advance_to ~= nil then
            local current_gt = memory.readdword(GLOBAL_TIMER_ADDR)
            if current_gt > advance_to then
                -- sometimes when frame advancing this branch triggers
                local delay_already_updated = gt == advance_to
                gt = advance_to
                advance_to = nil
                FixSlowmoIndex()
                if current_slowmo_index == nil then
                    slowmo_delay = 0
                elseif not delay_already_updated then
                    slowmo_delay = slowmo_points[current_slowmo_index].speed
                end
            elseif current_gt == advance_to then
                freeze_delay = 0
                gt = current_gt
                advance_to = nil
                enable_timestop = true
                Timestop.enable()
                FixSlowmoIndex()
                if current_slowmo_index == nil then
                    slowmo_delay = 0
                end
            end
        end
        memory.writedword(GLOBAL_TIMER_ADDR, gt)
    elseif freeze_delay > 0 or slowmo_delay > 0 then
        memory.writedword(GLOBAL_TIMER_ADDR, gt)
    end

    UpdateCameraPosition()
    UpdateFocusPosition()

    Ghost.updateGhosts()
end)

local printed = nil
local printed_ff = nil
function UpdateCameraPosition()
    if #camera_path.points > 0 then
        local frame = gt
        if slowmo_delay > 0 then
            local p = slowmo_points[current_slowmo_index]
            frame = frame + (slowmo_delay - 1) / p.speed
        end
        local pos = camera_path(frame, freeze_delay)
        Camera.SetPosition(pos)
        if printed ~= frame or printed_ff ~= freeze_delay then
            print(frame, freeze_delay, pos)
            printed = frame
            printed_ff = freeze_delay
        end
        if lock_camera_to_path then
            Camera.SetRenderPosition(pos)
        end
    end

    if toggle_camera_ghost then
        show_camera_ghost = not show_camera_ghost
        if show_camera_ghost then
            Ghost.createGhost(GHOST_ID_CAMERA)
            Ghost.setTransparency(GHOST_ID_CAMERA, false)
            Ghost.setColor(GHOST_ID_CAMERA, CONFIG.GHOST_CAMERA_COLOR)
        else
            Ghost.unloadGhost(GHOST_ID_CAMERA)
        end
        toggle_camera_ghost = false
    end

    if show_camera_ghost then
        local pos = Camera.GetPosition()
        local dir = {0,0,0}
        if #camera_path.points > 0 then
            dir = camera_path.velocity(gt, freeze_delay)
        end
        local data = MakeFlyingGhost(pos, dir)
        Ghost.setGhostFrame(GHOST_ID_CAMERA, data)
    end
    
    --local MYAW = memory.readword(0x00B3B19E)
end

function UpdateFocusPosition()
    if warp_focus_to_ghost then
        warp_focus_to_ghost = false
        local data = Ghost.getGhostData(GHOST_ID_TAS, gt)
        local pos = {data.position.x, data.position.y, data.position.z}
        Camera.Focus.SetPosition(pos)
        Camera.Focus.SetRenderPosition(pos)
    elseif warp_focus_to_camera then
        warp_focus_to_camera = false
        local pos = Camera.GetPosition()
        pos = {pos[1]+1, pos[2], pos[3]+1} -- offset to avoid crash
        Camera.Focus.SetPosition(pos)
        Camera.Focus.SetRenderPosition(pos)
    elseif #focus_path.points > 0 then
        if lock_focus_to_path then
            local frame = gt
            if slowmo_delay > 0 then
                local p = slowmo_points[current_slowmo_index]
                frame = frame + (slowmo_delay - 1) / p.speed
            end
            local pos = focus_path(frame, freeze_delay)
            Camera.Focus.SetPosition(pos)
            Camera.Focus.SetRenderPosition(pos)
        else
            local pos = Camera.Focus.GetRenderPosition()
            Camera.Focus.SetPosition(pos)
        end
    else -- free focus movement
        local pos = Camera.Focus.GetRenderPosition()
        Camera.Focus.SetPosition(pos)
    end

    if toggle_focus_ghost then
        show_focus_ghost = not show_focus_ghost
        if show_focus_ghost then
            Ghost.createGhost(GHOST_ID_FOCUS)
            Ghost.setTransparency(GHOST_ID_FOCUS, false)
            Ghost.setColor(GHOST_ID_FOCUS, CONFIG.GHOST_FOCUS_COLOR)
        else
            Ghost.unloadGhost(GHOST_ID_FOCUS)
        end
        toggle_focus_ghost = false
    end

     if show_focus_ghost then
        local pos = Camera.Focus.GetPosition()
        local dir = {0,0,0}
        if #focus_path.points > 0 and lock_focus_to_path or 
                PathManager.HasPointOnFrame(focus_path, gt) then
            dir = focus_path.velocity(gt, freeze_delay)
        end
        local data = MakeFlyingGhost(pos, dir)
        Ghost.setGhostFrame(GHOST_ID_FOCUS, data)
    end
end

-- frame advance: "gt = gt + 1" but consider freeze frames & slow-mo
function advance_gt()

end

emu.atinput(function()
    if paused then
        return
    elseif PathManager.HasFreezeFrameOnFrame(camera_path, gt) then
        gt, freeze_delay = PathManager.NextFrame(camera_path, gt, freeze_delay)
        return
    elseif PathManager.HasFreezeFrameOnFrame(focus_path, gt) then
        gt, freeze_delay = PathManager.NextFrame(focus_path, gt, freeze_delay)
        return
    elseif lock_camera_to_path or lock_focus_to_path then
        freeze_delay = 0
    end

    local p = slowmo_points[current_slowmo_index]
    if p ~= nil and slowmo_delay + 1 <= p.speed then
        slowmo_delay = slowmo_delay + 1
        return -- advance slowmo in current frame
    end

    if lock_camera_to_path or lock_focus_to_path then
        gt = gt + 1
        freeze_delay = 0
    else
        gt = memory.readdword(GLOBAL_TIMER_ADDR)
    end

    FixSlowmoIndex(current_slowmo_index)
    slowmo_delay = 0
    if current_slowmo_index ~= nil then
        slowmo_delay = 1
    end
end)
