local PATH = debug.getinfo(1).source:sub(2):match("(.*\\)")
local CONFIG = dofile(PATH .. "Config.lua")
if CONFIG.TASFILE:sub(1,2) == "./" or CONFIG.TASFILE:sub(1,2) == ".\\" then
    CONFIG.TASFILE = PATH .. CONFIG.TASFILE:sub(3)
end
local Ghost = dofile(PATH .. "lib\\Ghost.lua")
Ghost.initRecording()
emu.atinput(Ghost.recordFrame)
emu.atstopmovie(function()
    Ghost.saveRecording(CONFIG.TASFILE .. ".ghost")
    stop()
end)
movie.play(CONFIG.TASFILE .. ".m64")
