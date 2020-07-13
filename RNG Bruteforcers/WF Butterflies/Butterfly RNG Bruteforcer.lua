--[[

	Author: Xander
	Date: June 2019

	This was used for Task 10 of the 2019 TAS Competition (https://youtu.be/zUIfRJVYqfU)
	It aims to get a butterfly to spawn a 1up as close to the fence as possible.

	This code is directly based off of Nis' bruteforcer for Task 2 of the 2018 TAS Competition (https://youtu.be/rxbb4Kf4AsE)
	Nis' video: https://youtu.be/BVrF8V6wL2w
	Original script: https://pastebin.com/0AsbqWqw

	Fatal flaw: on line 148, I cap the butterfly's coords. They need to be reachable
	while standing on the ground but I believe this cap might be too small.

]]

RNG = require "RNG"
-- rr: +100
-- Max - 65219 = 65535 - 65219 = 316
-- 380
-- test 65310 (5039), 284 (5006)
local marioX_addr = 0x00B3B1AC -- TODO fix these values
local marioY_addr = 0x00B3B1B0
local marioZ_addr = 0x00B3B1B4
local coins = 0x00B3B218
local stars = 0x00B3B21A
local goomba1Y = 0x00B5C0CC
local goomba2Y = 0x00B4F6EC
local speed = 0x00B3B1C4
local gTimer = 0x00B2D5D4

local object_addr = 0xB3D488
local offset = 0x260
local graphicsOffset = 0x14
local butterfly_graphic = 0x800F9160

local varx = 0
local varz = 0
local vary = 0

local xOffset = 0xA0
local yOffset = 0xA4
local zOffset = 0xA8

local homeOffset = {}
homeOffset.x = 0x164
homeOffset.y = 0x168
homeOffset.z = 0x16C

local frame = 0
local endFrame = 400 --388
RNG.value = -1 + 782 -- set the starting value
local path = "D:/lua.st"
local restart = true

local minDist = 1000000
local minRNG = 0

local home = {}
home.x = 4574
home.y = 300
home.z = 1130

local b1 = {}
local b2 = {}
local maxX = 0


function main()

    -- Start condition
	if (restart) then
        restart = false
        frame = 0

        RNG.increment()
		if RNG.value > RNG.maxValue then
			print ("All "..RNG.maxValue.." values tested!")
			frame = endFrame+1
		end

		savestate.loadfile(path)

	elseif (frame == 1) then
	    memory.writeword(RNG.address, RNG.value) --65310
	    memory.writeword(stars, RNG.value)
		frame = frame + 2 -- adjust to match actual frame


    	--[[ End condition

		teleport mario to the butterfly
		store bfly coords
		frame advance
		if it hasnt moved then it spawns 1up, set new min

		--]]


	elseif (frame == 388) then

		setButterflies()

		if validPos(b1.x,b1.y,b1.z) then
			teleportToObj(b1.addr)
			--print("Teleport to 1 "..b1.x)
		end
		--print("398 "..b2.x)

	elseif (frame == 389) then

		-- check if 1st has 1up
		if hasMoved(b1.addr,b1.x,b1.y,b1.z)==false then
			maxX = b1.x
			print("1: "..maxX.." RNG: "..RNG.value)
		end

	elseif (frame == 390) then

		-- move to 2nd
		if validPos(b2.x,b2.y,b2.z) then
			teleportToObj(b2.addr)
			b1.x = b2.x -- store the original X val
			b2.x = memory.readfloat(b2.addr+xOffset)
			b2.y = memory.readfloat(b2.addr+yOffset)
			b2.z = memory.readfloat(b2.addr+zOffset)
			--print("Teleport to 2 "..b2.x)
		end

	elseif (frame == 391) then
		--print("400 "..memory.readfloat(b2.addr+xOffset))
		-- check if 2nd has 1up
		if hasMoved(b2.addr,b2.x,b2.y,b2.z)==false then
			maxX = b1.x -- b1 b/c it stored the val on frame 387
			print("2: "..maxX.." RNG: "..RNG.value)
		end

		--elseif (frame == 400) then
		restart = true

	end

	frame = frame + 1
end

function validPos(x,y,z)
	return 45<z and z<2300 and maxX<x and x<5071 and y<256+161 and x>4146
end


function hasMoved(objAddr, x, y, z)

	if memory.readfloat(objAddr+xOffset) == x and memory.readfloat(objAddr+yOffset) == y and memory.readfloat(objAddr+zOffset) == z then
		return false
	else
		return true
	end

end


function teleportToObj(objAddr)
	teleport(memory.readfloat(objAddr+xOffset), memory.readfloat(objAddr+yOffset), memory.readfloat(objAddr+zOffset))
end

function teleport(x, y, z)
	memory.writefloat(marioX_addr, x)
	--memory.writefloat(marioY_addr, y)
	memory.writefloat(marioZ_addr, z)
end


function setButterflies()

	b1.x=0
	b1.y=0
	b1.z=0
	b1.dist = 0
	b1.addr = 0
	b2.x=0
	b2.y=0
	b2.z=0
	b2.dist = 0
	b2.addr = 0

	dist = 0

    for slot=0, 250 do

		obj = object_addr+offset*slot

        if (memory.readdword(obj + graphicsOffset) == butterfly_graphic) and  -- right graphic
		memory.readfloat(obj + homeOffset.y) == home.y and -- right home coords
		memory.readfloat(obj+homeOffset.z) == home.z and
		not(memory.readfloat(obj+0x144) == 4) then -- subtype can't be 4

			x = memory.readfloat(obj + xOffset)
			y = memory.readfloat(obj + yOffset)
			z = memory.readfloat(obj + zOffset)

			dist = math.sqrt(x*x+y*y+z*z)

			if b1.x == 0 then
				b1.x=x
				b1.y=y
				b1.z=z
				b1.dist=dist
				b1.addr = object_addr+offset*slot
			else
				b2.x=x
				b2.y=y
				b2.z=z
				b2.dist=dist
				b2.addr = object_addr+offset*slot
			end

		end

    end

end

function findRed()
    for slot=0, 239 do
        if (memory.readdword(object_addr+offset*slot + 0x14) == 0x800F9C24 and memory.readfloat(object_addr+offset*slot + 0xA0) == -6560) then
            redAddr = (0x0B3D488+0x260*z+0x74)
        end
    end
end

--emu.atvi(fn)
emu.atinput(main)

--[[ check goomba vals ?? by nis
	elseif (j == 2400) then

   for z=0, 250 do
	if (memory.readdword(0xB3D694+0x260*z) == 2148459252) then
	--print("Found bob slot "..z.." behavior: "..memory.readdword(0xB3D694+0x260*z).."")
	varz = memory.readfloat(0xB3D530+0x260*z)
	vary = memory.readfloat(0xB3D52C+0x260*z)
	if (varz < -3671) then
		if (vary < -1550 and vary > -3500) then
			print("RNG value "..i..":, Slot "..z.." Bob fell at "..memory.readfloat(0xB3D52C+0x00000260*z).."")
		end
	end
	end
   end
--]]

function dist(x1, y1, x2, y2)
	dx = x2-x2
	dy = y2-y1
	return math.sqrt(dx*dx + dy*dy)
end
