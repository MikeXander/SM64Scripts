return {
    -- needs TASFILE.m64/st/ghost
    TASFILE = "./save/tas",

    -- Visualiation colors: nil results in random color
    GHOST_TAS_COLOR = "#39E3F3",
    GHOST_CAMERA_COLOR = nil,
    GHOST_FOCUS_COLOR = nil,

    -- Free cam movement speed
    CAMERA_SPEED = 10.0,
    FOCUS_SPEED = 10.0,

    -- See list of case-sensitive keys:
    --    https://wade7wastaken.github.io/MupenLuaDoc/#inputGet
    -- To map a combo like CTRL+C list multiple: {"control", "C"}
    HOTKEYS = {
        ["Toggle Camera & Focus Hack"] = {},
        ["Toggle Camera Hack"] = {},
        ["Toggle Focus Hack"] = {},
        
        ["Camera Left"] = {"A"},
        ["Camera Right"] = {"D"},
        ["Camera Up"] = {"space"},
        ["Camera Down"] = {"shift"},
        ["Camera Backwards"] = {"S"},
        ["Camera Forwards"] = {"W"},
        
        ["Focus Left"] = {"left"},
        ["Focus Right"] = {"right"},
        ["Focus Up"] = {"up"},
        ["Focus Down"] = {"down"},
        ["Focus Closer"] = {"numpad0"},
        ["Focus Further"] = {"numpad1"}
    }
}
