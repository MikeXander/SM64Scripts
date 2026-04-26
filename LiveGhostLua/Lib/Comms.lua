--[[ Communications standard for these scripts:

1. Set ID: "1ID\n"
    The host manages the IDs for all the clients. The host gets ID=1.

2. Set Color and Name: "2ID|R,G,B,NAME\n"
    Each client controls their own color.

3. Set Ghost Data: "3ID|gt|x,y,z|animId,animF|pitch,yaw,roll\n"
    Share per-frame ghost information.

4. Disconnect: "4ID\n"
    Let clients know they can free space if someone disconnects.

Note: only the host sends out type 1 and type 4 messages.
]]

local COMMTYPE = {
    ASSIGN = "1",
    INFO = "2",
    DATA = "3",
    DISCONNECT = "4"
}

return {
    TYPES = COMMTYPE,

    MsgType = function(msg)
        return msg:sub(1, 1)
    end,

    AssignIDMsg = function(ID)
        return "1" .. ID .. "\n"
    end,

    InfoMsg = function(ID, color, name)
        if ID == nil or color == nil or #color < 3 or name == nil then
            return ""
        end
        return string.format(
            "2%d|%d,%d,%d,%s\n",
            ID, color[1], color[2], color[3], name
        )
    end,

    DataMsg = function(ID, data)
        if ID == nil or data.offset == nil or data.position == nil or
            data.position.x == nil or data.position.y == nil or data.position.z == nil or
            data.animationIndex == nil or data.animationFrame == nil or
            data.pitch == nil or data.yaw == nil or data.roll then
            return ""
        end
        return string.format(
            "3%d|%d|%.6f,%.6f,%.6f|%d,%d|%d,%d,%d\n",
            ID, data.offset,
            data.position.x, data.position.y, data.position.z,
            data.animationIndex, data.animationFrame,
            data.pitch, data.yaw, data.roll
        )
    end,

    DisconnectMsg = function(ID)
        return "4" .. ID .. "\n"
    end,

    DecodeMsg = function(msg)
        local msg_type = msg:sub(1, 1)
        if msg_type == COMMTYPE.ASSIGN then
            local ID = msg:match("1(.+)")
            ID = tonumber(ID)
            if ID == nil then
                return nil
            end
            return {
                ["type"] = COMMTYPE.ASSIGN,
                ["ID"] = ID
            }
        elseif msg_type == COMMTYPE.INFO then
            local ID,R,G,B,name = msg:match("2([^|]+)|([^,]+),([^,]+),([^,]+),(.+)")
            ID = tonumber(ID)
            R = tonumber(R)
            G = tonumber(G)
            B = tonumber(B)
            if ID == nil or R == nil or G == nil or B == nil or name == nil then
                return nil
            end
            return {
                ["type"] = COMMTYPE.INFO,
                ["ID"] = ID,
                ["color"] = {R, G, B},
                ["name"] = name
            }
        elseif msg_type == COMMTYPE.DATA then
            local ID, offset, x,y,z, animIdx,animFrame, pitch,yaw,roll =
            msg:match("3([^|]+)|([^|]+)|([^,]+),([^,]+),([^|]+)|([^,]+),([^|]+)|([^,]+),([^,]+),(.+)")

            ID = tonumber(ID)
            offset = tonumber(offset)
            x = tonumber(x)
            y = tonumber(y)
            z = tonumber(z)
            animIdx = tonumber(animIdx)
            animFrame = tonumber(animFrame)
            pitch = tonumber(pitch)
            yaw = tonumber(yaw)
            roll = tonumber(roll)

            if (ID == nil or offset == nil or
                x == nil or y == nil or z == nil or
                animIdx == nil or animFrame == nil or
                pitch == nil or yaw == nil or roll == nil) then
                return nil
            end
            
            return {
                ["type"] = COMMTYPE.DATA,
                ["ID"] = ID,
                ["data"] = {
                    ["offset"] = offset,
                    ["position"] = {
                        ["x"] = x,
                        ["y"] = (y),
                        ["z"] = (z)
                    },
                    ["animationIndex"] = animIdx,
                    ["animationFrame"] = animFrame,
                    ["pitch"] = pitch,
                    ["yaw"] = yaw,
                    ["roll"] = roll
                }
            }
        elseif msg_type == COMMTYPE.DISCONNECT then
            local ID = msg:match("4(.+)")
            ID = tonumber(ID)
            if ID == nil then
                return nil
            end
            return {
                ["type"] = COMMTYPE.DISCONNECT,
                ["ID"] = ID
            }
        end
    end,

    -- Receive a '\n'-terminated string. This avoids the bug
    -- where socket:receive("*l") returns a string s with
    -- non-zero #s but s:sub(i,i) is always nil
    ReceiveLine = function(socket)
        local buffer = ""

        while true do
            local byte, err, partial = socket:receive(1)

            local c = byte or partial
            if c and #c > 0 then
                if c == "\n" then
                    return buffer
                else
                    buffer = buffer .. c
                end
            end

            if err == "timeout" then
                return nil  -- no full line yet
            elseif err == "closed" then
                return nil, "closed"
            end
        end
    end
}
