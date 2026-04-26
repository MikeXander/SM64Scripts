-- LiveGhostLua-Client Version 1.0 by ERGC Xander

PATH = debug.getinfo(1).source:sub(2):match("(.*\\)")
package.path = package.path .. ";" .. PATH .. "?.lua;" .. PATH .. "Lib\\?.lua"
package.cpath = package.cpath .. ";" .. PATH .. "Lib\\?.dll"
local socket = require("socket")
local Comms = require("Comms")
local Config = require("Config")
local Ghost = require("Ghost")

local my_ID = nil
local current_frame = nil
local current_data = nil

-- track existing ghosts
local IdNameMap = {}

Ghost.applyGhostHack()
emu.atloadstate(Ghost.applyGhostHack)
Ghost.setColor(0, Config.COLOR)

local host = socket.tcp()
host:settimeout(0)
local connected = false

local function Connect()
    if not connected then
        local ok, err = host:connect(Config.IP, Config.PORT)
        if ok or err == "already connected" then
            connected = true
            IdNameMap[1] = "Host"
            print("Connected to host")
        end
    end
end

local function Disconnect()
    print("Disconnected")
    connected = false
    IdNameMap[1] = nil
    host:close()
    host = socket.tcp() -- attempt reconnect
    host:settimeout(0)
end

local function Process(msg)
    local msg_type = Comms.MsgType(msg)
    if msg_type == Comms.TYPES.ASSIGN then
        local data = Comms.DecodeMsg(msg)
        if data ~= nil then
            my_ID = data.ID
            print("Assigned ID=" .. my_ID)
            local s = Comms.InfoMsg(my_ID, Config.COLOR, Config.NAME)
            host:send(s)
        end
    elseif msg_type == Comms.TYPES.INFO then
        local data = Comms.DecodeMsg(msg)
        if data ~= nil then
            Ghost.setColor(data.ID, data.color)
            IdNameMap[data.ID] = data.name
            print(string.format(
                "Client ID=%d is '%s' #%02X%02X%02X",
                data.ID, data.name,
                data.color[1], data.color[2], data.color[3]
            ))
        end
    elseif msg_type == Comms.TYPES.DATA then
        local data = Comms.DecodeMsg(msg)
        if data ~= nil then
            Ghost.setGhostFrame(data.ID, data.data)
        end
    elseif msg_type == Comms.TYPES.DISCONNECT then
        local data = Comms.DecodeMsg(msg)
        if data ~= nil then
            Ghost.unloadGhost(data.ID)
            local name = IdNameMap[data.ID] or "Client"
            IdNameMap[data.ID] = nil
            print(string.format(
                "%s (ID=%d) disconnected",
                name, data.ID
            ))
        end
    end
end

emu.atinterval(function()
    Connect()
    if connected then
        if current_data ~= nil then
            host:send(Comms.DataMsg(my_ID, current_data))
            current_data = nil -- send once
        end
        local line, err = Comms.ReceiveLine(host)
        if err == "closed" then
            Disconnect()
        elseif line then
            Process(line)
        end
    end
end)

emu.atvi(function()
    current_data = Ghost.getCurrentFrame()
    -- don't unnecessarily send data twice
    if current_data.offset == current_frame then
        current_data = nil
    else
        current_frame = current_data.offset
    end
end)

emu.atinput(Ghost.updateGhosts)
