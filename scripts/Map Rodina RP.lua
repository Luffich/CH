script_name('Map Rodina RP')

require 'moonloader'

textures = {
	map = nil,
	cursor = nil,
	marker = nil
}

local zoom = 115.0

function main()
	while not isSampAvailable() do wait(0) end
	wait(1234)
	if not doesDirectoryExist("moonloader/map") then
		createDirectory("moonloader/map")
		thisScript():reload()
	end
	if doesFileExist('moonloader/map/map.png') or not doesFileExist('moonloader/map/cursor.png') or not doesFileExist('moonloader/map/marker.png') then
		textures.map = renderLoadTextureFromFile("moonloader/map/map.png")
		textures.cursor = renderLoadTextureFromFile("moonloader/map/cursor.png")
		textures.marker = renderLoadTextureFromFile("moonloader/map/marker.png")
	else
		thisScript():unload()
	end
	while true do
		wait(0)

		if isKeyDown(VK_XBUTTON1) and not sampIsCursorActive() then
			map_render = true
		else;
			map_render = false
		end

		if map_render and not sampIsCursorActive() then
			zoom = zoom + getMousewheelDelta()*6
		end

		renderMap()
	end
end

function renderMap(mode)
	if map_render then
		if not sampIsDialogActive() and not sampIsScoreboardOpen() then
			local mapSize = {getMapSize()}

			local myPos = {getCharCoordinates(playerPed)}
			local player_max_id = sampGetMaxPlayerId(false)
			local closest_player = -1
			local closest_distance = math.huge

			renderDrawTexture(textures.map, mapSize[1], mapSize[2], mapSize[3], mapSize[3], 0, join_argb(200,255,255,255))

			local my_x,my_y = convertCoord(myPos[1],myPos[2])
			renderDrawTexture(textures.cursor, my_x-7.5,my_y-7.5, 15,15, (getCharHeading(PLAYER_PED)-getCharHeading(PLAYER_PED)-360-getCharHeading(PLAYER_PED)), join_argb(255,255,255,255))



			for _, v in ipairs(getAllChars()) do
				local r,id = sampGetPlayerIdByCharHandle(v)
				if r and doesCharExist(v) and v ~= PLAYER_PED and not sampIsPlayerNpc(id) then
				local cx,cy,cz = getCharCoordinates(v)
					local x,y = convertCoord(cx,cy)
					local color = clist(155,id)
					if (cz) > myPos[3] + 5 then
						renderDrawPolygon(x, y, 21, 21, 3, 0, 0xFF000000)
						renderDrawPolygon(x, y, 15, 15, 3, 0, color)
					elseif (cz) < myPos[3] - 5 then
						renderDrawPolygon(x, y, 21, 21, 3, 180, 0xFF000000)
						renderDrawPolygon(x, y, 15, 15, 3, 180, color)
					else
						renderDrawBox(x - 6, y - 6, 12, 12, 0xFF000000)
						renderDrawBox(x - 5, y - 5, 10, 10, color)
					end
				end
			end

			local blip = {getTargetBlipCoordinates()}
			if blip[1] then
				local x,y = convertCoord(blip[2],blip[3])
				renderDrawTexture(textures.marker, x-12.5,y-12.5, 25,25, 0, join_argb(155,255,255,255))	
			end

			local marker = {SearchMarker(true)}
			if marker[1] then
				local marker_x,marker_y = convertCoord(marker[2],marker[3])
				renderDrawBox(marker_x-1, marker_y-1, 12, 12, 0xFF000000)
				renderDrawBox(marker_x, marker_y, 10, 10, join_argb(155,250,60,60))
			end

		end

	end
end

function join_argb(a, r, g, b) local argb = b argb = bit.bor(argb, bit.lshift(g, 8)) argb = bit.bor(argb, bit.lshift(r, 16)) argb = bit.bor(argb, bit.lshift(a, 24)) return argb end
function explode_argb(argb) local a = bit.band(bit.rshift(argb, 24), 0xFF) local r = bit.band(bit.rshift(argb, 16), 0xFF) local g = bit.band(bit.rshift(argb, 8), 0xFF) local b = bit.band(argb, 0xFF) return a, r, g, b end
function clist(alpha,id)
	local aa, rr, gg, bb = explode_argb(sampGetPlayerColor(id))
	return join_argb(255, rr, gg, bb)
end


function convertCoord(xx,yy)

	local function limitToMap(x, y)
		if x > 3000 then
			x = 3000
		elseif x < -3000 then
			x = -3000
		end
		if y > 3000 then
			y = 3000
		elseif y < -3000 then
			y = -3000
		end
		return x, y
	end

	local mapSize = {getMapSize()}

	local multiplier = mapSize[3] / 6000

	local bottom_y = mapSize[2] + mapSize[3]
	local bottom_x = mapSize[1] + mapSize[3]
	local wx, wy = limitToMap((xx), (yy))
	local x = mapSize[1] + (wx + 3000) * multiplier
	local y = mapSize[2] + mapSize[3] - (wy + 3000) * multiplier
	return x,y
end

function getMapSize()
	local sh, sw = getScreenResolution()
	local map_size = math.floor(sw * 0.8)
	sw = sw - (zoom*4.5)
	map_size = map_size + zoom
	local top_x = sh / 2 - map_size / 2
	local top_y = sw * 0.1

	return top_x,top_y,map_size
end

function SearchMarker(isRace)
    local ret_posX = 0.0
    local ret_posY = 0.0
    local ret_posZ = 0.0
    local isFind = false

    for id = 0, 31 do
        local MarkerStruct = 0
        if isRace then MarkerStruct = 0xC7F168 + id * 56
        else MarkerStruct = 0xC7DD88 + id * 160 end
        local MarkerPosX = representIntAsFloat(readMemory(MarkerStruct + 0, 4, false))
        local MarkerPosY = representIntAsFloat(readMemory(MarkerStruct + 4, 4, false))
        local MarkerPosZ = representIntAsFloat(readMemory(MarkerStruct + 8, 4, false))

        if MarkerPosX ~= 0.0 or MarkerPosY ~= 0.0 or MarkerPosZ ~= 0.0 then
            ret_posX = MarkerPosX
            ret_posY = MarkerPosY
            ret_posZ = MarkerPosZ
            isFind = true
        end
    end

    return isFind, ret_posX, ret_posY, ret_posZ
end