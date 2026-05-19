--[[
    Handles editing camera within .st files
    Author: Eddio0141
	Note: this avoids error checking for performance
]]


local PATH = debug.getinfo(1).source:sub(2):match("(.*\\)")
local LibDeflate = dofile(PATH .. "utils\\LibDeflate.lua")
local Camera = dofile(PATH .. "Camera.lua")

local File = {
	Savepath = PATH
}

local pow = math.pow
local floor = math.floor

local function ReverseTable(t)
	local newT = {}
	for i = #t, 1, -1 do
		table.insert(newT, t[i])
	end
	return newT
end

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
	local tempWriteAddr = Camera.GetRenderCameraAddress()
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

function File.SetRenderPosition(stFileHandle, camera_position, focus_position)
    if focus_position == nil then
		WriteRenderCameraInFile({
			x = camera_position[1],
			y = camera_position[2],
			z = camera_position[3],
			xfocus = nil,
			yfocus = nil,
			zfocus = nil
		}, stFileHandle)
		return
	end
	WriteRenderCameraInFile({
        x = camera_position[1],
        y = camera_position[2],
        z = camera_position[3],
        xfocus = focus_position[1],
        yfocus = focus_position[2],
        zfocus = focus_position[3]
    }, stFileHandle)
end

-- this replaces the st file with an uncompressed one (with no extension)
function File.ExtractSavestateWithLibDeflate(filename)
    local f = io.open(File.Savepath .. filename .. ".st", "rb")
    local data = f:read("*all")
    f:close()
    local out = io.open(File.Savepath .. filename .. ".st", "wb")
    local decompressed = LibDeflate:DecompressDeflate(data:sub(11, #data-8))
	out:write(decompressed)
	out:close()
end

-- A significantly faster way to extract a savestate.
-- It doesn't work in all environments though.
function File.ExtractSavestateWith7z(filename)
	os.execute("7z.exe e \"" .. File.Savepath .. filename .. ".st\" -o\"" .. File.Savepath .. "\" -aoa -y > nul\"")
	os.remove(File.Savepath .. filename .. ".st")
	os.rename(File.Savepath .. filename, File.Savepath .. filename .. ".st")
end

return File
