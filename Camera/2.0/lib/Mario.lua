--[[
    Module for unloading & reviving Mario.
    This code was translated from STROOP
]]

-- Constants
local ROM = memory.readdword(0x802F0000)
local MARIO_ADDR = (ROM == 0xC58400A4 and 0x00B3B170) or 
    (ROM == 0x27BD0020 and 0x80339E00) or nil

local VACANT_ROOT = 0x803610F0
local MARIO_GFX = 0x800F0860
local GFX_OFFSET = 0x14
local ACTIVE_FLAGS_OFFSET = 0x74

-- STROOP/Structs/Configurations/ObjectSlotsConfig.cs
local PROCESS_GROUP_START_ADDR_U = 0x8033CBE0
local VACANT_SLOTS_NODE_ADDR_U = 0x803610F0
local PROCESSED_NEXT_LINK_OFFSET = 0x60
local PROCESSED_PREV_LINK_OFFSET = 0x64

-- callback is a function that will takes the address of each iterated object as an argument
-- if callback returns true, it stops further iterations
function iterateActiveObjects(callback)
	-- The game stores 16 different lists of loaded objects.
	-- Each root node is 0x68 bytes in size
	for i = 0, 15, 1 do 
		local objectList = 0x8033CBE0 + 0x68 * i
		local currentObject = memory.readdword(objectList + 0x60) --objectList->next
		if currentObject ~= 0 then --Do nothing if list is unused
			--Iterate until we reach the root node again, since these lists are cyclic
			while currentObject ~= objectList do
				if callback(currentObject) then
                    return
                end
				currentObject = memory.readdword(currentObject + 0x60) --currrentObject->next
			end
		end
	end
end

function iterateVacantObjects(callback)
    local current = memory.readdword(VACANT_ROOT + 0x60)
    while current ~= VACANT_ROOT do
        if callback(current) then
            return
        end
        current = memory.readdword(current + 0x60)
    end
end

function unloadMario()
    iterateActiveObjects(function(obj)
        gfx = memory.readdword(obj + GFX_OFFSET)
        if gfx == MARIO_GFX then
            memory.writeword(obj + ACTIVE_FLAGS_OFFSET, 0)
            return true
        end
    end) 
end

-- STROOP/Structs/Configurations/ObjectConfig.cs
-- STROOP/Models/ObjectDataModel.cs
function BehaviorProcessGroup(obj)
    local BehaviorScriptStart = memory.readdword(obj + 0x20C) 
    if BehaviorScriptStart == 0 then
        return nil
    end
    local firstScriptAction = memory.readdword(BehaviorScriptStart)
    if (firstScriptAction & 0xFF000000) ~= 0 then
        return nil
    end
    return (firstScriptAction & 0x00FF0000) >> 16
end

function renderObj(obj, enable)
    local value = memory.readbyte(obj + 0x3)
    if enable then
        value = value | 0x1
    else
        value = value & (~0x1)
    end
    memory.writebyte(obj + 0x3, value)
end

function renderMario(enable)
    iterateActiveObjects(function(obj)
        gfx = memory.readdword(obj + GFX_OFFSET)
        if gfx == MARIO_GFX then
            renderObj(obj, enable)
            return true
        end
    end) 
end

-- STROOP/Utilities/ButtonUtilities.cs
function reviveMario(render)
    -- option to re-enable rendering Mario at the end
    -- it can sometimes be useful to keep him hidden
    if render == nil then
        render = true
    end
    iterateVacantObjects(function(obj)
        gfx = memory.readdword(obj + GFX_OFFSET)
        if gfx ~= MARIO_GFX then
            return
        end

        local processGroup = BehaviorProcessGroup(obj)
        if processGroup == nil then
            return true
        end

        local groupAddress = PROCESS_GROUP_START_ADDR_U + processGroup * 0x68
        local lastGroupObj = groupAddress
        local x = memory.readdword(lastGroupObj + PROCESSED_NEXT_LINK_OFFSET)
        while (x ~= groupAddress) do
            lastGroupObj = x
            x = memory.readdword(lastGroupObj + PROCESSED_NEXT_LINK_OFFSET)
        end

        local nextObj = memory.readdword(obj + PROCESSED_NEXT_LINK_OFFSET)
        local prevObj = memory.readdword(VACANT_SLOTS_NODE_ADDR_U + PROCESSED_NEXT_LINK_OFFSET)
        if (prevObj == obj) then
            memory.writedword(VACANT_SLOTS_NODE_ADDR_U + PROCESSED_NEXT_LINK_OFFSET, nextObj)
        else
            local found = false
            for i = 0, 239 do
                local curObj = memory.readdword(prevObj + PROCESSED_NEXT_LINK_OFFSET)
                if curObj == obj then
                    found = true
                    break
                end
                prevObj = curObj
            end
            if found then
                return true
            end

            memory.writedword(prevObj + PROCESSED_NEXT_LINK_OFFSET, nextObj)
        end

        nextObj = memory.readdword(lastGroupObj + PROCESSED_NEXT_LINK_OFFSET)
        memory.writedword(nextObj + PROCESSED_PREV_LINK_OFFSET, obj)
        memory.writedword(lastGroupObj + PROCESSED_NEXT_LINK_OFFSET, obj)
        memory.writedword(obj + PROCESSED_PREV_LINK_OFFSET, lastGroupObj)
        memory.writedword(obj + PROCESSED_NEXT_LINK_OFFSET, nextObj)

        memory.writeword(obj + ACTIVE_FLAGS_OFFSET, 1)
        if render then
            renderObj(obj, true)
        end
        return true
    end)
end

return {
    unload = unloadMario,
    reload = reviveMario,
    render = renderMario,
    SetPosition = function(pos)
        memory.writefloat(MARIO_ADDR + 0x3C, pos.x)
        memory.writefloat(MARIO_ADDR + 0x40, pos.y)
        memory.writefloat(MARIO_ADDR + 0x44, pos.z)
    end
}
