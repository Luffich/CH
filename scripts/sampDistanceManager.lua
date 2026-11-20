__name__	= "SA-MP Distance Manager"
__version__ = "0.4"
__author__	= "lay3r"

local inicfg = require 'inicfg'

local settingsFile = 'sampDistanceManager.ini'
local mainIni = inicfg.load({
		distance = 
			{
				nametags = 8,
				tdtext = 8,
				chatbubbles = 6,
				fog = 350,
				lods = 150
			}
}, settingsFile)
if not doesFileExist('moonloader/config/'..settingsFile) then inicfg.save(mainIni, settingsFile) end

local memory = require 'memory'
local sampev = require 'lib.samp.events'
local imgui = require 'imgui'
local ffi = require 'ffi'

local fog_dist = ffi.cast('float *', 0x00B7C4F0)
local lods_dist = ffi.cast('float *', 0x00858FD8)

local show_main_window = imgui.ImBool(false)
local nametags_dist_slider = imgui.ImInt(mainIni.distance.nametags)
local tdtext_dist_slider = imgui.ImInt(mainIni.distance.tdtext)
local chatbubbles_dist_slider = imgui.ImInt(mainIni.distance.chatbubbles)
local fog_dist_slider = imgui.ImInt(mainIni.distance.fog)
local lods_dist_slider = imgui.ImInt(mainIni.distance.lods)

function imgui.OnDrawFrame()
	if show_main_window.v then
		local sw, sh = getScreenResolution()
		imgui.SetNextWindowPos(imgui.ImVec2(sw / 2, sh / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
		imgui.SetNextWindowSize(imgui.ImVec2(345, 160), imgui.Cond.FirstUseEver)
		imgui.Begin(__name__..' (v'..__version__..')', show_main_window, imgui.WindowFlags.NoCollapse + imgui.WindowFlags.NoResize)
		if imgui.SliderInt('NAMETAGS', nametags_dist_slider, 0, nametags_allowed_dist) then
			set_dist(0, nametags_dist_slider.v)
		end
		if imgui.SliderInt('3D TEXT', tdtext_dist_slider, 0, 30) then
			set_dist(1, tdtext_dist_slider.v)
		end
		if imgui.SliderInt('CHAT BUBBLES', chatbubbles_dist_slider, 0, 30) then
			set_dist(2, chatbubbles_dist_slider.v)
		end
		if imgui.SliderInt('FOG', fog_dist_slider, 0, 3600) then
			set_dist(3, fog_dist_slider.v)
		end
		if imgui.SliderInt('LODS', lods_dist_slider, 0, 1000) then
			set_dist(4, lods_dist_slider.v)
		end
		imgui.End()
	end
end

function main()
	if not isSampfuncsLoaded() or not isSampLoaded() then return end
    while not isSampAvailable() do wait(100) end
	sampRegisterChatCommand('sdm', function() 
		if sampGetGamestate() ~= 3 then
			sampAddChatMessage('Wait for connection', -1)
		else
			show_main_window.v = not show_main_window.v	
		end
	end)
	set_dist(3, mainIni.distance.fog)
	set_dist(4, mainIni.distance.lods)
	while true do
		wait(0)
		imgui.Process = show_main_window.v
		if sampGetGamestate() == 2 then
			while sampGetGamestate() ~= 3 do wait(100) end
			nametags_server_settings = sampGetServerSettingsPtr() + 39
			nametags_allowed_dist = get_dist(0)
			set_dist(0, mainIni.distance.nametags)
		end
	end
end

function get_dist(number)
	if number == 0 then
		return memory.getfloat(nametags_server_settings)
	end
	if number == 1 then
		return mainIni.distance.tdtext
	end
	if number == 2 then
		return mainIni.distance.chatbubbles
	end
	if number == 3 then
		return fog_dist[0]
	end
	if number == 4 then
		return lods_dist[0]
	end
end

function set_dist(number, value)
	value = tonumber(value)
	if number == 0 then
		if show_main_window.v and sampGetGamestate() == 3 then
			mainIni.distance.nametags = value
			inicfg.save(mainIni, settingsFile)
		end
		if value > nametags_allowed_dist or value < 0 then
			return memory.setfloat(nametags_server_settings, nametags_allowed_dist)
		else
			return memory.setfloat(nametags_server_settings, value)
		end
	end
	if number == 1 then
		if show_main_window.v then
			for i=0, 2048 do
				if sampIs3dTextDefined(i) then
				local text, col, posX, posY, posZ, dist, los, plid, vehid = sampGet3dTextInfoById(i)
					sampCreate3dTextEx(i, text, col, posX, posY, posZ, value, los, plid, vehid)
				end
			end
			mainIni.distance.tdtext = value
			inicfg.save(mainIni, settingsFile)
		end
	end
	if number == 2 then
		if show_main_window.v then
			mainIni.distance.chatbubbles = value
			inicfg.save(mainIni, settingsFile)
		end
	end
	if number == 3 then
		if value > 3600.0 or value < 0 then return false end
		fog_dist[0] = value
		mainIni.distance.fog = value
		inicfg.save(mainIni, settingsFile)
	end
	if number == 4 then
		if value > 1000.0 or value < 0 then return false end
		lods_dist[0] = value
		mainIni.distance.lods = value
		inicfg.save(mainIni, settingsFile)
	end
end

function sampev.onCreate3DText(id, col, pos, allowed_dist, los, plid, vehid, text)
	local custom_dist = mainIni.distance.tdtext
	if custom_dist < allowed_dist then
		return {id, col, pos, custom_dist, los, plid, vehid, text}
	end
end

function sampev.onPlayerChatBubble(id, col, allowed_dist, dur, text)
	local custom_dist = mainIni.distance.chatbubbles
	if custom_dist < allowed_dist then
		return {id, col, custom_dist, dur, text}
	end
end