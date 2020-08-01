Helper = {}

function string.findlast(s, pattern, plain)
	local curr = 0
	repeat
		local next = s:find(pattern, curr + 1, plain)
		if (next) then curr = next end
	until (not next)
	if (curr > 0) then
		return curr
	end	
end

function Helper.FileExists(path)
	local f = io.open(path, "r")
	if f~=nil then io.close(f) return true else return false end
end

function Helper.GetFileExtension(strFilename)
	if not Helper.FileExists(strFilename) then return "" end
	if not string.match(strFilename, ".") then
		return ""
	end
	return strFilename:match"\.[^.\\/:*?\"<>|\r\n]+$"
end

--[[
   Save Table to File
   Load Table from File
   v 1.0
   
   Lua 5.2 compatible
   
   Only Saves Tables, Numbers and Strings
   Insides Table References are saved
   Does not save Userdata, Metatables, Functions and indices of these
   ----------------------------------------------------
   table.save( table , filename )
   
   on failure: returns an error msg
   
   ----------------------------------------------------
   table.load( filename or stringtable )
   
   Loads a table that has been saved via the table.save function
   
   on success: returns a previously saved table
   on failure: returns as second argument an error msg
   ----------------------------------------------------
   
   Licensed under the same terms as Lua itself.
]]--
do
   -- declare local variables
   --// exportstring( string )
   --// returns a "Lua" portable version of the string
   local function exportstring( s )
      return string.format("%q", s)
   end

   --// The Save Function
   function table.save(  tbl,filename )
      local charS,charE = "   ","\n"
      local file,err = io.open( filename, "wb" )
      if err then return err end

      -- initiate variables for save procedure
      local tables,lookup = { tbl },{ [tbl] = 1 }
      file:write( "return {"..charE )

      for idx,t in ipairs( tables ) do
         file:write( "-- Table: {"..idx.."}"..charE )
         file:write( "{"..charE )
         local thandled = {}

         for i,v in ipairs( t ) do
            thandled[i] = true
            local stype = type( v )
            -- only handle value
            if stype == "table" then
               if not lookup[v] then
                  table.insert( tables, v )
                  lookup[v] = #tables
               end
               file:write( charS.."{"..lookup[v].."},"..charE )
            elseif stype == "string" then
               file:write(  charS..exportstring( v )..","..charE )
            elseif stype == "number" then
               file:write(  charS..tostring( v )..","..charE )
            end
         end

         for i,v in pairs( t ) do
            -- escape handled values
            if (not thandled[i]) then
            
               local str = ""
               local stype = type( i )
               -- handle index
               if stype == "table" then
                  if not lookup[i] then
                     table.insert( tables,i )
                     lookup[i] = #tables
                  end
                  str = charS.."[{"..lookup[i].."}]="
               elseif stype == "string" then
                  str = charS.."["..exportstring( i ).."]="
               elseif stype == "number" then
                  str = charS.."["..tostring( i ).."]="
               end
            
               if str ~= "" then
                  stype = type( v )
                  -- handle value
                  if stype == "table" then
                     if not lookup[v] then
                        table.insert( tables,v )
                        lookup[v] = #tables
                     end
                     file:write( str.."{"..lookup[v].."},"..charE )
                  elseif stype == "string" then
                     file:write( str..exportstring( v )..","..charE )
                  elseif stype == "number" then
                     file:write( str..tostring( v )..","..charE )
                  end
               end
            end
         end
         file:write( "},"..charE )
      end
      file:write( "}" )
      file:close()
   end
   
   --// The Load Function
   function table.load( sfile )
      local ftables,err = loadfile( sfile )
      if err then return _,err end
      local tables = ftables()
      for idx = 1,#tables do
         local tolinki = {}
         for i,v in pairs( tables[idx] ) do
            if type( v ) == "table" then
               tables[idx][i] = tables[v[1]]
            end
            if type( i ) == "table" and tables[i[1]] then
               table.insert( tolinki,{ i,tables[i[1]] } )
            end
         end
         -- link indices
         for _,v in ipairs( tolinki ) do
            tables[idx][v[2]],tables[idx][v[1]] =  tables[idx][v[1]],nil
         end
      end
      return tables[1]
   end
-- close do
end

