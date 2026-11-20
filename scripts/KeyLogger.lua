script_name("KeyLogger")
script_author("h")

require "moonloader"
vk = require "vkeys"
wm = require "windows.message"
ini = require "inicfg"
ffi = require "ffi"

ffi.cdef[[
	typedef unsigned long DWORD;
	DWORD GetTickCount();
]]

config = ini.load({
	m = {
		kl = false,
		kt = false
	}
}, "keylogger")

--#######-- CONFIG --#######--
limit = 7				 	-- Кол-во строк лога
col_default = 0x00FFFF	-- обычный цвет
col_pressed = 0xE0FFFF	-- цвет нажатия
font_name = "Arial"		-- Шрифт
font_size = 17			-- Размер

function main()
	assert(isSampLoaded(), "SA:MP was not loaded!")
	while not isSampAvailable() do wait(333) end
	sampAddChatMessage("{8B8B8B}[KeyLogger]:{8B8B8B} Автор: {8B8B8B}trawyuxlly{8B8B8B} | Активация: {8B8B8B}/kl", 0x8B8B8B)
	sampRegisterChatCommand("kl", function() 
		config.m.kl = not config.m.kl; ini.save(config, 'keylogger.ini')
		sampAddChatMessage("KeyLogger: {8B8B8B}" .. (config.m.kl and "Включен" or "Выключен"), col_pressed)
	end)
	sampRegisterChatCommand("kt", function() 
		config.m.kt = not config.m.kt; ini.save(config, 'keylogger.ini')
		sampAddChatMessage("KeyTimer: {8B8B8B}" .. (config.m.kt and "Включен" or "Выключен"), col_pressed)
	end)
	wait(-1)
end

local sw, sh = getScreenResolution()
local log = {}
local font = {
	renderCreateFont(font_name, font_size, 5),
	renderCreateFont(font_name, (font_size - 5) <= 0 and 1 or (font_size - 5), 5)
}

addEventHandler("onD3DPresent", function()
	local X = sw - 10
	local Y = sh - (renderGetFontDrawHeight(font[1]) + 3)
	if config.m.kl and #log > 0 then
		for i = #log, 1, -1 do 
			local keyname = vk.id_to_name(log[i][1])
			local color = getColorKey(i, log[i][1])
			local offset = 0

			if config.m.kt then
				local time = log[i + 1] and (log[i + 1][2] - log[i][2]) / 1000 or (ffi.C.GetTickCount() - log[i][2]) / 1000
				time = string.format("%.3f", time)
				renderFontDrawText(font[2], time, X - renderGetFontDrawTextLength(font[2], time), Y, color)
				offset = renderGetFontDrawTextLength(font[2], time) + 5
			end

			renderFontDrawText(font[1], keyname, (X - offset) - renderGetFontDrawTextLength(font[1], keyname), Y, color)
			Y = Y - renderGetFontDrawHeight(font[1]) * 0.8
		end
	end
end)

local mouse = {
	L = { [wm.WM_LBUTTONDOWN] = true, [wm.WM_LBUTTONDBLCLK] = true },
	R = { [wm.WM_RBUTTONDOWN] = true, [wm.WM_RBUTTONDBLCLK] = true },
	M = { [wm.WM_MBUTTONDOWN] = true, [wm.WM_MBUTTONDBLCLK] = true },
	X = { [wm.WM_XBUTTONDOWN] = true, [wm.WM_XBUTTONDBLCLK] = true }
}

addEventHandler("onWindowMessage", function(message, wp, lp)
	if config.m.kl and bit.band(lp, 0x40000000) == 0 then
		if message == wm.WM_KEYDOWN or message == wm.WM_SYSKEYDOWN then
	    	log_key(wp)
		else
			if mouse["L"][message] then log_key(vk.VK_LBUTTON) end
			if mouse["R"][message] then log_key(vk.VK_RBUTTON) end
			if mouse["M"][message] then log_key(vk.VK_MBUTTON) end
			if mouse["X"][message] then
				local X = bit.rshift(bit.band(wp, 0xffff0000), 16)
				if X == 1 then log_key(vk.VK_XBUTTON1) end
				if X == 2 then log_key(vk.VK_XBUTTON2) end
			end
		end
	end
end)

function log_key(key)
	log[#log + 1] = { key, ffi.C.GetTickCount() }
	while #log > limit do table.remove(log, 1) end
end

function getColorKey(i, keyId)
	if i == #log and isKeyDown(keyId) then
		return set_alpha(col_pressed, 200)
	elseif #log > (limit - 5) and i <= 5 then
		return set_alpha(col_default, i * 35)
	end 
	return set_alpha(col_default, 200)
end

function set_alpha(color, alpha)
	local r = bit.band(bit.rshift(color, 16), 0xFF)
	local g = bit.band(bit.rshift(color, 8), 0xFF)
	local b = bit.band(color, 0xFF)

	color = b
	color = bit.bor(color, bit.lshift(g, 8))
	color = bit.bor(color, bit.lshift(r, 16))
	color = bit.bor(color, bit.lshift(alpha, 24))
	return color
end