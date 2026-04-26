-- LiveGhostLua-Host Version 1.0 by ERGC Xander

PATH = debug.getinfo(1).source:sub(2):match("(.*\\)")
package.path = package.path .. ";" .. PATH .. "?.lua;" .. PATH .. "Lib\\?.lua"
package.cpath = package.cpath .. ";" .. PATH .. "Lib\\?.dll"
local socket = require("socket")
local Comms = require("Comms")
local Config = require("Config")
local Ghost = require("Ghost")

local ghost_ID = nil
local current_frame = nil
local current_data = nil

Ghost.applyGhostHack()
emu.atloadstate(Ghost.applyGhostHack)
Ghost.setColor(0, Config.COLOR)

local server = assert(socket.bind("*", Config.PORT))
server:settimeout(0)
local allow_connections = true

print(string.format(
    "Hosting on port %d as '%s' using %s + %s",
    Config.PORT, Config.NAME, _VERSION, socket._VERSION
))

local IdClientMap = {}
local IdNameMap = {}
local last_given_ID = 1

local function Connect()
    if allow_connections then
        local client = server:accept()
        if client then
            client:settimeout(0)

            -- assign them a new ID
            last_given_ID = last_given_ID + 1
            client:send(Comms.AssignIDMsg(last_given_ID))

            -- forward color+name info about existing clients
            client:send(Comms.InfoMsg(1, Config.COLOR, Config.NAME))
            for ID, _ in pairs(IdClientMap) do
                local c = Ghost.getColor(ID)
                local name = IdNameMap[ID]
                if c ~= nil and name ~= nil then
                    client:send(Comms.InfoMsg(ID, c, name))
                end
            end

            IdClientMap[last_given_ID] = client
            print(string.format("Client (ID=%d) connected", last_given_ID))
        end
    end
end

local function Disconnect(ID)
    local name = IdNameMap[ID] or "Client"
    IdClientMap[ID] = nil
    IdNameMap[ID] = nil
    Ghost.unloadGhost(ID)
    print(string.format("%s (ID=%d) disconnected", name, ID))
end

local function Broadcast(ID, msg)
    for id, client in pairs(IdClientMap) do
        if id ~= ID then
            client:send(msg)
        end
    end
end

local function Process(sock, msg)
    local msg_type = Comms.MsgType(msg)
    if msg_type == Comms.TYPES.INFO then
        local data = Comms.DecodeMsg(msg)
        if data ~= nil then
            IdNameMap[data.ID] = data.name
            Ghost.setColor(data.ID, data.color)
            print(string.format(
                "Client ID=%d is '%s' #%02X%02X%02X",
                data.ID, data.name,
                data.color[1], data.color[2], data.color[3]
            ))
            Broadcast(data.ID, msg .. "\n")
        end
    elseif msg_type == Comms.TYPES.DATA then
        local data = Comms.DecodeMsg(msg)
        if data ~= nil then
            Ghost.setGhostFrame(data.ID, data.data)
            Broadcast(data.ID, msg .. "\n")
        end
    end
end

emu.atinterval(function()
    -- accept clients (non-blocking)
    Connect()

    -- send host data to clients
    if current_data ~= nil then
        Broadcast(1, Comms.DataMsg(1, current_data)) 
        current_data = nil -- send once
    end

    -- receive messages
    local disconnected_client_IDs = {}
    for ID, client in pairs(IdClientMap) do
        local line, err = Comms.ReceiveLine(client)
        if err == "closed" then
            table.insert(disconnected_client_IDs, ID)
        elseif line then
            Process(client, line)
        end
        
    end

    -- graceful disconnect
    for _,ID in pairs(disconnected_client_IDs) do
        Disconnect(ID)
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
