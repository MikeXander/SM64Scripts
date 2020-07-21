--[[
	Prints the positions of all the red coins currently loaded
]]

local red_graphic = 0x800F9C24
local object_addr = 0xB3D488
local offset = 0x260
local graphicsOffset = 0x14

local function print_pos(slot, obj_addr)
    local x = memory.readfloat(obj_addr + 0xA0)
    local y = memory.readfloat(obj_addr + 0xA4)
    local z = memory.readfloat(obj_addr + 0xA8)
    print(string.format("%d %.2f %.2f %.2f", slot, x, y, z))
end

local function main()
    for slot=0,240 do
        obj = object_addr + offset * slot
        if (memory.readdword(obj + graphicsOffset) == red_graphic) then -- identifyer
            print_pos(slot, obj)
        end
    end
end

main()