function Helper.BoolToString(bool)
	if bool then
		return "true"
	else
		return "false"
	end
end

function Helper.StringToBool(str)
	str = string.lower(str)
	return str == "true"
end

-- almost no error checking because performance
-- make sure the variables are what they are suppose to be
-- byteArray is an array of bytes
-- address is the offset to take value from
-- numOfBytes is the length to take
-- isLittleEndian is if the value is a little endian
-- isSigned is if the value is signed
local pow = math.pow
local UNPACK = unpack
function Helper.GetBytes(byteArray, address, numOfBytes, isLittleEndian, isSigned)
	-- check if theres enough bytes in byteArray
	if #byteArray - address < numOfBytes then return nil end
	-- byte limit is 8. I have to do this one
	if numOfBytes > 8 then return nil end
	local bytes = {UNPACK(byteArray, address + 1, address + numOfBytes)}
	if not isLittleEndian then
		bytes = Helper.ReverseTable(bytes)
	end
	local finalvar = bytes[1]
	for i = 2, #bytes, 1 do
		finalvar = finalvar + pow(0x100, i - 1) * bytes[i]
	end
	if isSigned then
		finalvar = finalvar - pow(256, numOfBytes) / 2
	end
	return finalvar
end

-- gets value from byte array
function Helper.GetBytes2(byteArray, isLittleEndian, isSigned)
	-- byte limit is 8. I have to do this one
	if #byteArray > 8 then return nil end
	if not isLittleEndian then
		byteArray = Helper.ReverseTable(byteArray)
	end
	local finalvar = byteArray[1]
	for i = 2, #byteArray, 1 do
		finalvar = finalvar + pow(0x100, i - 1) * byteArray[i]
	end
	if isSigned then
		finalvar = finalvar - pow(256, #byteArray) / 2
	end
	return finalvar
end

-- also almost no error checking because optimization
local floor = math.floor
function Helper.GetByteArray(var, lengthInBytes, isLittleEndian, isSigned)
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
		t = Helper.ReverseTable(t)
	end
	return t
end

-- no error checking
function Helper.ReverseTable(t)
	local newT = {}
	for i = #t, 1, -1 do
		table.insert(newT, t[i])
	end
	return newT
end

function Helper.BytesToASCII(bytes, address, length)
	if not bytes then return nil end
	if type(bytes) ~= "table" then return nil end
	if #bytes < 1 then return "" end
	bytes = {unpack(bytes, address + 1, address + length)}
	local str = ""
	for _, chByte in pairs(bytes) do
		str = str .. string.char(chByte)
	end
	return str
end

function Helper.BytesToASCII2(bytes)
	if not bytes then return nil end
	if type(bytes) ~= "table" then return nil end
	if #bytes < 1 then return "" end
	local str = ""
	for _, chByte in pairs(bytes) do
		str = str .. string.char(chByte)
	end
	return str
end

function Helper.ASCIIToBytes(str, lengthPad)
	if not str then return nil end
	if type(str) ~= "string" or type(lengthPad) ~= "number" then return nil end
	if str == "" then return {} end
	local bytes = {}
	for ch in str:gmatch"." do
		table.insert(bytes, string.byte(ch))
	end
	if #bytes < lengthPad then
		for i = 1, lengthPad - #bytes, 1 do
			table.insert(bytes, 0)
		end
	end
	return bytes
end

function Helper.BytesToUTF8(bytes, address, length)
	if not bytes then return nil end
	if type(bytes) ~= "table" then return nil end
	if #bytes < 1 then return "" end
	bytes = {unpack(bytes, address + 1, address + length)}
	local bytearr = {}
	for _, v in ipairs(bytes) do
		local utf8byte = v < 0 and (0xff + v + 1) or v
		table.insert(bytearr, string.char(utf8byte))
	end
	return table.concat(bytearr)
end

function Helper.BytesToUTF82(bytes)
	if not bytes then return nil end
	if type(bytes) ~= "table" then return nil end
	if #bytes < 1 then return "" end
	local bytearr = {}
	for _, v in ipairs(bytes) do
		local utf8byte = v < 0 and (0xff + v + 1) or v
		table.insert(bytearr, string.char(utf8byte))
	end
	return table.concat(bytearr)
end

-- no error checking
function Helper.IsInt(num)
	return num == math.floor(num)
end

function Helper.GetByteArrayFromFile(path)
	if not Helper.FileExists(path) then return nil end
	local file = assert(io.open(path, "rb"))
	local t = {}
	local str = ""
	repeat
		str = file:read(1)
		if str then t[#t+1] = string.byte(str) end
	until not str
	file:close()
	return t
end

function Helper.GetByteArrayFromFileInRange(file, address, lengthInBytes)
	file:seek("set", address)
	local str = ""
	local t = {}
	for i = 1, lengthInBytes, 1 do
		str = file:read(1)
		if str then t[#t+1] = string.byte(str) else break end
	end
	return t
end

function Helper.MergeTables(t1, t2)
	if type(t1) ~= "table" or type(t2) ~= "table" then return nil end
	for _, v in pairs(t2) do
		table.insert(t1, v)
	end
	return t1
end

function Helper.Sleep(seconds)
	local tim = os.clock()
	while os.clock() - tim <= seconds do end
end

function Helper.GetFilename(p)
	local i = p:findlast("[/\\]")
	if (i) then
		return p:sub(i + 1)
	else
		return p
	end
end

-- big thanks to Xander I was stuck here for TWO WEEKS because of a simple mistake
function Helper.WriteByteArrayToFile(bytes, path)
	if type(bytes) ~= "table" or type(path) ~= "string" then return end
	local f = io.open(path, "wb")
	for _, v in pairs(bytes) do
		f:write(string.char(v))
	end
	f:close()
end

-- u have to do with ab mode for the filehandle
function Helper.AppendByteArrayToFile(bytes, fileHandle)
	for _, v in pairs(bytes) do
		fileHandle:write(string.char(v))
	end
end

function Helper.CopyFile(sauce, dest)
	if not Helper.FileExists(sauce) then return nil end
	if type(dest) ~= "string" then return nil end
	Helper.WriteByteArrayToFile(Helper.GetByteArrayFromFile(sauce), dest)
end

function Helper.DeepCopyTable(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[Helper.DeepCopyTable(orig_key, copies)] = Helper.DeepCopyTable(orig_value, copies)
            end
            setmetatable(copy, Helper.DeepCopyTable(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    return copy
end

-- only will take the first file in the extracted folder
function Helper.ExtractFileWith7z(path, outputPath)
	if type(path) ~= "string" then return nil end
	if type(outputPath) ~= "string" then return nil end
	if not Helper.FileExists(path) then return nil end
	os.execute("\"\"" .. RESOURCE .. "7z.exe\" e \"" .. path .. "\" -o\"" .. RESOURCE .. "extracted\" -aoa -y > nul\"")
	os.rename(RESOURCE .. "extracted\\" .. Helper.GetFilename(Helper.GetFilePathWithoutExtension(path)), outputPath)
	os.execute("\"RD /S /Q \"" .. RESOURCE .. "extracted\"\"")
end

-- gzip
function Helper.CompressFileWith7z(path, outputPath)
	if type(path) ~= "string" then return nil end
	if type(outputPath) ~= "string" then return nil end
	if not Helper.FileExists(path) then return nil end
	os.execute("\"\"" .. RESOURCE .. "7z.exe\" a \"" .. outputPath .. "\" \"" .. path .. "\" -tgzip -aoa -y > nul\"")
	os.remove(path)
end

function Helper.GetFilePathWithoutExtension(path)
	if type(path) ~= "string" then return nil end
	local ext = Helper.GetFileExtension(path)
	if not ext then return path end
	return string.sub(path, 1, string.len(path) - string.len(ext))
end

function Helper.GetFileName(path)
	local start, finish = path:find('[%w%s!-={-|]+[_%.].+')
	return path:sub(start,#path)
end

function Helper.GetTimeInMS()
	os.execute("\"\"" .. RESOURCE .. "get time in ms.exe\"\"")
	local f = io.open(RESOURCE .. "timeInMS", "r")
	local ms = f:read()
	f:close()
	os.remove(RESOURCE .. "timeInMS")
	return tonumber(ms)
end

function Helper.GetFileSize(file)
	local currentPos = file:seek()
	local size = file:seek("end")
	file:seek("set", currentPos)
	return size
end