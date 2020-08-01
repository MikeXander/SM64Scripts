--[[
    Handles editing the savestate file for "Freeze frames"
    Author: Eddio0141
]]

File = {}

local PATH = debug.getinfo(1).source:sub(2):match("(.*\\)")
--local Cam = require "Camera" -- Cam must be loaded before this file

-- no error checking
function ReverseTable(t)
	local newT = {}
	for i = #t, 1, -1 do
		table.insert(newT, t[i])
	end
	return newT
end

-- also almost no error checking because optimization
local pow = math.pow
local floor = math.floor
local function GetByteArray(var, lengthInBytes, isLittleEndian, isSigned)
	--if type(var) ~= "number" or type(lengthInBytes) ~= "number" or type(isLittleEndian) ~= "boolean" then return nil end
	if lengthInBytes < 1 then return nil end
	local bytesLimit = pow(256, lengthInBytes)
	if isSigned then
		var = var + bytesLimit / 2
	end
	if var > bytesLimit then
		var = bytesLimit
	elseif var < 0 then
		var = 0
	end

	local t = {}
	local currentNum
	for i = lengthInBytes, 1, -1 do
		currentNum = floor(var / pow(0x100, i - 1))
		var = var - currentNum * pow(0x100, i - 1)
		t[#t + 1] = currentNum
	end
	if isLittleEndian then
		t = ReverseTable(t)
	end
	return t
end

local function FlipTable(t)
	local t2 = {}
	for i = #t, 1, -1 do
		t2[#t2 + 1] = t[i]
	end
	return t2
end

local function OverWriteByteArrayToFileLittleEndian(bytes, address, fileHandle)
	bytes = FlipTable(bytes)
	fileHandle:seek("set", address)
	for _, v in pairs(bytes) do
		fileHandle:write(string.char(v))
	end
end

-- stFileHandle has to be in r+b mode
local function WriteRenderCameraInFile(camstruct, stFileHandle)
	local tempWriteAddr = Cam.GetRenderCameraAddress()
	local originalTempAddrValue = memory.readfloat(tempWriteAddr)
	local fileWritePATHOffset = 0x1b0
	local floatVarArray
	local writeContent = {
		camstruct.x,
		camstruct.y,
		camstruct.z,
		camstruct.xfocus,
		camstruct.yfocus,
		camstruct.zfocus,
	}

	for i, v in pairs(writeContent) do
		if v then
			-- hacky float to bytes conversion
			memory.writefloat(tempWriteAddr, v)
			floatVarArray = GetByteArray(memory.readdword(tempWriteAddr), 4, false, false)
			OverWriteByteArrayToFileLittleEndian(floatVarArray, fileWritePATHOffset + tempWriteAddr - 0x800000 + ((i - 1) * 4), stFileHandle)
		end
	end

	-- restore original value
	memory.writefloat(tempWriteAddr, originalTempAddrValue)
end

function File.SetCamPosToFile(stFileHandle, pos)
    WriteRenderCameraInFile({
        x = pos[1],
        y = pos[2],
        z = pos[3],
        xfocus = nil,
        yfocus = nil,
        zfocus = nil
    }, stFileHandle)
end

-- It replaces the st file with the uncompressed one
function File.ExtractSTFileWith7z()
	-- extract it into dir "extracted"
	os.execute("\"\"" .. PATH .. "7z.exe\" e \"" .. PATH .. "frame.st\" -o\"" .. PATH .. "extracted/\" -aoa -y > nul\"")
	os.remove(PATH .. "frame.st")
	os.rename(PATH .. "extracted\\frame", PATH .. "frame.st")
	os.execute("\"RD /S /Q \"" .. PATH .. "extracted\" \"")
end
