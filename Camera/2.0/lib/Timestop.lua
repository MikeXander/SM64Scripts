--[[
    A simple module to cause Timestop. Usage:
    Timestop = require("Timestop")
    emu.atvi(Timestop.atvi)
    Timestop.enabled = true
    or:
    Timestop.enable()
    Timestop.disable()
]]

local Timestop = {
    enabled = false
}

local ROM = memory.readdword(0x802F0000)
if ROM == 0x27BD0020 then -- JP
    Timestop.ADDRESS = 0x8033C110
else -- default to U
    Timestop.ADDRESS = 0x8033D480
end

function Timestop.enable()
    local value = memory.readdword(Timestop.ADDRESS)
    memory.writedword(Timestop.ADDRESS, value | 0x02)
end

function Timestop.disable()
    local value = memory.readdword(Timestop.ADDRESS)
    memory.writedword(Timestop.ADDRESS, value & (~0x02))
end

function Timestop.atvi()
    local value = memory.readdword(Timestop.ADDRESS)
    if Timestop.enabled then
        value = value | 0x02
    else
        value = value & (~0x02)
    end
    memory.writedword(Timestop.ADDRESS, value)
end

return Timestop
