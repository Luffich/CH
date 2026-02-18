script_author('CaJlaT')
script_name('Keyboard & Mouse')
script_version('3.1.1')
local wm = require('lib.windows.message')
local inicfg = require 'inicfg'
local res, imgui = pcall(require, 'mimgui') assert(res, 'Ошибка, установите mimgui')
local res, ti = pcall(require, 'tabler_icons') assert(res, 'Ошибка, установите tabler-icons')
local mLoad, monet = pcall(require, 'MoonMonet') if not mLoad then print('Для работоспособности темы "MoonMonet", нужна библиотека MoonMonet') end
local ffi = require 'ffi'
local encoding = require 'encoding'
encoding.default = 'CP1251'
local u8 = encoding.UTF8
local new, str, sizeof = imgui.new, ffi.string, ffi.sizeof
local iniFile = 'keyboard.ini'
local ini = inicfg.load({
	config = {
		active = false,
		mode = 0,
		move = true,
		theme = 0,
		rounding = true,
		size = 1.0,
	},
	mouse = {
		active = false,
		x = 10,
		y = 200,
		size = 1.0,
		move = true
	},
	pos = {
		x = 10,
		y = 500
	},
	cStyle = {
		mainColor = 0xcc000000,
		activeColor = 0xcc993066,
		borderColor = 0xff993066,
		textColor = 0xffffffff
	},
	monet = {
		mainColor = 0xcc993066,
		brightness = 1.0
	},
	rainbowMode = {
		active = false,
		speed = 1.0,
		async = false
	},
	logging = {
		active = false,
		enableTimeout = false,
		timeout = 5,
		highlight = false
	}
}, iniFile)
if not doesDirectoryExist(getWorkingDirectory()..'\\config') then print('Creating the config directory') createDirectory(getWorkingDirectory()..'\\config') end
if not doesFileExist('moonloader/config/'..iniFile) or not ini.cStyle or not ini.monet then print('Creating/updating the .ini file') inicfg.save(ini, iniFile) end

local keyboardsDir = getWorkingDirectory().."\\config\\keyboards.json"
function json(filePath)
	local f = {}

	function f:read()
		local file = io.open(filePath, 'r')
		local jsonInString = file:read("*a")
		file:close()
		local jsonTable = decodeJson(jsonInString)
		return jsonTable
	end

	function f:write(t)
		file = io.open(filePath, "w")
		file:write(encodeJson(t))
		file:flush()
		file:close()
	end

	return f
end

local ui_meta = { -- by Cosmo
	__index = function(self, v)
		if v == "switch" then
			local switch = function()
				if self.process and self.process:status() ~= "dead" then
					return false -- // Предыдущая анимация ещё не завершилась!
				end
				self.timer = os.clock()
				self.state = not self.state

				self.process = lua_thread.create(function()
					local bringFloatTo = function(from, to, start_time, duration)
						local timer = os.clock() - start_time
						if timer >= 0.00 and timer <= duration then
							local count = timer / (duration / 100)
							return count * ((to - from) / 100)
						end
						return (timer > duration) and to or from
					end

					while true do wait(0)
						local a = bringFloatTo(0.00, 1.00, self.timer, self.duration)
						self.alpha = self.state and a or 1.00 - a
						if a == 1.00 then break end
					end
				end)
				return true -- // Состояние окна изменено!
			end
			return switch
		end
 
		if v == "alpha" then
			return self.state and 1.00 or 0.00
		end
	end
}


local keyboards = {}
local keyLog = {}
local date = os.date('%d.%m.%Y')



local settings = { state = false, duration = 0.3 }
setmetatable(settings, ui_meta)

local logging = {
	active = new.bool(ini.logging.active),
	enableTimeout = new.bool(ini.logging.enableTimeout),
	timeout = new.int(ini.logging.timeout),
	highlight = new.bool(ini.logging.highlight)
}


local keyboard = new.bool(ini.config.active)
local mouse = new.bool(ini.mouse.active)
local keyboard_type = new.int(ini.config.mode)
local keyboardMove = new.bool(ini.config.move)
local mouseMove = new.bool(ini.mouse.move)
local kPos = imgui.ImVec2(ini.pos.x, ini.pos.y)
local mPos = imgui.ImVec2(ini.mouse.x, ini.mouse.y)
local theme = new.int(ini.config.theme)
local rounding = new.bool(ini.config.rounding)
local kSize = new.float(ini.config.size)
local mSize = new.float(ini.mouse.size)

local cStyle = {} -- цвета для покраски
local cStyleEdit = {} -- цвета для ColorEdit
local monetColor = imgui.ImVec4(0,0,0,0)
local monetColorEdit = new.float[4](0, 0, 0, 0)
local monetBrightness = new.float(ini.monet.brightness)
local rainbowMode = {
	active = new.bool(ini.rainbowMode.active),
	speed = new.float(ini.rainbowMode.speed),
	async = new.bool(ini.rainbowMode.async)
}

local keyboardList = { arr =  {}, var = nil}
local addKey = {
	state = new.bool(false), 
	block = 0,
	line = 0
}
local addLine = false
local editElement = {
	state = new.bool(false),
	selected = new.int(0),
	block = 0,
	line = 0,
	key = 0,
	tKey = 0,
	keySize = {x = new.int(20), y = new.int(20)}
}

local wheel = {} -- Фикс отображения прокрута колеса
local gta = true -- Фикс улетания в левый верхний угол при сворачивании

function main()
	while not isSampAvailable() do wait(100) end
	getKeyboardsList()
	if not keyboards or #keyboards == 0 then return false end
	sampRegisterChatCommand('keyboard', settings.switch)
	lua_thread.create(logThread)
	printChat('Скрипт загружен и готов к работе. Автор: CaJlaT')
	while true do wait(0)
		local delta = getMousewheelDelta()
		if mouse[0] and delta ~= 0 then table.insert(wheel, {delta, os.clock()+0.05}) end -- Фикс отображения прокрута колеса
	end
end

function printChat(text) sampAddChatMessage(string.format('[{993066}%s v.%s{FFFFFF}]: %s', thisScript().name, thisScript().version, text), -1) end


function loadFonts(sizes)
	local fonts = {}
	local config = imgui.ImFontConfig()
	local iconfig = imgui.ImFontConfig()
	iconfig.OversampleH = 1
	config.OversampleH = 1
	iconfig.MergeMode = false
	config.MergeMode = true
	config.PixelSnapH = true
	imgui.GetIO().Fonts.Flags = 1
	local iconRanges = imgui.new.ImWchar[3](ti.min_range, ti.max_range, 0)
	imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(ti.get_font_data_base85(), 14, config, iconRanges) -- Обязательно
	for i, v in ipairs(sizes) do
		fonts[v] = imgui.GetIO().Fonts:AddFontFromFileTTF(getFolderPath(0x14) .. '\\trebucbd.ttf', v, iconfig, glyph_ranges)
		imgui.GetIO().Fonts:AddFontFromMemoryCompressedBase85TTF(ti.get_font_data_base85(), v, config, iconRanges)
	end
	return fonts
end

local fonts = {}

imgui.OnInitialize(function()
	local getfloat = function(r, g, b, a) return r/255, g/255, b/255, a/255 end
	for k, v in pairs(ini.cStyle) do
		local a, r, g, b = getfloat(explode_argb(ini.cStyle[k]))
		cStyle[k] = imgui.ImVec4(r, g, b, a)
		cStyleEdit[k] = new.float[4](r, g, b, a)
	end
	local a, r, g, b = getfloat(explode_argb(ini.monet.mainColor))
	monetColor = imgui.ImVec4(r, g, b, a)
	monetColorEdit = new.float[4](r, g, b, a)
	imgui.GetIO().IniFilename = nil
	defaultStyle()
	if not mLoad and theme[0] == 7 then
		theme[0] = 6
		print('Для работоспособности темы "MoonMonet", установите библиотеку MoonMonet')
		printChat('{FF0000}Ошибка, у вас не установлена библиотека "MoonMonet", тема была изменена на "Своя"')
		printChat('Для работоспособности темы "MoonMonet", установите библиотеку MoonMonet')
		printChat('Библиотеку можно найти на BLASTHACK.')
		printChat('Если вы играете на Arizona Launcher, просто переустановите скрипт во вкладке "Моды"')
	end
	glyph_ranges = imgui.GetIO().Fonts:GetGlyphRangesCyrillic()
	fonts = loadFonts({16})
	styles[theme[0]].func()
	keyColors = setKeyColors()
	logopng = imgui.CreateTextureFromFileInMemory(imgui.new('const char*', logo), #logo)
end)

local sX, xY = getScreenResolution()


local nav = {
	sel = new.int(1),
	list = { 
		{name = u8'Информация', icon =  ti.ICON_INFO_CIRCLE}, 
		{name = u8'Клавиатура', icon =  ti.ICON_KEYBOARD}, 
		{name = u8'Мышь', icon =  ti.ICON_MOUSE}, 
		{name = u8'Темы', icon =  ti.ICON_PALETTE}, 
		{name = u8'Своя клавиатура', icon =  ti.ICON_VECTOR},
		{name = u8'Лог нажатий', icon =  ti.ICON_CHECKUP_LIST},
	}
}

-- Клавиатура
imgui.OnFrame(function() return keyboard[0] and not isGamePaused() and gta and #keyboards > 0 end, function(player)
	player.HideCursor = not settings.state
end,
function(player)
	imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(5.0, 2.4)) -- Фикс положения клавиш
	imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0,0,0,0)) -- Убираем фон
	imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0.0) -- Убираем обводку окна
	imgui.SetNextWindowPos(kPos, imgui.Cond.FirstUseEver, imgui.ImVec2(0, 0))
	imgui.Begin('##keyboard', _, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize + (keyboardMove[0] and 0 or imgui.WindowFlags.NoInputs) )
		kPos = imgui.GetWindowPos()
		imgui.SetWindowFontScale(kSize[0])
		local spacing = imgui.GetStyle().ItemSpacing
		for ib, block in ipairs(keyboards[keyboard_type[0]+1].keyboard.blocks) do
			imgui.BeginGroup()
			for il, line in ipairs(block) do
				local y = imgui.GetCursorPosY()
				if #line == 0 then imgui.NewLine() else
					for i, key in ipairs(line) do
						if key.pos then
							local x = imgui.GetCursorPosX()
							imgui.SetCursorPosX((x+20*(kSize[0])*(key.pos-1))+spacing.x*(key.pos-1))
						end
						if not key.time then key.time = -1 end
						if isKeyDown(key.id) then key.time = os.clock() + 0.015 end
						renderKey(key)
						if i ~= #line then imgui.SameLine() end
					end
				end
				imgui.SetCursorPosY(y+20*kSize[0]+spacing.y)
			end
			imgui.EndGroup()
			imgui.SameLine()
		end
	imgui.End()
	imgui.PopStyleColor()
	imgui.PopStyleVar(2)
end)
local test = new.int(0)
-- Настройки
imgui.OnFrame(function() return settings.alpha > 0.00 and not isGamePaused() and gta and #keyboards > 0 end, function(player) 
	player.HideCursor = not settings.state
end,
function(player)
	local X, Y = getScreenResolution()
	imgui.SetNextWindowSize(imgui.ImVec2(822, 465), imgui.Cond.FirstUseEver)
	imgui.SetNextWindowPos(imgui.ImVec2(X / 2, Y / 2), imgui.Cond.FirstUseEver, imgui.ImVec2(0.5, 0.5))
	imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, settings.alpha)
	imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
	imgui.Begin('##Settings', _, imgui.WindowFlags.NoTitleBar)
		imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(8, 8))
		imgui.DrawMenu(nav)
		imgui.SameLine()
		imgui.BeginChild('##main', imgui.ImVec2(0, 0), true)
			local y = imgui.GetCursorPosY()
			if nav.sel[0] == 1 then
				imgui.PushFont(fonts[16])
				imgui.Text(u8'Приветствую, это новое меню настроек скрипта.')
				imgui.Text(u8'? Почему меню настроек теперь такого вида?')
				imgui.Text(u8'- В старое не влез бы редактор клавиатуры и кое-кому не нравилось старое меню')
				imgui.Text(u8'? Почему при изменении размера текст мылится?')
				imgui.Text(u8'- Другого нормального способа изменения размера шрифта я не нашёл :(')
				imgui.PopFont()
				imgui.TextDisabled(u8'Список изменений:')
				imgui.BeginChild('Changelog', imgui.ImVec2(-1, -90))
					for i, v in ipairs(changelog) do
						imgui.PushFont(fonts[16]) imgui.TextDisabled(u8('v'..v.version)) imgui.PopFont()
						imgui.Text(u8(v.description))
					end
					imgui.NewLine()
				imgui.EndChild()
			elseif nav.sel[0] == 2 then
				imgui.Checkbox(u8'Включить возможность перемещения клавиатуры', keyboardMove)
				imgui.Checkbox(u8'Включить отображение клавиатуры', keyboard)
				imgui.Combo(u8'Тип клавиатуры', keyboard_type, keyboardList.var, #keyboardList.arr)
				if imgui.SliderFloat(u8'Размер клавиатуры', kSize, 0.5, 2.0) then 
					kFontChanged = true
				end
				if imgui.AnimatedButton(u8'Сбросить размер', imgui.ImVec2(-1, 0), 0.5, true) then kSize[0], kFontChanged = 1.0, true end
			elseif nav.sel[0] == 3 then
				imgui.Checkbox(u8'Включить возможность перемещения мыши', mouseMove)
				imgui.Checkbox(u8'Включить мышь', mouse)
				if imgui.SliderFloat(u8'Размер мыши', mSize, 0.5, 2.0) then mFontChanged = true end
				if imgui.AnimatedButton(u8'Сбросить размер', imgui.ImVec2(-1, 0), 0.5, true) then mSize[0], mFontChanged = 1.0, true end
			elseif nav.sel[0] == 4 then
				imgui.Text(u8'Выберите тему:')
				for i = 0, #styles do
					if imgui.ThemeSelector(styles[i].name, i, theme) then
						theme[0] = i
						keyColors = setKeyColors()
						if not mLoad and theme[0] == 7 then
							theme[0] = 6
							print('Для работоспособности темы "MoonMonet", установите библиотеку MoonMonet')
							printChat('{FF0000}Ошибка, у вас не установлена библиотека "MoonMonet", тема была изменена на "Своя"')
							printChat('Для работоспособности темы "MoonMonet", установите библиотеку MoonMonet')
							printChat('Библиотеку можно найти на BLASTHACK.')
							printChat('Если вы играете на Arizona Launcher, просто переустановите скрипт во вкладке "Моды"')
						end
						styles[theme[0]].func()
					end
					imgui.Hint('theme##'..i, string.format(u8'Тема: {DISABLED}%s{/DISABLED}', styles[i].name), 0.05)
					if i ~= #styles then imgui.SameLine() end
				end
				if imgui.Checkbox(u8'Скругление клавиш', rounding) then defaultStyle() end
				imgui.NewLine()
				imgui.BeginTitleChild2(u8'Кастомная тема', imgui.ImVec2(imgui.GetWindowWidth()/2-11, 115), imgui.GetStyle().Colors[imgui.Col.ButtonActive])
					if imgui.ColorEdit4(u8'Цвет кнопки', cStyleEdit['mainColor'], imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.AlphaPreviewHalf + imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
						keyColors = setKeyColors()
					end
					imgui.SameLine() imgui.Text(u8'Цвет кнопки')
					if imgui.ColorEdit4(u8'Цвет нажатия', cStyleEdit['activeColor'], imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.AlphaPreviewHalf + imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
						keyColors = setKeyColors()
					end
					imgui.SameLine() imgui.Text(u8'Цвет Нажатия')
					if imgui.ColorEdit4(u8'Цвет обводки', cStyleEdit['borderColor'], imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.AlphaPreviewHalf + imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
						keyColors = setKeyColors()
					end
					imgui.SameLine() imgui.Text(u8'Цвет Обводки')
					if imgui.ColorEdit4(u8'Цвет  текста', cStyleEdit['textColor'], imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.AlphaPreviewHalf + imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
						keyColors = setKeyColors()
					end
					imgui.SameLine() imgui.Text(u8'Цвет текста')
				imgui.EndChild() 
				imgui.SameLine()
				imgui.BeginTitleChild2(u8'Тема MoonMonet', imgui.ImVec2(imgui.GetWindowWidth()/2-11, 115), imgui.GetStyle().Colors[imgui.Col.ButtonActive])
					if not mLoad then
						imgui.TextDisabled(u8'У вас не установлена библиотека MoonMonet')
						imgui.Hint('moonmonet', u8'Нажмите, чтобы получить\nболее подробную информацию', 0.05, function()
							print('Для работоспособности темы "MoonMonet", установите библиотеку MoonMonet')
							printChat('Для работоспособности темы "MoonMonet", установите библиотеку MoonMonet')
							printChat('Библиотеку можно найти на BLASTHACK.')
							printChat('Если вы играете на Arizona Launcher, просто переустановите скрипт во вкладке "Моды"')
						end)
					end
					if imgui.ColorEdit4(u8'Основной цвет', monetColorEdit, imgui.ColorEditFlags.AlphaBar + imgui.ColorEditFlags.AlphaPreviewHalf + imgui.ColorEditFlags.NoInputs + imgui.ColorEditFlags.NoLabel) then 
						monetColor = imgui.ImVec4(monetColorEdit[0],monetColorEdit[1],monetColorEdit[2],monetColorEdit[3])
						styles[theme[0]].func()
					end
					imgui.SameLine() imgui.Text(u8'Основной цвет')
					if imgui.SliderFloat(u8'Яркость цветов', monetBrightness, 0.5, 2.0) then styles[theme[0]].func() end
				imgui.EndChild()
				imgui.Checkbox(u8'Переливающиеся нажатые клавиши', rainbowMode.active)
				imgui.Checkbox(u8'Разные цвета', rainbowMode.async)
				imgui.SliderFloat(u8'Скорость переливания', rainbowMode.speed, 0.0, 20.0)
			elseif nav.sel[0] == 5 then
				local w = imgui.GetWindowWidth()
				imgui.Text(u8'В этой вкладке можно настроить отображение "своей" клавиатуры')
				imgui.Text(u8'Для изменения/удаления элемента, нажмите на нём пкм')
				if imgui.AnimatedButton(u8'Добавить блок', imgui.ImVec2((w-25)/3, 0), 0.5, true)  then
					table.insert(keyboards[#keyboards].keyboard.blocks, {})
				end
				imgui.SameLine()
				if imgui.AnimatedButton(u8'Добавить Линию', imgui.ImVec2((w-25)/3, 0), 0.5, true) then
					addLine = true
					printChat('Выберите блок, в который нужно добавить линию')
				end
				imgui.SameLine()
				if imgui.AnimatedButton(u8'Добавить клавишу', imgui.ImVec2((w-25)/3, 0), 0.5, true) then 
					addKey.state[0] = true 
					printChat('Выберите линию, на которую нужно добавить клавишу')
				end
				imgui.Spacing()
				imgui.BeginTitleChild(u8'Редактор клавиатуры', imgui.ImVec2(-1, imgui.GetWindowHeight()-105))
				local spacing = imgui.GetStyle().ItemSpacing
				local blocks = keyboards[#keyboards].keyboard.blocks
				for ib, block in ipairs(blocks) do
					local maxSize = getBlockMaxSize(block)
					imgui.BeginTitleChild(u8'Блок #'..ib, imgui.ImVec2(maxSize.x+20, -1), imgui.GetStyle().Colors[imgui.Col.Button])
					for il, line in ipairs(block) do
						local maxHeight = getLineMaxHeight(line)
						imgui.Spacing()
						imgui.BeginTitleChild2(u8'Линия #'..il, imgui.ImVec2(-1, maxHeight), imgui.GetStyle().Colors[imgui.Col.ButtonActive], 8)
						local y = imgui.GetCursorPosY()
						if #line == 0 then imgui.NewLine() else
							for i, key in ipairs(line) do
								if key.pos then
									local x = imgui.GetCursorPosX()
									imgui.SetCursorPosX((x+20*(kSize[0])*(key.pos-1))+spacing.x*key.pos-1)
								end
								if isKeyDown(key.id) then key.time = os.clock() + 0.015 end
								renderKey(key, _, true)
								if imgui.IsItemHovered() then
									if addKey.state[0] and (imgui.IsItemClicked() or imgui.IsItemClicked(1)) then
										imgui.OpenPopup(u8'Добавить клавишу') 
										addKey.block, addKey.line = ib, il
									elseif imgui.IsItemClicked(1) and not editElement.state[0] then 
										imgui.OpenPopup(u8'Изменить элемент')
										editKeyboard = tableCopy(keyboards[1].keyboard)
										editElement.state[0] = true
										editElement.block = ib
										editElement.line = il
										editElement.key = i
										editElement.keySize = key.size and {x = new.int(key.size.x), y = new.int(key.size.y)} or {x = new.int(20), y = new.int(20)}
										editElement.keyPos = new.float((key.pos and key.pos-1 or 0))
										editElement.tKey = key
									end
								end
								if i ~= #line then
									imgui.SameLine()
								end
							end
						end
						editKeyPopups()
						imgui.EndChild()
						if imgui.IsItemHovered() then
							if addKey.state[0] and (imgui.IsItemClicked() or imgui.IsItemClicked(1)) then
								imgui.OpenPopup(u8'Добавить клавишу') 
								addKey.block, addKey.line = ib, il
							elseif not editElement.state[0] and imgui.IsItemClicked(1) then
								imgui.OpenPopup(u8'Изменить элемент')
								editElement.state[0] = true
								editElement.block = ib
								editElement.line = il
								editElement.key = 0
							end
						end
					end
					editKeyPopups()
					imgui.EndChild()
					if imgui.IsItemHovered() then
						if addLine and (imgui.IsItemClicked() or imgui.IsItemClicked(1)) then
							table.insert(keyboards[#keyboards].keyboard.blocks[ib], {})
							addLine = false
						elseif not editElement.state[0] and imgui.IsItemClicked(1) then
							imgui.OpenPopup(u8'Изменить элемент')
							editElement.state[0] = true
							editElement.block = ib
							editElement.line = 0
							editElement.key = 0
						end
					end
					imgui.SameLine()
				end
				editKeyPopups()

				imgui.EndChild()
			elseif nav.sel[0] == 6 then
				imgui.Checkbox(u8'Включить логирование нажатий клавиш', logging.active)
				imgui.Checkbox(u8'Использовать сохранение по времени', logging.enableTimeout)
				imgui.Hint('##enableTimeout', u8'Используйте, если у вас не сохраняются логи при выходе из игры', 0.1)
				if logging.enableTimeout[0] then
					imgui.SameLine()
					imgui.PushItemWidth(220)
					imgui.SliderInt(u8'Минуты', logging.timeout, 1, 60)
					imgui.Hint('##timeout', 
						u8('Интервал автоматического сохранения логов.\nТекущий интервал: {DISABLED}'..logging.timeout[0]..' минут{/DISABLED}'), 
						0.1
					)
					imgui.PopItemWidth()
				end
				imgui.Checkbox(u8'Подсвечивать нажатые клавиши', logging.highlight)
				imgui.Hint('##highlight', u8'Подсвечивать клавиши в логе, которые были нажаты хотя бы 1 раз', 0.1)
				imgui.BeginTitleChild(u8'Лог клавиш', imgui.ImVec2(-1, imgui.GetWindowHeight()-115))
					if not menuLog then menuLog, menuDate = getKeyLogs(_, true) end
					local spacing = imgui.GetStyle().ItemSpacing
					imgui.Text(u8'Нажатые клавиши') imgui.SameLine() imgui.TextDisabled(u8(menuDate))
					if imgui.AnimatedButton(u8'Обновить лог', _, 0.5, true) then 
						if keyLogs and #keyLogs > 0 then saveKeyLogs(date) end
						menuLog, menuDate = getKeyLogs(menuDate, true)
					end
					imgui.SameLine()
					if imgui.AnimatedButton(u8'Загрузить лог за всё время', _, 0.5, true) then
						local files = getFilesInPath(getWorkingDirectory()..'\\config\\keyboard', '*.json')
						if #files == 0 then
							return printChat('Ошибка, логи не найдены')
						end
						printChat('Загрузка логов за всё время...')
						menuLog, menuDate = getKeyLogs('Всё время', true)
						printChat('Логи за всё время загружены.')
					end
					for ib, block in ipairs(keyboards[1].keyboard.blocks) do
						imgui.BeginGroup()
						for il, line in ipairs(block) do
							local y = imgui.GetCursorPosY()
							if #line == 0 then imgui.NewLine() else
								for i, key in ipairs(line) do
									if key.pos then
										local x = imgui.GetCursorPosX()
										imgui.SetCursorPosX((x+20*(key.pos-1))+spacing.x*key.pos-1)
									end
									if not key.time then key.time = -1 end
									local keylog = getTableByValue(menuLog, key.id, 'id')
									renderKey(key, _, true, (logging.highlight[0] and keylog.pressed > 0 or false))
									local text = string.format(u8[[
Клавиша: {DISABLED}%s{/DISABLED}
Вы нажали эту клавишу {DISABLED}%d{/DISABLED} %s
Минимальное время нажатия: {DISABLED}%s{/DISABLED}
Максимальное время нажатия: {DISABLED}%s{/DISABLED}
Общее время нажатия: {DISABLED}%s{/DISABLED}]], 
										(key.name == ' ' and 'Space' or key.name),
										keylog.pressed, u8(plural(keylog.pressed, {'раз', 'раза', 'раз'})),
										u8(timeFormat(keylog.timeMin)),
										u8(timeFormat(keylog.timeMax)),
										u8(timeFormat(keylog.timeTotal)),
										keylog.timeTotal
									)
									imgui.Hint('keyLogs##'..key.id..key.name, text, 0.1)
									if i ~= #line then imgui.SameLine() end
								end
							end
							imgui.SetCursorPosY(y+20+spacing.y)
						end
						imgui.EndGroup()
						if ib ~= #keyboards[1].keyboard.blocks then imgui.SameLine() end
					end
					local y = imgui.GetCursorPosY()
					imgui.SameLine()
					local pos = imgui.GetCursorPos()
					for il, line in ipairs(mouse_keys) do
						if il == 2 then imgui.SetCursorPos(imgui.ImVec2(pos.x, pos.y+50*mSize[0]+spacing.y*2)) end
						imgui.BeginGroup()
						for i, key in ipairs(line) do
							if key.name == 'MMB' then renderWheel()
								imgui.SetCursorPosY(pos.y+13*mSize[0]+spacing.y)
							elseif key.name == 'RMB' then
								imgui.SetCursorPosY(pos.y+2.2)
							end
							if isKeyDown(key.id) then key.time = os.clock() + 0.015 end
							local keylog = getTableByValue(menuLog, key.id, 'id')
							renderKey(key, true, true, (logging.highlight[0] and keylog.pressed > 0 or false))
							local text = string.format(u8[[
Клавиша: {DISABLED}%s{/DISABLED}
Вы нажали эту клавишу {DISABLED}%d{/DISABLED} %s
Минимальное время нажатия: {DISABLED}%s{/DISABLED}
Максимальное время нажатия: {DISABLED}%s{/DISABLED}
Общее время нажатия: {DISABLED}%s{/DISABLED}]], 
								(key.name == ' ' and 'Space' or key.name),
								keylog.pressed, u8(plural(keylog.pressed, {'раз', 'раза', 'раз'})),
								u8(timeFormat(keylog.timeMin)),
								u8(timeFormat(keylog.timeMax)),
								u8(timeFormat(keylog.timeTotal))
							)
							imgui.Hint('keyLogs##'..key.id..key.name, text, 0.1)
							if i ~= #line then imgui.SameLine() end
						end
						imgui.EndGroup()
					end
					imgui.SetCursorPosY(y)
					imgui.BeginChild(u8'Выбрать дату')
					if imgui.CollapsingHeader(u8'Выбрать дату') then
						local files = getFilesInPath(getWorkingDirectory()..'\\config\\keyboard', '*.json')
						table.sort(files, function(a, b)
							local function time(date) return os.time({day = date:sub(1,2), month = date:sub(4,5), year = date:sub(7,10)}) end
							return time(a) > time(b)
						end)
						for i, v in ipairs(files) do
							local fDate = v:gsub('%.json', '')
							if imgui.AnimatedButton(u8(fDate), imgui.ImVec2(-1, 0), 0.5, true) then
								menuLog, menuDate = getKeyLogs(fDate)
							end
						end
					end
					imgui.EndChild()
				imgui.EndChild()
			end
			if nav.sel[0] <= 4 then
				imgui.PushFont(fonts[16])
					imgui.SetCursorPosY(imgui.GetWindowHeight()-90)
					imgui.Text(ti.ICON_HEART..u8' Всем спасибо, всех люблю '..ti.ICON_HEART)
					imgui.Text(ti.ICON_INFO_SQUARE_ROUNDED..u8' Теперь доступно в Arizona Launcher '..ti.ICON_INFO_SQUARE_ROUNDED)
					imgui.Link('https://vk.com/lvsmods', ti.ICON_LINK..u8' Группа автора (тех.поддержка) '..ti.ICON_LINK)
				imgui.PopFont()
			end
			imgui.SetCursorPos(imgui.ImVec2(10, imgui.GetWindowHeight()-30))
			if imgui.AnimatedButton(u8'Сохранить настройки', imgui.ImVec2(-1, 0), 0.5, true) then 
				iniSave()
				printChat('Настройки успешно сохранены')
			end
			imgui.SetCursorPos(imgui.ImVec2(imgui.GetWindowWidth()-28, y))
			if imgui.CloseButton(20, 2) then settings.switch() end
		imgui.EndChild()
		imgui.PopStyleVar()
	imgui.End()
	imgui.PopStyleVar(2)
end)

-- Мышь
imgui.OnFrame(function() return mouse[0] and not isGamePaused() and gta and #keyboards > 0 end, function(player)
	player.HideCursor = not settings.state
end,
function(player)

	imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(5.0, 2.4)) -- Фикс положения клавиш
	imgui.PushStyleColor(imgui.Col.WindowBg, imgui.ImVec4(0,0,0,0)) -- Убираем фон
	imgui.PushStyleVarFloat(imgui.StyleVar.WindowBorderSize, 0.0) -- Убираем обводку окна
	imgui.SetNextWindowPos(mPos, imgui.Cond.FirstUseEver, imgui.ImVec2(0, 0))
	imgui.Begin('##mouse', _, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar + imgui.WindowFlags.AlwaysAutoResize + (mouseMove[0] and 0 or imgui.WindowFlags.NoInputs) )
		mPos = imgui.GetWindowPos()
		imgui.SetWindowFontScale(mSize[0])
		local spacing = imgui.GetStyle().ItemSpacing
		local y = imgui.GetCursorPosY()
		for il, line in ipairs(mouse_keys) do
			if il == 2 then imgui.SetCursorPosY(y+50*mSize[0]+spacing.y*2) end
			imgui.BeginGroup()
			for i, key in ipairs(line) do
				if key.name == 'MMB' then renderWheel()
					imgui.SetCursorPosY(15*mSize[0]+spacing.y)
				elseif key.name == 'RMB' then
					imgui.SetCursorPosY(2.2)
				end
				if isKeyDown(key.id) then key.time = os.clock() + 0.015 end
				renderKey(key, true)
				if i ~= #line then imgui.SameLine() end
			end
			imgui.EndGroup()
		end
	imgui.End()
	imgui.PopStyleColor()
	imgui.PopStyleVar(2)
end)


function editKeyPopups()
	local spacing = imgui.GetStyle().ItemSpacing
	if imgui.BeginPopupModal(u8'Добавить клавишу', addKey.state, imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize) then
		imgui.Text(string.format(u8'Добавить клавишу в блок #%s, на линии #%s', addKey.block, addKey.line))
		for ib, block in ipairs(keyboards[1].keyboard.blocks) do
			imgui.BeginGroup()
			for il, line in ipairs(block) do
				local y = imgui.GetCursorPosY()
				if #line == 0 then imgui.NewLine() else
					for i, key in ipairs(line) do
						if key.pos then
							local x = imgui.GetCursorPosX()
							imgui.SetCursorPosX((x+20*(kSize[0])*(key.pos-1))+spacing.x*key.pos-1)
						end
						if not key.time then key.time = -1 end
						if isKeyDown(key.id) then key.time = os.clock() + 0.015 end
						renderKey(key)
						imgui.Hint('addKey##'..key.id..ib, string.format(u8'Нажмите, чтобы добавить клавишу{DISABLED}%s{/DISABLED}', (key.name == ' ' and 'Space' or key.name)), 0.1, callbackAddKey, key, addKey.block, addKey.line)
						if i ~= #line then imgui.SameLine() end
					end
				end
				imgui.SetCursorPosY(y+20*kSize[0]+spacing.y)
			end
			imgui.EndGroup()
			if ib ~= #keyboards[1].keyboard.blocks then imgui.SameLine() end
		end
		imgui.EndPopup()
	end
	if imgui.BeginPopupModal(u8'Изменить элемент', editElement.state, imgui.WindowFlags.NoResize + imgui.WindowFlags.AlwaysAutoResize) then
		if editElement.key ~= 0 then
			local key = keyboards[#keyboards].keyboard.blocks[editElement.block][editElement.line][editElement.key]
			imgui.Text(string.format(u8'Изменение клавиши #%s в блоке #%s на линии #%s', editElement.key, editElement.block, editElement.line))
			imgui.Text(u8'Чтобы ввести вручную, зажмите CTRL и нажмите на ползунок')
			imgui.SliderInt(u8'Ширина', editElement.keySize.x, 15, 180)
			imgui.SliderInt(u8'Высота', editElement.keySize.y, 15, 80)
			if key and not key.pos then
				if imgui.Button(u8'Добавить отступ', imgui.ImVec2(-1, 0)) then
					key.pos = 1
					editElement.keyPos = new.float(0)
				end
			elseif key and key.pos then
				if imgui.SliderFloat(u8'Отступ (количество клавиш)', editElement.keyPos, -10, 10) then
					key.pos = editElement.keyPos[0]+1.0
				end
				if imgui.Button(u8'Удалить отступ', imgui.ImVec2(-1, 0)) then
					key.pos = nil
					editElement.keyPos = new.float(0)
				end
			end
			imgui.Text(u8'Текущая клавиша:')
			renderKey(key)
			imgui.Text(u8'Новая клавиша:')
			renderKey({name = editElement.tKey.name, size = {x = editElement.keySize.x[0], y = editElement.keySize.y[0]}})
			if imgui.CollapsingHeader(u8'Выбрать новую клавишу') then
				for ib, block in ipairs(editKeyboard.blocks) do
					imgui.BeginGroup()
					for il, line in ipairs(block) do
						local y = imgui.GetCursorPosY()
						if #line == 0 then imgui.NewLine() else
							for i, key in ipairs(line) do
								if key.pos then
									local x = imgui.GetCursorPosX()
									imgui.SetCursorPosX((x+20*(key.pos-1))+spacing.x*key.pos-1)
								end
								if not key.time then key.time = -1 end
								if isKeyDown(key.id) then key.time = os.clock() + 0.015 end
								renderKey(key, _, true)
								imgui.Hint('addKey##'..key.id..ib, string.format(u8'Нажмите, чтобы изменить клавишу на{DISABLED}%s{/DISABLED}', (key.name == ' ' and 'Space' or key.name)), 0.1, callbackEditKey, key)
								if i ~= #line then imgui.SameLine() end
							end
						end
						imgui.SetCursorPosY(y+20+spacing.y)
					end
					imgui.EndGroup()
					if ib ~= #keyboards[1].keyboard.blocks then imgui.SameLine() end
				end
				if imgui.AnimatedButton(u8'Применить изменение клавиши', imgui.ImVec2(-1, 30), 0.5, true) then
					keyboards[#keyboards].keyboard.blocks[editElement.block][editElement.line][editElement.key] = editElement.tKey
				end
			end
			if imgui.AnimatedButton(u8'Применить изменение размера', imgui.ImVec2(-1, 30), 0.5, true) then
				key.size = {x = editElement.keySize.x[0], y = editElement.keySize.y[0]}
			end
			if imgui.AnimatedButton(u8'Удалить клавишу', imgui.ImVec2(-1, 30), 0.5, true) then
				table.remove(keyboards[#keyboards].keyboard.blocks[editElement.block][editElement.line], editElement.key)
				lua_thread.create(function()
					local start = os.clock()
					while os.clock() <= start + 0.5 do wait(0) end
					editElement.state[0] = false
					imgui.CloseCurrentPopup() 
				end)
			end
		elseif editElement.line ~= 0 then
			imgui.Text(string.format(u8'Изменить линию #%s в блоке #%s', editElement.line, editElement.block))
			if imgui.AnimatedButton(u8'Удалить линию', imgui.ImVec2(-1, 30), 0.5, true) then
				table.remove(keyboards[#keyboards].keyboard.blocks[editElement.block], editElement.line)
				lua_thread.create(function()
					local start = os.clock()
					while os.clock() <= start + 0.5 do wait(0) end
					editElement.state[0] = false
					imgui.CloseCurrentPopup() 
				end)
			end
			if imgui.AnimatedButton(u8'Отмена', imgui.ImVec2(-1, 30), 0.5, true) then
				lua_thread.create(function()
					local start = os.clock()
					while os.clock() <= start + 0.5 do wait(0) end
					editElement.state[0] = false
					imgui.CloseCurrentPopup() 
				end)
			end
		else
			imgui.Text(string.format(u8'Изменить БЛОК #%s', editElement.block))
			if imgui.AnimatedButton(u8'Добавить линию', imgui.ImVec2(-1, 30), 0.5, true) then
				table.insert(keyboards[#keyboards].keyboard.blocks[editElement.block], {})
			end
			if imgui.AnimatedButton(u8'Удалить блок', imgui.ImVec2(-1, 30), 0.5, true) then
				table.remove(keyboards[#keyboards].keyboard.blocks, editElement.block)
				lua_thread.create(function()
					local start = os.clock()
					while os.clock() <= start + 0.5 do wait(0) end
					editElement.state[0] = false
					imgui.CloseCurrentPopup() 
				end)
			end
			if imgui.AnimatedButton(u8'Отмена', imgui.ImVec2(-1, 30), 0.5, true) then
				lua_thread.create(function()
					local start = os.clock()
					while os.clock() <= start + 0.5 do wait(0) end
					editElement.state[0] = false
					imgui.CloseCurrentPopup() 
				end)
			end
		end
		imgui.EndPopup()
	end
end

function callbackAddKey(key, block, line)
	local add = tableCopy(key)
	add.pos = nil
	table.insert(keyboards[#keyboards].keyboard.blocks[block][line], add) 
end

function callbackEditKey(key) 
	editElement.tKey = tableCopy(key)
	editElement.tKey.pos = nil
end

function imgui.DrawMenu(menu)
	imgui.BeginGroup()
	imgui.SetCursorPos(imgui.ImVec2(41, 8))
	imgui.Image(logopng, imgui.ImVec2(63, 60), _, _, imgui.GetStyle().Colors[imgui.Col.TextDisabled])
	imgui.SetCursorPos(imgui.ImVec2(1, 70))
		imgui.PushFont(fonts[16])
		for i, v in ipairs(nav.list) do
			if imgui.CustomMenuItem(i, v, imgui.ImVec2(150, 40)) then nav.sel[0] = i end
		end
		imgui.PopFont()
		imgui.SetCursorPos(imgui.ImVec2(80-imgui.CalcTextSize('Keyboard & Mouse v.' .. thisScript().version).x/2, imgui.GetWindowHeight()-40))
		imgui.Text('Keyboard & Mouse v.' .. thisScript().version)
		imgui.SetCursorPosX(80-imgui.CalcTextSize('by CaJlaT').x/2)
		imgui.TextDisabled('by CaJlaT')
	imgui.EndGroup()
end

function imgui.CustomMenuItem(index, item, size, duration)
	local function bringVec4To(from, to, start_time, duration) -- by Cosmo
		local timer = os.clock() - start_time
		if timer >= 0.00 and timer <= duration then
			local count = timer / (duration / 100)
			return imgui.ImVec4(
				from.x + (count * (to.x - from.x) / 100),
				from.y + (count * (to.y - from.y) / 100),
				from.z + (count * (to.z - from.z) / 100),
				from.w + (count * (to.w - from.w) / 100)
			), true
		end
		return (timer > duration) and to or from, false
	end
	local function bringVec2To(from, to, start_time, duration) -- by Cosmo
		local timer = os.clock() - start_time
		if timer >= 0.00 and timer <= duration then
			local count = timer / (duration / 100)
			return imgui.ImVec2(
				from.x + (count * (to.x - from.x) / 100),
				from.y + (count * (to.y - from.y) / 100)
			), true
		end
		return (timer > duration) and to or from, false
	end
	local clr = {
		main = imgui.ImVec4(0,0,0,0),
		hovered = imgui.GetStyle().Colors[imgui.Col.ButtonHovered],
		active = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
	}
	local bool = false
	local DL = imgui.GetWindowDrawList()
	local p = imgui.GetCursorScreenPos()
	local w = imgui.GetWindowPos()
	local ts = imgui.CalcTextSize(item.icon..' '..item.name)
	if not CUSTOM_MENU_ANIMATIONS then CUSTOM_MENU_ANIMATIONS = {} end
	if not CUSTOM_MENU_ANIMATIONS[index] then 
		CUSTOM_MENU_ANIMATIONS[index] = {
			time = os.clock(),
			pos = imgui.ImVec2(p.x, p.y+size.y),
			pos2 = imgui.ImVec2(p.x, p.y+size.y),
			clr = imgui.ImVec4(0,0,0,0),
			hovered = false
		}
	end
	if imgui.InvisibleButton(item.name..'##'..index, size) and nav.sel[0] ~= index then 
		bool = true 
		CUSTOM_MENU_ANIMATIONS[index].time = os.clock()
		CUSTOM_MENU_ANIMATIONS[nav.sel[0]].time = os.clock()
	end
	local pool = CUSTOM_MENU_ANIMATIONS[index]
	if imgui.IsItemHovered() and not pool.hovered then
		pool.time = os.clock()
		pool.hovered = true
	elseif not imgui.IsItemHovered() and pool.hovered then
		pool.time = os.clock()
		pool.hovered = false
	end
	pool.clr = bringVec4To(
		pool.clr, 
		((nav.sel[0] == index or pool.hovered) and (pool.hovered and clr.hovered or clr.active) or clr.main), 
		pool.time, 
		pool.hovered and 0.8 or 1.5
	)
	pool.pos = bringVec2To(
		pool.pos, 
		((nav.sel[0] == index or pool.hovered) and imgui.ImVec2(p.x+size.x, p.y+size.y) or imgui.ImVec2(p.x, p.y+size.y)), 
		pool.time, 
		0.5
	)
	pool.pos2 = bringVec2To(
		pool.pos2, 
		((nav.sel[0] == index) and imgui.ImVec2(p.x+5, p.y+size.y) or imgui.ImVec2(p.x, p.y+size.y)), 
		pool.time, 
		0.5
	)
	local colors = {
		imgui.GetColorU32Vec4(pool.clr),
		imgui.GetColorU32Vec4(imgui.ImVec4(0,0,0,0))
	}
	DL:AddRectFilledMultiColor(imgui.ImVec2(w.x-25, p.y), CUSTOM_MENU_ANIMATIONS[index].pos, colors[1], colors[2], colors[2], colors[1]);
	DL:AddRectFilled(imgui.ImVec2(w.x, p.y), CUSTOM_MENU_ANIMATIONS[index].pos2, colors[1])
	DL:AddText(imgui.ImVec2(w.x+10, p.y + (size.y-ts.y)/2), -1, item.icon..' '..item.name)
	return bool
end

function imgui.CloseButton(size, thickness)
	local bool = false
	local DL = imgui.GetWindowDrawList()
	local p = imgui.GetCursorScreenPos()
	if imgui.InvisibleButton('##close', imgui.ImVec2(size, size)) then bool = true end
	local cColor = imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.Button])
	if imgui.IsItemHovered() then
		cColor = imgui.IsItemClicked() and imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.ButtonActive]) or imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.ButtonHovered])
		DL:AddLine(imgui.ImVec2(p.x+size/3.5, p.y+size/3.5), imgui.ImVec2(p.x+size/1.5, p.y+size/1.5), cColor, thickness)
		DL:AddLine(imgui.ImVec2(p.x+size/3.5, p.y+size/1.5), imgui.ImVec2(p.x+size/1.5, p.y+size/3.5), cColor, thickness)
	end
	DL:AddCircle(imgui.ImVec2(p.x+size/2,p.y+size/2),size/2, cColor, 20, thickness)
	return bool
end

function imgui.ThemeSelector(name, id, selected)
	local bool = false
	local DL = imgui.GetWindowDrawList()
	local p = imgui.GetCursorScreenPos()
	if imgui.InvisibleButton(ti.ICON_PALETTE..'##'..id, imgui.ImVec2(30, 30)) then bool = true end
	local colors = styles[id].buttonColors
	local color = colors.main
	if imgui.IsItemHovered() then
		color = imgui.IsAnyMouseDown() and colors.active or colors.hovered
	end
	if selected[0] == id then color = colors.active end
	if type(color) == 'table' then
		local mult = {}
		for i, v in ipairs(color) do
			mult[i] = imgui.GetColorU32Vec4(v)
		end
		DL:AddRectFilledMultiColor(p, imgui.ImVec2(p.x+30, p.y+30), mult[1], mult[2], mult[3], mult[4]);
	else 
		DL:AddRectFilled(p, imgui.ImVec2(p.x+30, p.y+30), imgui.GetColorU32Vec4(color), 6)
	end
	DL:AddText(imgui.ImVec2(p.x+8.5, p.y+8.5), -1, type(color) == 'table' and ti.ICON_COLOR_FILTER or ti.ICON_PALETTE)
	return bool
end

-- by Gorskin
function imgui.BeginTitleChild(str_id, size, colorBegin, colorText, colorLine, offset)
	colorBegin = colorBegin or imgui.GetStyle().Colors[imgui.Col.Button]
	colorText = colorText or imgui.ImVec4(1.00, 1.00, 1.00, 1.00)
	colorLine = colorLine or imgui.GetStyle().Colors[imgui.Col.Button]
	local DL = imgui.GetWindowDrawList()
	local posS = imgui.GetCursorScreenPos()
	local rounding = imgui.GetStyle().ChildRounding
	local title = str_id:gsub('##.+$', '')
	local sizeT = imgui.CalcTextSize(title)
	local bgColor = imgui.ColorConvertFloat4ToU32(imgui.GetStyle().Colors[imgui.Col.WindowBg])
	imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0, 0, 0, 0))
	imgui.BeginChild(str_id, size, true)
	imgui.SetCursorPos(imgui.ImVec2(0, 30))
	imgui.Spacing()
	imgui.PopStyleColor(1)
	size.x = size.x == -1.0 and imgui.GetWindowWidth() or size.x
	size.y = size.y == -1.0 and imgui.GetWindowHeight() or size.y
	offset = offset or (size.x-sizeT.x)/2
	DL:AddRect(posS, imgui.ImVec2(posS.x + size.x, posS.y + size.y), imgui.ColorConvertFloat4ToU32(colorLine), rounding, _, 1)
	DL:AddRectFilled(imgui.ImVec2(posS.x, posS.y), imgui.ImVec2(posS.x + size.x, posS.y + 25), imgui.ColorConvertFloat4ToU32(colorBegin), rounding, 1 + 2)
	DL:AddText(imgui.ImVec2(posS.x + offset, posS.y + 12 - (sizeT.y / 2)), imgui.ColorConvertFloat4ToU32(colorText), title)
end

--by Cosmo
function imgui.BeginTitleChild2(str_id, size, color, offset)
	color = color or imgui.GetStyle().Colors[imgui.Col.Border]
	offset = offset or 30
	local DL = imgui.GetWindowDrawList()
	local posS = imgui.GetCursorScreenPos()
	local rounding = imgui.GetStyle().ChildRounding
	local title = str_id:gsub('##.+$', '')
	local sizeT = imgui.CalcTextSize(title)
	local padd = imgui.GetStyle().WindowPadding
	local bgColor = imgui.ColorConvertFloat4ToU32(imgui.GetStyle().Colors[imgui.Col.WindowBg])
	--imgui.Spacing()

	imgui.PushStyleColor(imgui.Col.ChildBg, imgui.ImVec4(0, 0, 0, 0))
	imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0, 0, 0, 0))
	imgui.BeginChild(str_id, size, true)
	imgui.Spacing()
	imgui.PopStyleColor(2)

	size.x = size.x == -1.0 and imgui.GetWindowWidth() or size.x
	size.y = size.y == -1.0 and imgui.GetWindowHeight() or size.y
	DL:AddRect(posS, imgui.ImVec2(posS.x + size.x, posS.y + size.y), imgui.ColorConvertFloat4ToU32(color), rounding, _, 1)
	DL:AddLine(imgui.ImVec2(posS.x + offset - 3, posS.y), imgui.ImVec2(posS.x + offset + sizeT.x + 3, posS.y), bgColor, 3)
	DL:AddText(imgui.ImVec2(posS.x + offset, posS.y - (sizeT.y / 2)), imgui.ColorConvertFloat4ToU32(color), title)
end

function imgui.Hint(str_id, hint, delay, callback, ...) -- by Cosmo
	local hovered = imgui.IsItemHovered()
	local animTime = 0.2
	local delay = delay or 0.00
	local show = true
	if not allHints then allHints = {} end
	if not allHints[str_id] then
		allHints[str_id] = {
			status = false,
			timer = 0
		}
	end
	if hovered then
		for k, v in pairs(allHints) do
			if k ~= str_id and os.clock() - v.timer <= animTime  then
				show = false
			end
		end
		if callback and (imgui.IsItemClicked() or imgui.IsItemClicked(1)) then callback(...) end
	end
	if show and allHints[str_id].status ~= hovered then
		allHints[str_id].status = hovered
		allHints[str_id].timer = os.clock() + delay
	end
	if show then
		local between = os.clock() - allHints[str_id].timer
		if between <= animTime then
			local s = function(f)
				return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f)
			end
			local alpha = hovered and s(between / animTime) or s(1.00 - between / animTime)
			imgui.PushStyleVarFloat(imgui.StyleVar.Alpha, alpha)
			imgui.BeginTooltip()
				imgui.TextDisabled(ti.ICON_INFO_CIRCLE..u8' Подсказка')
				if hint:find('{DISABLED}') then
					for text in hint:gmatch('[^\r\n]+') do
						while text:find('(.-){DISABLED}(.-){/DISABLED}(.*)') do
							local a, b, c = text:match('(.-){DISABLED}(.-){/DISABLED}(.*)')
							text = c
							imgui.Text(a)
							imgui.SameLine(nil, 0)
							imgui.TextDisabled(b)
							imgui.SameLine(nil, 0)
						end
						imgui.Text(text)
					end
				else
					imgui.Text(hint)
				end
			imgui.EndTooltip()
			imgui.PopStyleVar()
		elseif hovered then
			imgui.BeginTooltip()
				imgui.TextDisabled(ti.ICON_INFO_CIRCLE..u8' Подсказка')
				if hint:find('{DISABLED}') then
					for text in hint:gmatch('[^\r\n]+') do
						while text:find('(.-){DISABLED}(.-){/DISABLED}(.*)') do
							local a, b, c = text:match('(.-){DISABLED}(.-){/DISABLED}(.*)')
							text = c
							imgui.Text(a)
							imgui.SameLine(nil, 0)
							imgui.TextDisabled(b)
							imgui.SameLine(nil, 0)
						end
						imgui.Text(text)
					end
				else
					imgui.Text(hint)
				end
			imgui.EndTooltip()
		end
	end
end

function imgui.Link(link,name,myfunc) -- by neverlane (Cosmo)
	myfunc = type(name) == 'boolean' and name or myfunc or false
	name = type(name) == 'string' and name or type(name) == 'boolean' and link or link
	local size = imgui.CalcTextSize(name)
	local p = imgui.GetCursorScreenPos()
	local p2 = imgui.GetCursorPos()
	local resultBtn = imgui.InvisibleButton('##'..link..name, size)
	if resultBtn then
		if not myfunc then
			os.execute('start '..link)
		end
	end
	imgui.SetCursorPos(p2)
	if imgui.IsItemHovered() then
		imgui.TextColored(imgui.GetStyle().Colors[imgui.Col.ButtonHovered], name)
		imgui.GetWindowDrawList():AddLine(imgui.ImVec2(p.x, p.y + size.y), imgui.ImVec2(p.x + size.x, p.y + size.y), imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.ButtonHovered]))
	else
		imgui.TextColored(imgui.GetStyle().Colors[imgui.Col.Button], name)
	end
	return resultBtn
end

function imgui.AnimatedButton(label, size, speed, rounded)
	local rounding = rounded and imgui.GetStyle().FrameRounding or 0
	local size = size or imgui.ImVec2(0, 0)
	local bool = false
	local text = label:gsub('##.+$', '')
	local ts = imgui.CalcTextSize(text)
	speed = speed and speed or 0.4
	local p = imgui.GetCursorScreenPos()
	local c = imgui.GetCursorPos()
	if not AnimatedButtons then AnimatedButtons = {} end
	local color = imgui.GetStyle().Colors[imgui.Col.ButtonHovered]
	if not AnimatedButtons[label] then
		AnimatedButtons[label] = {circles = {}, hovered = false, state = false, time = os.clock(), color = imgui.ImVec4(color.x, color.y, color.z, 0.2)}
	end
	local button = AnimatedButtons[label]
	if button.color.x ~= color.x or button.color.y ~= color.y or button.color.z ~= color.z then
		button.color = imgui.ImVec4(color.x, color.y, color.z, button.color.w)
	end
	local CalcItemSize = function(size, width, height)
		local region = imgui.GetContentRegionMax()
		if (size.x == 0) then
			size.x = width
		elseif (size.x < 0) then
			size.x = math.max(4.0, region.x - c.x + size.x);
		end
		if (size.y == 0) then
			size.y = height;
		elseif (size.y < 0) then
			size.y = math.max(4.0, region.y - c.y + size.y);
		end
		return size
	end
	size = CalcItemSize(size, ts.x+imgui.GetStyle().FramePadding.x*2, ts.y+imgui.GetStyle().FramePadding.y*2)
	imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0,0))
	imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, rounding)
	imgui.BeginChild('button##'..label, size, false, imgui.WindowFlags.NoScrollbar)
	local p = imgui.GetCursorScreenPos()
	local c = imgui.GetCursorPos()
	local dl = imgui.GetWindowDrawList()
	if imgui.InvisibleButton(label, size) then
		bool = true
		table.insert(button.circles, {animate = true, reverse = false, time = os.clock(), clickpos = imgui.ImVec2(getCursorPos())})
	end
	button.hovered = imgui.IsItemHovered()
	if button.hovered ~= button.state then
		button.state = button.hovered
		button.time = os.clock()
	end
	local ImSaturate = function(f) return f < 0.0 and 0.0 or (f > 1.0 and 1.0 or f) end
	if #button.circles > 0 then
		local PathInvertedRect = function(a, b, col)
			if rounding <= 0 or not rounded then return end
			local dl = imgui.GetWindowDrawList()
			dl:PathLineTo(a)
			dl:PathArcTo(imgui.ImVec2(a.x + rounding, a.y + rounding), rounding, -3.0, -1.5)
			dl:PathFillConvex(col)

			dl:PathLineTo(imgui.ImVec2(b.x, a.y))
			dl:PathArcTo(imgui.ImVec2(b.x - rounding, a.y + rounding), rounding, -1.5, -0.205)
			dl:PathFillConvex(col)

			dl:PathLineTo(imgui.ImVec2(b.x, b.y))
			dl:PathArcTo(imgui.ImVec2(b.x - rounding, b.y - rounding), rounding, 1.5, 0.205)
			dl:PathFillConvex(col)

			dl:PathLineTo(imgui.ImVec2(a.x, b.y))
			dl:PathArcTo(imgui.ImVec2(a.x + rounding, b.y - rounding), rounding, 3.0, 1.5)
			dl:PathFillConvex(col)
		end
		for i, circle in ipairs(button.circles) do
			local time = os.clock() - circle.time
			local t = ImSaturate(time / speed)
			local color = imgui.GetStyle().Colors[imgui.Col.ButtonActive]
			local color = imgui.GetColorU32Vec4(imgui.ImVec4(color.x, color.y, color.z, (circle.reverse and (255-255*t) or (255*t))/255))
			local radius = math.max(size.x, size.y) * (circle.reverse and 1.5 or t)
			imgui.PushClipRect(p, imgui.ImVec2(p.x+size.x, p.y+size.y), true)
			dl:AddCircleFilled(circle.clickpos, radius, color, radius/2)
			PathInvertedRect(p, imgui.ImVec2(p.x+size.x, p.y+size.y), imgui.GetColorU32Vec4(imgui.GetStyle().Colors[imgui.Col.WindowBg]))
			imgui.PopClipRect()
			if t == 1 then
				if not circle.reverse then
					circle.reverse = true
					circle.time = os.clock()
				else
					table.remove(button.circles, i)
				end
			end
		end
	end
	local t = ImSaturate((os.clock()-button.time) / speed)
	button.color.w = button.color.w + (button.hovered and 0.8 or -0.8)*t
	button.color.w = button.color.w < 0.2 and 0.2 or (button.color.w > 1 and 1 or button.color.w)
	color = imgui.GetStyle().Colors[imgui.Col.Button]
	color = imgui.GetColorU32Vec4(imgui.ImVec4(color.x, color.y, color.z, 0.2))
	dl:AddRectFilled(p, imgui.ImVec2(p.x+size.x-1, p.y+size.y), color, rounded and imgui.GetStyle().FrameRounding or 0)
	dl:AddRect(p, imgui.ImVec2(p.x+size.x-1, p.y+size.y), imgui.GetColorU32Vec4(button.color), rounded and imgui.GetStyle().FrameRounding or 0)
	local align = imgui.GetStyle().ButtonTextAlign
	dl:AddText(imgui.ImVec2(p.x+(size.x-ts.x)*align.x, p.y+(size.y-ts.y)*align.y), -1, text)
	imgui.EndChild()
	imgui.PopStyleVar(2)
	return bool
end

function getBlockMaxSize(block)
	local max_size = {x = 20, y = 20}
	local spacing = imgui.GetStyle().ItemSpacing
	for i, line in ipairs(block) do
		local size = {x = 0, y = 0}
		for i, key in ipairs(line) do
			size.x = size.x + (key.size and key.size.x or 20) + spacing.x
			size.y = (key.size and key.size.y or 20) + spacing.y
		end
		if size.x > max_size.x then max_size.x = size.x end
		if size.y > max_size.y then max_size.y = size.y end
	end
	max_size.x, max_size.y = max_size.x + 20, max_size.y + 20
	return max_size
end
function getLineMaxHeight(line)
	local max = 20
	local spacing = imgui.GetStyle().ItemSpacing
	local size = 0
	for i, key in ipairs(line) do
		size = (key.size and key.size.y or 20) + spacing.y
		if size > max then max = size end
	end
	return max + 20
end

function renderKey(key, isMouse, notResize, pressed)
	if not key then return false end
	local resize = notResize and 1 or (isMouse and mSize[0] or kSize[0])
	if not key.time then key.time = 0 end
	local DL = imgui.GetWindowDrawList()
	local cp = imgui.GetCursorScreenPos()
	local spacing = imgui.GetStyle().ItemSpacing
	local size = (key.size 
		and imgui.ImVec2((key.size.x > 20 and key.size.x * resize + spacing.x or key.size.x * resize), (key.size.y > 20 and key.size.y * resize + spacing.y or key.size.y * resize))
		or imgui.ImVec2(20 * resize, 20 * resize))
	local text = key.name:gsub('#.+', '')
	local ts = imgui.CalcTextSize(text)
	local a, b = cp, imgui.ImVec2(cp.x+size.x, cp.y+size.y)
	local tPos = imgui.ImVec2(a.x+(size.x-ts.x)/2, a.y+(size.y-ts.y)/2)
	local color = imgui.ColorConvertFloat4ToU32(((pressed or key.time >= os.clock()) and (rainbowMode.active[0] and rainbow(rainbowMode.speed[0], 0.4, key.id) or keyColors.active) or keyColors.main))
	imgui.Dummy(size)
	DL:AddRectFilled(imgui.ImVec2(a.x+1, a.y+1), imgui.ImVec2(b.x-1, b.y-1), color, rounding[0] and 6 or 0)
	DL:AddRect(a, b, imgui.ColorConvertFloat4ToU32((theme[0] == 6 and cStyle['borderColor'] or imgui.GetStyle().Colors[imgui.Col.FrameBg])), rounding[0] and 6 or 0, _, 1.2)
	DL:AddText(tPos, (theme[0] == 6 and imgui.GetColorU32Vec4(cStyle['textColor']) or -1), text)
end

function renderWheel()
	local resize = mSize[0]
	local p = imgui.GetCursorScreenPos()
	local draw_list = imgui.GetWindowDrawList()
	local spacing = imgui.GetStyle().ItemSpacing
	local color1 = imgui.ColorConvertFloat4ToU32((wheel[1] and (wheel[1][1] > 0 and (rainbowMode.active[0] and rainbow(rainbowMode.speed[0], 0.4, 10) or keyColors.active) or keyColors.main) or keyColors.main))
	local color2 = imgui.ColorConvertFloat4ToU32((wheel[1] and (wheel[1][1] < 0 and (rainbowMode.active[0] and rainbow(rainbowMode.speed[0], 0.4, 20) or keyColors.active) or keyColors.main) or keyColors.main))
	draw_list:AddRectFilled(imgui.ImVec2(p.x+1, p.y+1), imgui.ImVec2(p.x+32*resize+spacing.x-1, p.y+14*resize+spacing.y-1), color1, rounding[0] and 6 or 0)
	draw_list:AddRectFilled(imgui.ImVec2(p.x+1, p.y+35*resize), imgui.ImVec2(p.x+32*resize+spacing.x-1, p.y+50*resize+spacing.y-1), color2, rounding[0] and 6 or 0)
	if #wheel > 0 and wheel[1][1] ~= 0 then
		if wheel[1][2] < os.clock() then
			table.remove(wheel, 1)
		end
	end
	local a, b = p, imgui.ImVec2(p.x+32*resize+spacing.x, p.y+50*resize+spacing.y)
	draw_list:AddRect(a, b, imgui.ColorConvertFloat4ToU32((theme[0] == 6 and cStyle['borderColor'] or imgui.GetStyle().Colors[imgui.Col.FrameBg])), rounding[0] and 6 or 0, _, 1.2)
end

function setKeyColors()
	for k, v in pairs(cStyleEdit) do
		cStyle[k] = imgui.ImVec4(v[0], v[1], v[2], v[3])
	end
	return {
		active = (theme[0] == 6 and 
			imgui.ImVec4(cStyleEdit['activeColor'][0], cStyleEdit['activeColor'][1], cStyleEdit['activeColor'][2], cStyleEdit['activeColor'][3])
			or imgui.GetStyle().Colors[imgui.Col.ButtonActive]),
		main = (theme[0] == 6 and 
			imgui.ImVec4(cStyleEdit['mainColor'][0], cStyleEdit['mainColor'][1], cStyleEdit['mainColor'][2], cStyleEdit['mainColor'][3])
			or imgui.GetStyle().Colors[imgui.Col.ChildBg])
	}
end

function tableCopy(t)
	local t2 = {}
	for k,v in pairs(t) do
		t2[k] = v
	end
	return t2
end

-- Фикс улетания в левый верхний угол при сворачивании
addEventHandler("onWindowMessage", function (msg, wp, lp)
	if wp == 0x1B and settings.state then 
		settings.switch()
		consumeWindowMessage()
	end
	if msg == 6 then
		if wp == 0 then
			gta = false
		elseif wp == 1 or wp == 2 then
			gta = true
		end
	end
end)

function iniSave()
	ini.config.active = keyboard[0]
	ini.mouse.active = mouse[0]
	ini.config.mode = keyboard_type[0]
	ini.config.move = keyboardMove[0]
	ini.mouse.move = mouseMove[0]
	ini.config.theme = theme[0]
	ini.config.rounding = rounding[0]
	ini.config.size = kSize[0]
	ini.mouse.size = mSize[0]
	ini.pos.x, ini.pos.y = kPos.x, kPos.y
	ini.mouse.x, ini.mouse.y = mPos.x, mPos.y
	for k, v in pairs(ini.cStyle) do
		ini.cStyle[k] =  rgba_to_argb(imgui.ColorConvertFloat4ToU32(cStyle[k]))
	end
	ini.monet.mainColor = rgba_to_argb(imgui.ColorConvertFloat4ToU32(monetColor))
	ini.monet.brightness = monetBrightness[0]
	ini.rainbowMode.active = rainbowMode.active[0]
	ini.rainbowMode.speed = rainbowMode.speed[0]
	ini.rainbowMode.async = rainbowMode.async[0]
	ini.rainbowMode.async = rainbowMode.async[0]
	for ik, keyboard in ipairs(keyboards) do
		for ib, block in ipairs(keyboard.keyboard.blocks) do
			for il, line in ipairs(block) do
				for i, key in ipairs(line) do
					key.time = -1
					if key.name == '/\\' then key.name = ti.ICON_CARET_UP
					elseif key.name == '\\/' then key.name = ti.ICON_CARET_DOWN
					elseif key.name == '<' then key.name = ti.ICON_CARET_LEFT
					elseif key.name == '>' then key.name = ti.ICON_CARET_RIGHT
					elseif key.name == '<-' then key.name = ti.ICON_ARROW_NARROW_LEFT
					end
				end
			end
		end
	end
	ini.logging.active = logging.active[0]
	ini.logging.enableTimeout = logging.enableTimeout[0]
	ini.logging.timeout = logging.timeout[0]
	ini.logging.highlight = logging.highlight[0]
	inicfg.save(ini, iniFile)
	json(keyboardsDir):write(keyboards)
	if keyLogs and #keyLogs > 0 then saveKeyLogs(date) end
	--keyLogs, date = getKeyLogs()
end

function explode_argb(argb)
	local a = bit.band(bit.rshift(argb, 24), 0xFF)
	local r = bit.band(bit.rshift(argb, 16), 0xFF)
	local g = bit.band(bit.rshift(argb, 8), 0xFF)
	local b = bit.band(argb, 0xFF)
	return a, r, g, b
end
function join_argb(a, r, g, b)
	local argb = b  -- b
	argb = bit.bor(argb, bit.lshift(g, 8))  -- g
	argb = bit.bor(argb, bit.lshift(r, 16)) -- r
	argb = bit.bor(argb, bit.lshift(a, 24)) -- a
	return argb
end
function argb_to_rgba(argb)
	local a, r, g, b = explode_argb(argb)
	return join_argb(r, g, b, a)
end

function rgba_to_argb(rgba)
	local a, b, g, r = explode_argb(rgba)
	return join_argb(a, r, g, b)
end

function onScriptTerminate(s) if s == thisScript() then iniSave() end end

function rainbow(speed, alpha, modify)
	alpha = alpha or 1
	modify = modify or 0
	local time = os.clock()
	if rainbowMode.async[0] then time = os.clock() + modify end
	return imgui.ImVec4(math.floor(math.sin(time * speed) * 127 + 128)/255, math.floor(math.sin(time * speed + 2) * 127 + 128)/255, math.floor(math.sin(time * speed + 4) * 127 + 128)/255, alpha)
end

function getKeyboardsList()
	if not doesFileExist(keyboardsDir) then
		printChat('Ошибка, не найден файл со списком клавиатур. Скачайте его из темы со скриптом.')
		printChat('Тему можно найти на BLASTHACK (Файл: keyboards.json)')
		printChat(string.format('Файл нужно установить в папку %s', getWorkingDirectory()..'\\config\\'))
		printChat('Если вы играете на Arizona Launcher, просто переустановите скрипт во вкладке "Моды"')
		printChat('Автоматическое выключение скрипта...')
		thisScript():unload()
	else
		keyboards = json(keyboardsDir):read()
		if not keyboards or #keyboards == 0 then
			printChat('Ошибка, файл со списком клавиатур был повреждён. Скачайте его из темы со скриптом.')
			printChat('Тему можно найти на BLASTHACK (Файл: keyboards.json)')
			printChat(string.format('Файл нужно установить в папку %s', getWorkingDirectory()..'\\config\\'))
			printChat('Если вы играете на Arizona Launcher, просто переустановите скрипт во вкладке "Моды"')
			printChat('Автоматическое выключение скрипта...')
			thisScript():unload()
		end
	end
	for i, v in ipairs(keyboards) do 
		table.insert(keyboardList.arr, u8(v.name))
		for ib, block in ipairs(v.keyboard.blocks) do
			for il, line in ipairs(block) do
				for i, key in ipairs(line) do
					key.time = -1
					if key.name == '/\\' then key.name = ti.ICON_CARET_UP
					elseif key.name == '\\/' then key.name = ti.ICON_CARET_DOWN
					elseif key.name == '<' then key.name = ti.ICON_CARET_LEFT
					elseif key.name == '>' then key.name = ti.ICON_CARET_RIGHT
					elseif key.name == '<-' then key.name = ti.ICON_ARROW_NARROW_LEFT
					end
				end
			end
		end
	end
	keyboardList.var = new['const char*'][#keyboardList.arr](keyboardList.arr)
	return true
end

function getKeyLogs(date, silent)
	if not date or date ~= 'Всё время' then
		if not doesDirectoryExist(getWorkingDirectory()..'\\config\\keyboard') then createDirectory(getWorkingDirectory()..'\\config\\keyboard') end
		local file = string.format('%s\\config\\keyboard\\%s.json', getWorkingDirectory(), (date or os.date('%d.%m.%Y')))
		if not doesFileExist(file) then
			if not silent then printChat(string.format('Ошибка, лог %s не был найден. Лог будет создан автоматически.', (date or os.date('%d.%m.%Y')))) end
			local log = {}
			for ib, block in ipairs(keyboards[1].keyboard.blocks) do
				for il, line in ipairs(block) do
					for i, key in ipairs(line) do
						if not inTable(log, id, 'id') then
							table.insert(log, {
								id = key.id,
								pressed = 0,
								timeMin = 0,
								timeMax = 0,
								timeTotal = 0,
								lastPress = 0
							})
						end
					end
				end
			end
			for il, line in ipairs(mouse_keys) do
				for i, key in ipairs(line) do
					table.insert(log, {
						id = key.id,
						pressed = 0,
						timeMin = 0,
						timeMax = 0,
						timeTotal = 0,
						lastPress = 0
					})
				end
			end
			json(file):write(log)
			if not silent then printChat(string.format('Лог %s успешно создан.', (date or os.date('%d.%m.%Y')))) end
			return json(file):read(), (date or os.date('%d.%m.%Y'))
		else
			local log = json(file):read()
			if not log or #log == 0 then
				if not silent then printChat(string.format('Произошла ошибка при загрузке лога. Лог %s будет автоматически обнулён.', (date or os.date('%d.%m.%Y')))) end
				log = {}
				for ib, block in ipairs(keyboards[1].keyboard.blocks) do
					for il, line in ipairs(block) do
						for i, key in ipairs(line) do
							if not inTable(log, id, 'id') then
								table.insert(log, {
									id = key.id,
									pressed = 0,
									timeMin = 0,
									timeMax = 0,
									timeTotal = 0,
									lastPress = 0
								})
							end
						end
					end
				end
				for il, line in ipairs(mouse_keys) do
					for i, key in ipairs(line) do
						table.insert(log, {
							id = key.id,
							pressed = 0,
							timeMin = 0,
							timeMax = 0,
							timeTotal = 0,
							lastPress = 0
						})
					end
				end
				json(file):write(log)
				log = json(file):read()
			else
				for i, v in ipairs(log) do
					v.lastPress = 0
				end
			end
			if not silent then printChat(string.format('Лог %s успешно загружен.', (date or os.date('%d.%m.%Y')))) end
			return log, (date or os.date('%d.%m.%Y'))
		end
	elseif date == 'Всё время' then
		local log = {}
		for i, v in ipairs(getFilesInPath(getWorkingDirectory()..'\\config\\keyboard', '*.json')) do
			local fDate = v:gsub('%.json', '')
			local fLog, fDate = getKeyLogs(fDate, true)
			for i, key in ipairs(fLog) do
				if not inTable(log, key.id, 'id') then
					table.insert(log, key)
				else
					local lKey = getTableByValue(log, key.id, 'id')
					lKey.pressed = lKey.pressed + key.pressed
					lKey.timeMin = (key.timeMin > 0) and 
						((lKey.timeMin > 0) and (lKey.timeMin > key.timeMin and key.timeMin or lKey.timeMin) or key.timeMin) 
						or lKey.timeMin > 0 and lKey.timeMin or key.timeMin
					lKey.timeMax = lKey.timeMax > key.timeMax and lKey.timeMax or key.timeMax
					lKey.timeTotal = lKey.timeTotal + key.timeTotal
				end
			end
		end
		return log, date
	end
end

function saveKeyLogs(date)
	local file = string.format('%s\\config\\keyboard\\%s.json', getWorkingDirectory(), (date or os.date('%d.%m.%Y')))
	json(file):write(keyLogs)
end

function getFilesInPath(path, ftype)
	local Files, SearchHandle, File = {}, findFirstFile(path.."\\"..ftype)
	table.insert(Files, File)
	while File do File = findNextFile(SearchHandle) table.insert(Files, File) end
	return Files
end

function inTable(t, val, key)
	for k, v in pairs(t) do
		if key and k == key and v == val then return true end
		if type(v) == 'table' then 
			if inTable(v, val, key) then return true end
		elseif not key and v == val then
			return true 
		end 
	end
	return false
end

function getTableByValue(t, val, key)
	for k, v in pairs(t) do
		if key and k == key and v == val then return t end
		if type(v) == 'table' then
			local test = getTableByValue(v, val, key)
			if test then return test end
		elseif not key and v == val then
			return t
		end 
	end
	return false
end

function round(number, precision)
	local fmtStr = string.format('%%0.%sf',precision)
	number = string.format(fmtStr,number)
	return tonumber(number)
end

function plural(n, forms)
	n = math.abs(n) % 100
	if n % 10 == 1 and n ~= 11 then
		return forms[1]
	elseif 2 <= n % 10 and n % 10 <= 4 and (n < 10 or n >= 20) then
		return forms[2]
	end
	return forms[3]
end

function array_reverse(x)
	local n, m = #x, #x/2
	for i=1, m do
	  x[i], x[n-i+1] = x[n-i+1], x[i]
	end
	return x
  end

function timeFormat(time)
	local days = math.floor(time/86400)
	local hour = math.floor((time-86400*days)/3600)
	local min = math.floor((time-86400*days-3600*hour)/60)
	local sec, ms = math.modf(time-86400*days-3600*hour-min*60)
	if days > 0 then
		return string.format('%d %s %02d:%02d:%02d.%s', days, plural(days, {'день', 'дня', 'дней'}), hour,min,sec, tostring(ms):sub(3,5))
	end
	if hour > 0 then return string.format('%02d:%02d:%02d.%s',hour,min,sec, tostring(ms):sub(3,5)) end
	if min > 0 then return string.format('%02d:%02d.%s',min,sec,tostring(ms):sub(3,5))
	else return string.format('%d.%s сек',sec,tostring(ms):sub(3,6)) 
	end
end

function logThread()
	local lastSave = os.clock()
	while true do
		wait(0)
		if logging.active[0] and gta then
			if not keyLogs or #keyLogs == 0 or date ~= os.date('%d.%m.%Y') then 
				if date ~= os.date('%d.%m.%Y') and keyLogs and #keyLogs > 0 then saveKeyLogs(date) end
				keyLogs, date = getKeyLogs()
			end
			for i, v in ipairs(keyLogs) do
				if isKeyJustPressed(v.id) then
					v.lastPress = os.clock()
					v.pressed = v.pressed + 1
				elseif wasKeyReleased(v.id) and v.lastPress > 0 then
					local time = os.clock() - v.lastPress
					v.timeTotal = round((v.timeTotal + time), 5)
					v.timeMin = round(((v.timeMin > 0 and v.timeMin < time) and v.timeMin or time), 5)
					v.timeMax = round(((v.timeMin > time) and v.timeMax or time), 5)
				end
			end
			if logging.enableTimeout[0] and os.clock() >= lastSave + logging.timeout[0]*60 then
				print('Авто-сохранение лога клавиш')
				saveKeyLogs(date)
				keyLogs, date = getKeyLogs(_, true)
				lastSave = os.clock()
			end
		end
	end
end



mouse_keys = {
	{
		{name = 'LMB', id = 0x01, size = { x = 32, y = 50}},
		{name = 'MMB', id = 0x04, size = { x = 32, y = 20}},
		{name = 'RMB', id = 0x02, size = { x = 32, y = 50}},
	},
	{
		{name = 'FWD', id = 0x06, size = { x = 51, y = 20}},
		{name = 'BWD', id = 0x05, size = { x = 51, y = 20}},
	}
}
function defaultStyle()
	imgui.SwitchContext()
	local style = imgui.GetStyle()
	style.WindowRounding = 10
	style.ChildRounding = 10
	style.FrameRounding = 6.0
	style.ItemSpacing = imgui.ImVec2(3.0, 3.0)
	style.ItemInnerSpacing = imgui.ImVec2(3.0, 3.0)
	style.FramePadding = imgui.ImVec2(4.0, 3.0)
	style.IndentSpacing = 21
	style.ScrollbarSize = 10.0
	style.ScrollbarRounding = 13
	style.GrabMinSize = 17.0
	style.GrabRounding = 16.0
	style.WindowTitleAlign = imgui.ImVec2(0.5, 0.5)
	style.ButtonTextAlign = imgui.ImVec2(0.5, 0.5)
end
styles = {
	[0] = {
		name = u8'Зелёная',
		buttonColors = {
			main =  imgui.ImVec4(0.00, 0.69, 0.33, 1.00),
			hovered = imgui.ImVec4(0.00, 0.82, 0.39, 1.00),
			active = imgui.ImVec4(0.00, 0.87, 0.42, 1.00),
		},
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.Text]				   = ImVec4(0.90, 0.90, 0.90, 1.00)
			colors[clr.TextDisabled]		   = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.WindowBg]			   = ImVec4(0.08, 0.08, 0.08, 1.00)
			colors[clr.ChildBg]		  = ImVec4(0.10, 0.10, 0.10, 0.40)
			colors[clr.PopupBg]				= ImVec4(0.08, 0.08, 0.08, 1.00)
			colors[clr.Border]				 = ImVec4(0.70, 0.70, 0.70, 0.40)
			colors[clr.BorderShadow]		   = ImVec4(0.00, 0.00, 0.00, 0.00)
			colors[clr.FrameBg]				= ImVec4(0.15, 0.15, 0.15, 1.00)
			colors[clr.FrameBgHovered]		 = ImVec4(0.19, 0.19, 0.19, 0.71)
			colors[clr.FrameBgActive]		  = ImVec4(0.34, 0.34, 0.34, 0.79)
			colors[clr.TitleBg]				= ImVec4(0.00, 0.69, 0.33, 0.80)
			colors[clr.TitleBgActive]		  = ImVec4(0.00, 0.74, 0.36, 1.00)
			colors[clr.TitleBgCollapsed]	   = ImVec4(0.00, 0.69, 0.33, 0.50)
			colors[clr.MenuBarBg]			  = ImVec4(0.00, 0.80, 0.38, 1.00)
			colors[clr.ScrollbarBg]			= ImVec4(0.16, 0.16, 0.16, 1.00)
			colors[clr.ScrollbarGrab]		  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.ScrollbarGrabHovered]   = ImVec4(0.00, 0.82, 0.39, 1.00)
			colors[clr.ScrollbarGrabActive]	= ImVec4(0.00, 1.00, 0.48, 1.00)
			colors[clr.CheckMark]			  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.SliderGrab]			 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.SliderGrabActive]	   = ImVec4(0.00, 0.77, 0.37, 1.00)
			colors[clr.Button]				 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.ButtonHovered]		  = ImVec4(0.00, 0.82, 0.39, 1.00)
			colors[clr.ButtonActive]		   = ImVec4(0.00, 0.87, 0.42, 1.00)
			colors[clr.Header]				 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.HeaderHovered]		  = ImVec4(0.00, 0.76, 0.37, 0.57)
			colors[clr.HeaderActive]		   = ImVec4(0.00, 0.88, 0.42, 0.89)
			colors[clr.Separator]			  = ImVec4(1.00, 1.00, 1.00, 0.40)
			colors[clr.SeparatorHovered]	   = ImVec4(1.00, 1.00, 1.00, 0.60)
			colors[clr.SeparatorActive]		= ImVec4(1.00, 1.00, 1.00, 0.80)
			colors[clr.ResizeGrip]			 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.ResizeGripHovered]	  = ImVec4(0.00, 0.76, 0.37, 1.00)
			colors[clr.ResizeGripActive]	   = ImVec4(0.00, 0.86, 0.41, 1.00)
			colors[clr.PlotLines]			  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.PlotLinesHovered]	   = ImVec4(0.00, 0.74, 0.36, 1.00)
			colors[clr.PlotHistogram]		  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.PlotHistogramHovered]   = ImVec4(0.00, 0.80, 0.38, 1.00)
			colors[clr.TextSelectedBg]		 = ImVec4(0.00, 0.69, 0.33, 0.72)
			colors[clr.ModalWindowDimBg]   = ImVec4(0.17, 0.17, 0.17, 0.48)
		end
	},
	{
		name = u8'Красная',
		buttonColors = {
			main = imgui.ImVec4(1.00, 0.28, 0.28, 1.00),
			hovered = imgui.ImVec4(1.00, 0.39, 0.39, 1.00),
			active = imgui.ImVec4(1.00, 0.21, 0.21, 1.00),
		},
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.Text]				   = ImVec4(0.95, 0.96, 0.98, 1.00)
			colors[clr.TextDisabled]		   = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.WindowBg]			   = ImVec4(0.14, 0.14, 0.14, 1.00)
			colors[clr.ChildBg]		  = ImVec4(0.12, 0.12, 0.12, 0.40)
			colors[clr.PopupBg]				= ImVec4(0.08, 0.08, 0.08, 0.94)
			colors[clr.Border]				 = ImVec4(0.14, 0.14, 0.14, 1.00)
			colors[clr.BorderShadow]		   = ImVec4(1.00, 1.00, 1.00, 0.00)
			colors[clr.FrameBg]				= ImVec4(0.22, 0.22, 0.22, 1.00)
			colors[clr.FrameBgHovered]		 = ImVec4(0.18, 0.18, 0.18, 1.00)
			colors[clr.FrameBgActive]		  = ImVec4(0.09, 0.12, 0.14, 1.00)
			colors[clr.TitleBg]				= ImVec4(0.14, 0.14, 0.14, 0.81)
			colors[clr.TitleBgActive]		  = ImVec4(0.14, 0.14, 0.14, 1.00)
			colors[clr.TitleBgCollapsed]	   = ImVec4(0.00, 0.00, 0.00, 0.51)
			colors[clr.MenuBarBg]			  = ImVec4(0.20, 0.20, 0.20, 1.00)
			colors[clr.ScrollbarBg]			= ImVec4(0.02, 0.02, 0.02, 0.39)
			colors[clr.ScrollbarGrab]		  = ImVec4(0.36, 0.36, 0.36, 1.00)
			colors[clr.ScrollbarGrabHovered]   = ImVec4(0.18, 0.22, 0.25, 1.00)
			colors[clr.ScrollbarGrabActive]	= ImVec4(0.24, 0.24, 0.24, 1.00)
			colors[clr.CheckMark]			  = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.SliderGrab]			 = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.SliderGrabActive]	   = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.Button]				 = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.ButtonHovered]		  = ImVec4(1.00, 0.39, 0.39, 1.00)
			colors[clr.ButtonActive]		   = ImVec4(1.00, 0.21, 0.21, 1.00)
			colors[clr.Header]				 = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.HeaderHovered]		  = ImVec4(1.00, 0.39, 0.39, 1.00)
			colors[clr.HeaderActive]		   = ImVec4(1.00, 0.21, 0.21, 1.00)
			colors[clr.ResizeGrip]			 = ImVec4(1.00, 0.28, 0.28, 1.00)
			colors[clr.ResizeGripHovered]	  = ImVec4(1.00, 0.39, 0.39, 1.00)
			colors[clr.PlotLines]			  = ImVec4(0.61, 0.61, 0.61, 1.00)
			colors[clr.PlotLinesHovered]	   = ImVec4(1.00, 0.43, 0.35, 1.00)
			colors[clr.PlotHistogram]		  = ImVec4(1.00, 0.21, 0.21, 1.00)
			colors[clr.PlotHistogramHovered]   = ImVec4(1.00, 0.18, 0.18, 1.00)
			colors[clr.TextSelectedBg]		 = ImVec4(1.00, 0.32, 0.32, 1.00)
			colors[clr.ModalWindowDimBg]   = ImVec4(0.26, 0.26, 0.26, 0.60)
		end
	},
	{
		name = u8'Пурпурная',
		buttonColors = {
			main = imgui.ImVec4(0.46, 0.11, 0.29, 1.00),
			hovered = imgui.ImVec4(0.69, 0.16, 0.43, 1.00),
			active = imgui.ImVec4(0.58, 0.10, 0.35, 1.00),
		},
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.FrameBg]				= ImVec4(0.46, 0.11, 0.29, 1.00)
			colors[clr.FrameBgHovered]		 = ImVec4(0.69, 0.16, 0.43, 1.00)
			colors[clr.FrameBgActive]		  = ImVec4(0.58, 0.10, 0.35, 1.00)
			colors[clr.TitleBg]				= ImVec4(0.00, 0.00, 0.00, 1.00)
			colors[clr.TitleBgActive]		  = ImVec4(0.61, 0.16, 0.39, 1.00)
			colors[clr.TitleBgCollapsed]	   = ImVec4(0.00, 0.00, 0.00, 0.51)
			colors[clr.CheckMark]			  = ImVec4(0.94, 0.30, 0.63, 1.00)
			colors[clr.SliderGrab]			 = ImVec4(0.85, 0.11, 0.49, 1.00)
			colors[clr.SliderGrabActive]	   = ImVec4(0.89, 0.24, 0.58, 1.00)
			colors[clr.Button]				 = ImVec4(0.46, 0.11, 0.29, 1.00)
			colors[clr.ButtonHovered]		  = ImVec4(0.69, 0.17, 0.43, 1.00)
			colors[clr.ButtonActive]		   = ImVec4(0.59, 0.10, 0.35, 1.00)
			colors[clr.Header]				 = ImVec4(0.46, 0.11, 0.29, 1.00)
			colors[clr.HeaderHovered]		  = ImVec4(0.69, 0.16, 0.43, 1.00)
			colors[clr.HeaderActive]		   = ImVec4(0.58, 0.10, 0.35, 1.00)
			colors[clr.Separator]			  = ImVec4(0.69, 0.16, 0.43, 1.00)
			colors[clr.SeparatorHovered]	   = ImVec4(0.58, 0.10, 0.35, 1.00)
			colors[clr.SeparatorActive]		= ImVec4(0.58, 0.10, 0.35, 1.00)
			colors[clr.ResizeGrip]			 = ImVec4(0.46, 0.11, 0.29, 0.70)
			colors[clr.ResizeGripHovered]	  = ImVec4(0.69, 0.16, 0.43, 0.67)
			colors[clr.ResizeGripActive]	   = ImVec4(0.70, 0.13, 0.42, 1.00)
			colors[clr.TextSelectedBg]		 = ImVec4(1.00, 0.78, 0.90, 0.35)
			colors[clr.Text]				   = ImVec4(1.00, 1.00, 1.00, 1.00)
			colors[clr.TextDisabled]		   = ImVec4(0.60, 0.19, 0.40, 1.00)
			colors[clr.WindowBg]			   = ImVec4(0.06, 0.06, 0.06, 0.94)
			colors[clr.ChildBg]		  = ImVec4(0.00, 0.00, 0.00, 0.40)
			colors[clr.PopupBg]				= ImVec4(0.08, 0.08, 0.08, 0.94)
			colors[clr.Border]				 = ImVec4(0.49, 0.14, 0.31, 1.00)
			colors[clr.BorderShadow]		   = ImVec4(0.49, 0.14, 0.31, 0.00)
			colors[clr.MenuBarBg]			  = ImVec4(0.15, 0.15, 0.15, 1.00)
			colors[clr.ScrollbarBg]			= ImVec4(0.02, 0.02, 0.02, 0.53)
			colors[clr.ScrollbarGrab]		  = ImVec4(0.31, 0.31, 0.31, 1.00)
			colors[clr.ScrollbarGrabHovered]   = ImVec4(0.41, 0.41, 0.41, 1.00)
			colors[clr.ScrollbarGrabActive]	= ImVec4(0.51, 0.51, 0.51, 1.00)
			colors[clr.ModalWindowDimBg]   = ImVec4(0.80, 0.80, 0.80, 0.35)
		end
	},
	{
		name = u8'Фиолетовая',
		buttonColors = {
			main = imgui.ImVec4(0.41, 0.19, 0.63, 0.44),
			hovered = imgui.ImVec4(0.41, 0.19, 0.63, 0.86),
			active = imgui.ImVec4(0.41, 0.19, 0.63, 1.00),
		},
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.WindowBg]			  = ImVec4(0.14, 0.12, 0.16, 1.00)
			colors[clr.ChildBg]		 = ImVec4(0.30, 0.20, 0.39, 0.40)
			colors[clr.PopupBg]			   = ImVec4(0.05, 0.05, 0.10, 0.90)
			colors[clr.Border]				= ImVec4(0.89, 0.85, 0.92, 0.30)
			colors[clr.BorderShadow]		  = ImVec4(0.00, 0.00, 0.00, 0.00)
			colors[clr.FrameBg]			   = ImVec4(0.30, 0.20, 0.39, 1.00)
			colors[clr.FrameBgHovered]		= ImVec4(0.41, 0.19, 0.63, 0.68)
			colors[clr.FrameBgActive]		 = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.TitleBg]			   = ImVec4(0.41, 0.19, 0.63, 0.45)
			colors[clr.TitleBgCollapsed]	  = ImVec4(0.41, 0.19, 0.63, 0.35)
			colors[clr.TitleBgActive]		 = ImVec4(0.41, 0.19, 0.63, 0.78)
			colors[clr.MenuBarBg]			 = ImVec4(0.30, 0.20, 0.39, 0.57)
			colors[clr.ScrollbarBg]		   = ImVec4(0.30, 0.20, 0.39, 1.00)
			colors[clr.ScrollbarGrab]		 = ImVec4(0.41, 0.19, 0.63, 0.31)
			colors[clr.ScrollbarGrabHovered]  = ImVec4(0.41, 0.19, 0.63, 0.78)
			colors[clr.ScrollbarGrabActive]   = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.CheckMark]			 = ImVec4(0.56, 0.61, 1.00, 1.00)
			colors[clr.SliderGrab]			= ImVec4(0.41, 0.19, 0.63, 0.24)
			colors[clr.SliderGrabActive]	  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.Button]				= ImVec4(0.41, 0.19, 0.63, 0.44)
			colors[clr.ButtonHovered]		 = ImVec4(0.41, 0.19, 0.63, 0.86)
			colors[clr.ButtonActive]		  = ImVec4(0.64, 0.33, 0.94, 1.00)
			colors[clr.Header]				= ImVec4(0.41, 0.19, 0.63, 0.76)
			colors[clr.HeaderHovered]		 = ImVec4(0.41, 0.19, 0.63, 0.86)
			colors[clr.HeaderActive]		  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.ResizeGrip]			= ImVec4(0.41, 0.19, 0.63, 0.20)
			colors[clr.ResizeGripHovered]	 = ImVec4(0.41, 0.19, 0.63, 0.78)
			colors[clr.ResizeGripActive]	  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.PlotLines]			 = ImVec4(0.89, 0.85, 0.92, 0.63)
			colors[clr.PlotLinesHovered]	  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.PlotHistogram]		 = ImVec4(0.89, 0.85, 0.92, 0.63)
			colors[clr.PlotHistogramHovered]  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.TextSelectedBg]		= ImVec4(0.41, 0.19, 0.63, 0.43)
			colors[clr.TextDisabled]		  = ImVec4(0.41, 0.19, 0.63, 1.00)
			colors[clr.ModalWindowDimBg]  = ImVec4(0.20, 0.20, 0.20, 0.35)
		end
	},
	{
		name = u8'Вишнёвая',
		buttonColors = {
			main = imgui.ImVec4(0.47, 0.77, 0.83, 0.14),
			hovered = imgui.ImVec4(0.46, 0.20, 0.30, 0.86),
			active = imgui.ImVec4(0.50, 0.08, 0.26, 1.00),
		},
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.Text]				  = ImVec4(0.86, 0.93, 0.89, 0.78)
			colors[clr.TextDisabled]		  = ImVec4(0.71, 0.22, 0.27, 1.00)
			colors[clr.WindowBg]			  = ImVec4(0.13, 0.14, 0.17, 1.00)
			colors[clr.ChildBg]		 = ImVec4(0.20, 0.22, 0.27, 0.58)
			colors[clr.PopupBg]			   = ImVec4(0.20, 0.22, 0.27, 0.90)
			colors[clr.Border]				= ImVec4(0.31, 0.31, 1.00, 0.00)
			colors[clr.BorderShadow]		  = ImVec4(0.00, 0.00, 0.00, 0.00)
			colors[clr.FrameBg]			   = ImVec4(0.20, 0.22, 0.27, 1.00)
			colors[clr.FrameBgHovered]		= ImVec4(0.46, 0.20, 0.30, 0.78)
			colors[clr.FrameBgActive]		 = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.TitleBg]			   = ImVec4(0.23, 0.20, 0.27, 1.00)
			colors[clr.TitleBgActive]		 = ImVec4(0.50, 0.08, 0.26, 1.00)
			colors[clr.TitleBgCollapsed]	  = ImVec4(0.20, 0.20, 0.27, 0.75)
			colors[clr.MenuBarBg]			 = ImVec4(0.20, 0.22, 0.27, 0.47)
			colors[clr.ScrollbarBg]		   = ImVec4(0.20, 0.22, 0.27, 1.00)
			colors[clr.ScrollbarGrab]		 = ImVec4(0.09, 0.15, 0.10, 1.00)
			colors[clr.ScrollbarGrabHovered]  = ImVec4(0.46, 0.20, 0.30, 0.78)
			colors[clr.ScrollbarGrabActive]   = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.CheckMark]			 = ImVec4(0.71, 0.22, 0.27, 1.00)
			colors[clr.SliderGrab]			= ImVec4(0.47, 0.77, 0.83, 0.14)
			colors[clr.SliderGrabActive]	  = ImVec4(0.71, 0.22, 0.27, 1.00)
			colors[clr.Button]				= ImVec4(0.47, 0.77, 0.83, 0.14)
			colors[clr.ButtonHovered]		 = ImVec4(0.46, 0.20, 0.30, 0.86)
			colors[clr.ButtonActive]		  = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.Header]				= ImVec4(0.46, 0.20, 0.30, 0.76)
			colors[clr.HeaderHovered]		 = ImVec4(0.46, 0.20, 0.30, 0.86)
			colors[clr.HeaderActive]		  = ImVec4(0.50, 0.08, 0.26, 1.00)
			colors[clr.ResizeGrip]			= ImVec4(0.47, 0.77, 0.83, 0.04)
			colors[clr.ResizeGripHovered]	 = ImVec4(0.46, 0.20, 0.30, 0.78)
			colors[clr.ResizeGripActive]	  = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.PlotLines]			 = ImVec4(0.86, 0.93, 0.89, 0.63)
			colors[clr.PlotLinesHovered]	  = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.PlotHistogram]		 = ImVec4(0.86, 0.93, 0.89, 0.63)
			colors[clr.PlotHistogramHovered]  = ImVec4(0.46, 0.20, 0.30, 1.00)
			colors[clr.TextSelectedBg]		= ImVec4(0.46, 0.20, 0.30, 0.43)
			colors[clr.ModalWindowDimBg]  = ImVec4(0.20, 0.22, 0.27, 0.73)
		end
	},
	{
		name = u8'Жёлтая',
		buttonColors = {
			main = imgui.ImVec4(0.51, 0.36, 0.15, 1.00),
			hovered = imgui.ImVec4(0.91, 0.64, 0.13, 1.00),
			active = imgui.ImVec4(0.78, 0.55, 0.21, 1.00),
		},
		func = function()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.Text]				 = ImVec4(0.92, 0.92, 0.92, 1.00)
			colors[clr.TextDisabled]		 = ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.WindowBg]			 = ImVec4(0.06, 0.06, 0.06, 1.00)
			colors[clr.ChildBg]		= ImVec4(0.00, 0.00, 0.00, 0.40)
			colors[clr.PopupBg]			  = ImVec4(0.08, 0.08, 0.08, 0.94)
			colors[clr.Border]			   = ImVec4(0.51, 0.36, 0.15, 1.00)
			colors[clr.BorderShadow]		 = ImVec4(0.00, 0.00, 0.00, 0.00)
			colors[clr.FrameBg]			  = ImVec4(0.11, 0.11, 0.11, 1.00)
			colors[clr.FrameBgHovered]	   = ImVec4(0.51, 0.36, 0.15, 1.00)
			colors[clr.FrameBgActive]		= ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.TitleBg]			  = ImVec4(0.51, 0.36, 0.15, 1.00)
			colors[clr.TitleBgActive]		= ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.TitleBgCollapsed]	 = ImVec4(0.00, 0.00, 0.00, 0.51)
			colors[clr.MenuBarBg]			= ImVec4(0.11, 0.11, 0.11, 1.00)
			colors[clr.ScrollbarBg]		  = ImVec4(0.06, 0.06, 0.06, 0.53)
			colors[clr.ScrollbarGrab]		= ImVec4(0.21, 0.21, 0.21, 1.00)
			colors[clr.ScrollbarGrabHovered] = ImVec4(0.47, 0.47, 0.47, 1.00)
			colors[clr.ScrollbarGrabActive]  = ImVec4(0.81, 0.83, 0.81, 1.00)
			colors[clr.CheckMark]			= ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.SliderGrab]		   = ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.SliderGrabActive]	 = ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.Button]			   = ImVec4(0.51, 0.36, 0.15, 1.00)
			colors[clr.ButtonHovered]		= ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.ButtonActive]		 = ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.Header]			   = ImVec4(0.51, 0.36, 0.15, 1.00)
			colors[clr.HeaderHovered]		= ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.HeaderActive]		 = ImVec4(0.93, 0.65, 0.14, 1.00)
			colors[clr.Separator]			= ImVec4(0.21, 0.21, 0.21, 1.00)
			colors[clr.SeparatorHovered]	 = ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.SeparatorActive]	  = ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.ResizeGrip]		   = ImVec4(0.21, 0.21, 0.21, 1.00)
			colors[clr.ResizeGripHovered]	= ImVec4(0.91, 0.64, 0.13, 1.00)
			colors[clr.ResizeGripActive]	 = ImVec4(0.78, 0.55, 0.21, 1.00)
			colors[clr.PlotLines]			= ImVec4(0.61, 0.61, 0.61, 1.00)
			colors[clr.PlotLinesHovered]	 = ImVec4(1.00, 0.43, 0.35, 1.00)
			colors[clr.PlotHistogram]		= ImVec4(0.90, 0.70, 0.00, 1.00)
			colors[clr.PlotHistogramHovered] = ImVec4(1.00, 0.60, 0.00, 1.00)
			colors[clr.TextSelectedBg]	   = ImVec4(0.26, 0.59, 0.98, 0.35)
			colors[clr.ModalWindowDimBg] = ImVec4(0.80, 0.80, 0.80, 0.35)
		end
	},
	{
		name = u8'Кастомная',
		buttonColors = {
			main = {
				imgui.ImVec4(0.72, 0.01, 0.01, 1.00),
				imgui.ImVec4(0.04, 0.03, 0.61, 1.00),
				imgui.ImVec4(0.03, 0.64, 0.02, 1.00),
				imgui.ImVec4(0.81, 0.82, 0.02, 1.00),
			},
			hovered = {
				imgui.ImVec4(0.85, 0.03, 0.03, 1.00),
				imgui.ImVec4(0.04, 0.02, 0.83, 1.00),
				imgui.ImVec4(0.04, 0.76, 0.03, 1.00),
				imgui.ImVec4(0.91, 0.92, 0.03, 1.00),
			},
			active = {
				imgui.ImVec4(0.99, 0.01, 0.01, 1.00),
				imgui.ImVec4(0.04, 0.02, 0.97, 1.00),
				imgui.ImVec4(0.03, 0.94, 0.02, 1.00),
				imgui.ImVec4(0.99, 1.00, 0.12, 1.00),
			},
		},
		func = function ()
			imgui.SwitchContext()
			local style = imgui.GetStyle()
			local colors = style.Colors
			local clr = imgui.Col
			local ImVec4 = imgui.ImVec4
			colors[clr.Text]				   = ImVec4(0.90, 0.90, 0.90, 1.00)
			colors[clr.TextDisabled]		   = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.WindowBg]			   = ImVec4(0.08, 0.08, 0.08, 1.00)
			colors[clr.ChildBg]		  = ImVec4(0.10, 0.10, 0.10, 0.40)
			colors[clr.PopupBg]				= ImVec4(0.08, 0.08, 0.08, 1.00)
			colors[clr.Border]				 = ImVec4(0.70, 0.70, 0.70, 0.40)
			colors[clr.BorderShadow]		   = ImVec4(0.00, 0.00, 0.00, 0.00)
			colors[clr.FrameBg]				= ImVec4(0.15, 0.15, 0.15, 1.00)
			colors[clr.FrameBgHovered]		 = ImVec4(0.19, 0.19, 0.19, 0.71)
			colors[clr.FrameBgActive]		  = ImVec4(0.34, 0.34, 0.34, 0.79)
			colors[clr.TitleBg]				= ImVec4(0.00, 0.69, 0.33, 0.80)
			colors[clr.TitleBgActive]		  = ImVec4(0.00, 0.74, 0.36, 1.00)
			colors[clr.TitleBgCollapsed]	   = ImVec4(0.00, 0.69, 0.33, 0.50)
			colors[clr.MenuBarBg]			  = ImVec4(0.00, 0.80, 0.38, 1.00)
			colors[clr.ScrollbarBg]			= ImVec4(0.16, 0.16, 0.16, 1.00)
			colors[clr.ScrollbarGrab]		  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.ScrollbarGrabHovered]   = ImVec4(0.00, 0.82, 0.39, 1.00)
			colors[clr.ScrollbarGrabActive]	= ImVec4(0.00, 1.00, 0.48, 1.00)
			colors[clr.CheckMark]			  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.SliderGrab]			 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.SliderGrabActive]	   = ImVec4(0.00, 0.77, 0.37, 1.00)
			colors[clr.Button]				 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.ButtonHovered]		  = ImVec4(0.00, 0.82, 0.39, 1.00)
			colors[clr.ButtonActive]		   = ImVec4(0.00, 0.87, 0.42, 1.00)
			colors[clr.Header]				 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.HeaderHovered]		  = ImVec4(0.00, 0.76, 0.37, 0.57)
			colors[clr.HeaderActive]		   = ImVec4(0.00, 0.88, 0.42, 0.89)
			colors[clr.Separator]			  = ImVec4(1.00, 1.00, 1.00, 0.40)
			colors[clr.SeparatorHovered]	   = ImVec4(1.00, 1.00, 1.00, 0.60)
			colors[clr.SeparatorActive]		= ImVec4(1.00, 1.00, 1.00, 0.80)
			colors[clr.ResizeGrip]			 = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.ResizeGripHovered]	  = ImVec4(0.00, 0.76, 0.37, 1.00)
			colors[clr.ResizeGripActive]	   = ImVec4(0.00, 0.86, 0.41, 1.00)
			colors[clr.PlotLines]			  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.PlotLinesHovered]	   = ImVec4(0.00, 0.74, 0.36, 1.00)
			colors[clr.PlotHistogram]		  = ImVec4(0.00, 0.69, 0.33, 1.00)
			colors[clr.PlotHistogramHovered]   = ImVec4(0.00, 0.80, 0.38, 1.00)
			colors[clr.TextSelectedBg]		 = ImVec4(0.00, 0.69, 0.33, 0.72)
			colors[clr.ModalWindowDimBg]   = ImVec4(0.17, 0.17, 0.17, 0.48)
		end
	},
	-- by THERION, edited by CaJlaT
	-- @param color number: Main color U32 representation.
	-- @param chroma_multiplier number: Color brightness. [0.5; 2.0].
	-- @param accurate_shades boolean: Use accurate shades.
	{
		name = u8'MoonMonet',
		buttonColors = {
			main = {
				imgui.ImVec4(0.72, 0.01, 0.01, 1.00),
				imgui.ImVec4(0.04, 0.03, 0.61, 1.00),
				imgui.ImVec4(0.03, 0.64, 0.02, 1.00),
				imgui.ImVec4(0.81, 0.82, 0.02, 1.00),
			},
			hovered = {
				imgui.ImVec4(0.85, 0.03, 0.03, 1.00),
				imgui.ImVec4(0.04, 0.02, 0.83, 1.00),
				imgui.ImVec4(0.04, 0.76, 0.03, 1.00),
				imgui.ImVec4(0.91, 0.92, 0.03, 1.00),
			},
			active = {
				imgui.ImVec4(0.99, 0.01, 0.01, 1.00),
				imgui.ImVec4(0.04, 0.02, 0.97, 1.00),
				imgui.ImVec4(0.03, 0.94, 0.02, 1.00),
				imgui.ImVec4(0.99, 1.00, 0.12, 1.00),
			},
		},
		func = function()
			if monet then
				imgui.SwitchContext()
				local style = imgui.GetStyle()
				local colors = style.Colors
				local clr = imgui.Col
				local function to_vec4(u32, a)
					local a_ = bit.band(bit.rshift(u32, 24), 0xFF) / 0xFF
					local r = bit.band(bit.rshift(u32, 16), 0xFF) / 0xFF
					local g = bit.band(bit.rshift(u32, 8), 0xFF) / 0xFF
					local b = bit.band(u32, 0xFF) / 0xFF
					a = a or a_
					return imgui.ImVec4(r, g, b, a)
			  	end

				local palette = monet.buildColors(rgba_to_argb(imgui.ColorConvertFloat4ToU32(monetColor)), monetBrightness[0], true)
			
				colors[clr.Text] = to_vec4(palette.neutral1.color_50)
				colors[clr.TextDisabled] = to_vec4(palette.accent1.color_800)

				colors[clr.WindowBg] = to_vec4(palette.neutral1.color_900, 0.94)
				colors[clr.ChildBg] = to_vec4(palette.neutral1.color_900, 0.40)
				colors[clr.PopupBg] = to_vec4(palette.neutral1.color_900, 0.94)

				colors[clr.Border] = to_vec4(palette.neutral1.color_100)
				colors[clr.BorderShadow] = to_vec4(palette.neutral2.color_900)

				colors[clr.FrameBg] = to_vec4(palette.accent1.color_800)
				colors[clr.FrameBgHovered] = to_vec4(palette.accent1.color_700)
				colors[clr.FrameBgActive] = to_vec4(palette.accent1.color_600)

				colors[clr.TitleBg] = to_vec4(palette.accent1.color_1000)
				colors[clr.TitleBgActive] = to_vec4(palette.accent1.color_800)
				colors[clr.TitleBgCollapsed] = to_vec4(palette.accent1.color_1000, 0.5)

				colors[clr.ScrollbarBg] = to_vec4(palette.accent1.color_800)
				colors[clr.ScrollbarGrab] = to_vec4(palette.accent1.color_500)
				colors[clr.ScrollbarGrabHovered] = to_vec4(palette.accent1.color_600)
				colors[clr.ScrollbarGrabActive] = to_vec4(palette.accent1.color_500)

				colors[clr.CheckMark] = to_vec4(palette.accent1.color_500)

				colors[clr.SliderGrab] = to_vec4(palette.accent1.color_500)
				colors[clr.SliderGrabActive] = to_vec4(palette.accent2.color_400)

				colors[clr.Button] = to_vec4(palette.accent1.color_800)
				colors[clr.ButtonHovered] = to_vec4(palette.accent1.color_700)
				colors[clr.ButtonActive] = to_vec4(palette.accent1.color_600)

				colors[clr.Header] = to_vec4(palette.accent1.color_800)
				colors[clr.HeaderHovered] = to_vec4(palette.accent1.color_700)
				colors[clr.HeaderActive] = to_vec4(palette.accent1.color_600)

				colors[clr.Separator] = to_vec4(palette.accent2.color_200)
				colors[clr.SeparatorHovered] = to_vec4(palette.accent2.color_100)
				colors[clr.SeparatorActive] = to_vec4(palette.accent2.color_50)

				colors[clr.ResizeGrip] = to_vec4(palette.accent2.color_900)
				colors[clr.ResizeGripHovered] = to_vec4(palette.accent2.color_800)
				colors[clr.ResizeGripActive] = to_vec4(palette.accent2.color_700)

				colors[clr.Tab] = to_vec4(palette.accent1.color_700)
				colors[clr.TabHovered] = to_vec4(palette.accent1.color_600)
				colors[clr.TabActive] = to_vec4(palette.accent1.color_500)

				colors[clr.PlotLines] = to_vec4(palette.accent3.color_300)
				colors[clr.PlotLinesHovered] = to_vec4(palette.accent3.color_50)
				colors[clr.PlotHistogram] = to_vec4(palette.accent3.color_300)
				colors[clr.PlotHistogramHovered] = to_vec4(palette.accent3.color_50)

				colors[clr.DragDropTarget] = to_vec4(palette.accent3.color_700)
			end
		end
	}
}
changelog = {
	{
		version = '3.0 (От 9.01.2023)',
		description = [[
* Редизайн настроек скрипта, переход на mimgui;
* Полный лог обновлений (начиная с 3.0) теперь находится во вкладке "Информация";
* Переписан способ рендера клавиш;
* Добавлены 2 динамические темы ("Своя" и "MoonMonet");
* Добавлена возможность включить режим переливающихся нажатых клавиш;
* Добавлен редактор клавиатуры;
* Добавлена возможность менять размер клавиатуры и мыши;
* Фикс пропуска нажатий при малом фпс;
* Фикс улетания в верхний левый угол при сворачивании игры с антиафк.
]]
	},
	{
		version = '3.1 (От 14.02.2023)',
		description = [[
* Фикс отображения нажатых клавиш (теперь не выходит за обводку);
* фикс рендера колесика при изменении размера;
* Все клавиши со стрелочками теперь отображаются иконками;
* Новый редактор клавиш;
* Добавлена возможность менять отступ клавиши;
* Изменена вкладка с темами;
* Добавлен лог нажатий клавиш (по умолчанию выключен);
* Добавлены анимации в меню настроек;
* Теперь меню скрипта можно закрыть на кнопку ESC;
* Фикс ссылки на тему со скриптом;
* Убрана авто-подкачка списка клавиатур;
* Изменён логотип;
* Уменьшен размер шрифтов в графической памяти;
* Вырезаны все ссылки из скрипта, кроме группы в ВК.
]]
	},
	{
		version = '3.1.1 (От 19.03.2024)',
		description = [[
* Фикс скрытия окон скрипта при переключении на игру мышкой, а не через Alt+Tab;
* Теперь можно кликать сквозь клавиатуру или мышь, если перемещение отключено;
* Список изменений теперь идёт от нового к старому и пишется дата выпуска версии.
]]
	}
}
changelog = array_reverse(changelog)
logo = "\x89\x50\x4E\x47\x0D\x0A\x1A\x0A\x00\x00\x00\x0D\x49\x48\x44\x52\x00\x00\x00\xB5\x00\x00\x00\xC2\x04\x03\x00\x00\x00\xFD\x5A\x9E\xE3\x00\x00\x00\x2D\x50\x4C\x54\x45\x47\x70\x4C\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xFF\xCD\x5E\xDD\x02\x00\x00\x00\x0E\x74\x52\x4E\x53\x00\x1C\x09\xE5\xF5\x33\xD4\x56\x80\xBB\xA1\x73\xC6\x3E\xEA\x13\xB3\x74\x00\x00\x07\x70\x49\x44\x41\x54\x78\xDA\xED\x5B\xED\x6B\x14\x47\x18\x9F\x5B\x38\x4E\x2A\x07\x77\xB6\xA2\x3D\x63\xD9\x04\x44\x1B\xC9\x87\x50\x62\xAC\xD2\xFD\x24\x7D\xB1\xE5\x50\x8B\x2D\xB5\x41\x2A\xB6\x69\x43\x6B\x88\x06\x84\x5A\x91\x9A\xBE\x50\x28\x04\xAD\x58\x9A\x16\xA5\x51\x44\x4A\x31\x68\xE2\xA7\x82\xA2\x16\xDA\x2F\xF6\xD0\x0A\x42\xDB\xD0\x2F\x1B\x4E\x13\xAF\xFB\x37\x74\x9E\xD9\x99\xCB\xEE\xEC\xCC\xEE\xCC\xEE\x1C\xF1\xC3\x3D\x08\xB7\x3E\xBB\xF7\xDB\xDF\x3D\xF3\xBC\xCE\x6E\x10\x6A\x4B\x5B\xDA\xD2\x96\xB6\xB4\x65\x09\x24\xF7\xC9\x57\x59\xE4\xEB\x83\x31\xD0\x5F\x7A\xD9\xA4\x7E\xC9\x96\x40\x5B\x87\xBD\xCC\x72\x5C\x82\xBD\x21\x3B\xB4\xB7\x50\x12\xD3\xBE\x6E\x00\xDB\x9B\x14\x62\x17\x4C\x40\x7B\x0F\x85\x16\x7F\xDA\x08\x76\xFD\x8E\x08\xDB\x88\x49\x3C\xEF\x47\x91\xB9\xA7\xCC\x60\xEF\x13\x60\xE7\x87\xCD\x60\x3F\x10\x61\x57\x3D\x6F\x6E\x62\x62\xE2\x5B\xB8\xE0\x15\x7C\x00\xF7\x12\x2A\xC8\x41\x9D\x9D\x19\xE2\x14\x42\x6C\xAC\x7F\x09\x2F\x72\xEE\x2C\x46\x38\x44\xD7\xF6\x55\x50\x80\xB1\xAE\x60\x45\x05\x7F\xBE\x8C\xFD\xD7\xBA\x8F\x0F\x0E\xE0\x33\x3D\x18\xB3\xFE\x27\xA7\x78\x24\xC1\x3E\x09\x07\xC7\x3C\x6F\xBE\x44\x7D\x92\x29\xEA\xA0\x28\x56\xA9\x35\xBB\xF1\x99\xCB\xB0\x44\xE3\xD4\xE7\x20\xEA\xC6\xE0\xCC\xB8\x1C\x9B\xAC\xF1\x33\x18\x9B\x64\x17\xAC\x38\x11\x52\x54\xA9\x62\x39\x3E\x33\x42\x5D\xEB\x01\x0B\x8D\xCB\x94\x46\x2C\xF6\x5E\x1C\xB9\x4C\x21\xC6\x5E\x26\xC2\x1E\x51\xC0\xB6\x96\x96\xF7\xF2\x2C\xBC\x17\x5A\xC5\xFB\x5F\x0C\x65\x53\xC5\x37\xA0\x78\xCA\xF3\x1A\xB6\xCC\xDE\x8F\xD8\xCD\x92\xB0\x4F\xD2\x2F\x34\x4A\xF4\x0B\xBD\xA0\xB8\x4A\x7D\xB0\x80\xB1\x0F\x20\xEA\xE8\x63\x34\x4D\x6C\xB7\xA9\x53\x9E\xA3\x0A\x19\xF6\xF6\xBB\xE5\xF2\x2A\xEC\xFF\x73\x97\xCA\xE5\xF2\x61\x5E\x71\x94\x2A\xCA\x9F\x43\x54\xE1\xCF\xD5\x10\xCA\x57\xF0\xC1\x55\xAA\x58\x53\x95\x63\xCF\x6D\xC3\x02\x81\xBC\x8D\x1E\x10\x45\x95\x1E\x54\xD9\x19\xF8\x3F\x53\x54\xB7\x71\x67\x64\xD8\x26\xA4\x8D\xFD\x78\x60\xCF\xDD\xBE\x7D\xFB\x37\xB8\xE0\x35\x7C\x30\xCC\x14\x55\xAA\x78\x17\x14\x1F\xD1\x33\x75\x76\x29\xAF\x90\x61\x43\x29\xC8\xD7\x30\xC2\x34\x56\x0C\xC0\x85\xA0\x60\xB5\x61\x0F\xB4\x08\x25\xDA\x7F\xBD\x80\xCF\x14\x30\xA6\x7B\x87\x2A\xFA\x51\x7C\x6D\xB8\x49\xE3\xB6\xC1\x6A\xC3\xCD\x50\x6D\x60\x81\x0A\x61\x38\xCD\xC2\x10\xE2\x72\x23\x8B\xCB\xEB\xC9\xB5\xA1\x99\xAB\x6E\x50\x45\x83\xE5\xAA\x1B\x99\xF2\x60\x28\xC7\xB6\x0A\x3B\x17\xF8\x21\x4B\xC8\x7B\xBD\x06\x76\xA4\xA6\x19\xE0\x7D\x82\xD5\x86\x08\x6F\x56\x1B\x6E\x21\xEA\x16\x11\xDE\x49\xB5\x21\xE2\x83\xFB\x82\x3E\x58\x60\xFD\x49\x25\x50\x0A\x16\x54\x6B\xC3\x96\xB2\x5F\x0A\xBC\x49\x56\x0A\xF0\xE7\xDA\x1A\xAD\x0D\xB3\x30\x17\xDC\xE5\x4A\x81\x72\x6D\x60\xF9\x3D\x52\x0A\xC4\x8A\x66\x19\xA9\x06\x14\x66\x73\x55\x95\x7E\xCE\xB5\xF3\xF7\xE3\x54\x1B\x06\xB1\xC0\x05\x2F\xE2\xCF\x61\x91\xC2\x03\x45\x35\x0D\x36\xD4\x86\xE2\x59\x5A\x1B\x60\x6E\x78\x54\xF2\x07\x09\x77\x92\x2A\xB6\x43\x6D\x18\x4D\x83\x1D\x1A\x13\x22\x71\x59\x64\x91\xDB\x9D\x06\xFB\x84\x6C\x6E\x68\xE6\xAA\x77\x58\xAE\x4A\x87\xBD\x37\x90\xAB\x22\x3D\xB2\x00\xDB\xDD\x34\xF1\xF3\x2F\x13\xFB\x1D\x1D\xEC\x20\xEF\xBA\x1C\xFB\xF9\x6B\x64\x82\xB7\xFE\x39\x95\x89\xB7\x13\xC5\x76\x2F\x96\x19\x40\xE7\x11\x27\x03\xEF\x28\xB6\x1B\xDA\xD2\xA8\x38\x9E\x46\x6D\x48\xE0\xED\x5E\x08\xED\x68\x58\x7F\x3B\x69\xFB\x93\xA6\x53\x3E\xCB\xA0\xE9\xF6\x54\xE7\xCA\x9D\x65\xDF\xE8\x7F\xC9\xB1\x17\x56\x74\x75\xF5\x90\xDA\xD0\xD5\xD5\x75\x5F\xA4\x98\xC7\x8A\xCE\x19\x8A\xBD\xD5\xF6\xED\x3C\xB1\x7F\x70\xE8\xFB\x83\xA4\xEC\x9D\x97\xE7\x93\xE7\xB0\x10\x46\xF8\xD3\x89\x55\x78\xFE\x28\x8F\xD0\xDB\xA7\x7C\xEF\xDB\x74\x71\x05\x94\x52\xC7\x4C\xAE\x22\x51\xBC\x66\x71\x6B\xE4\x43\x30\xDC\x61\x23\xD8\x5B\x4A\x61\x68\x1F\xBC\xF8\x83\x01\x6C\x17\xF2\x19\xE4\xB1\x80\xEA\x0C\x56\xAD\x35\x80\x4D\x1A\x58\x6E\xB7\xD2\x3D\x84\x90\x9D\x1D\x9B\xD0\xDE\xE8\x70\xDA\xAD\xE2\x3D\xD3\x3C\xCD\xFC\xFB\xC9\x37\x07\x05\x12\x41\xB1\x66\x22\x77\x9C\x94\x62\xC3\x17\x8A\xB0\x3A\xEF\x0B\xB6\x3E\x3B\x67\x22\xB4\x55\xF7\x4C\x83\x71\xE9\xEE\x10\x6D\xF2\x6D\x4C\xA4\x8D\x2B\xD6\x24\x4A\xCA\x27\x36\x8A\x5F\x11\xF7\xB2\x98\xB6\x3F\x10\x25\xF7\xC8\xD1\xED\xF1\x30\xED\xDC\x8C\x70\x91\xA7\x55\x72\x6C\x0C\xB6\x3B\x22\xA3\x8D\x07\x38\x95\xB9\x21\x06\xBB\xDF\x96\xEF\xDF\xF6\x67\xE3\x4D\x68\xA3\x51\x8D\xFD\xD8\xE0\xE8\x64\xC7\x62\x13\xDA\x92\x4E\xC2\xBD\x93\xC6\x07\x9B\x06\x26\x5F\xB7\x51\xD1\x51\x35\x37\xC1\x86\x36\xAA\xA7\x06\xCC\x56\xC4\xC4\x0E\x8C\xDB\xB9\x6B\xE2\x67\x08\x70\xDF\xCE\x52\x62\x6D\x88\x48\x90\x76\x05\x97\xBD\x0E\x01\xF6\x1F\x38\xB0\xCF\xF7\xDB\x69\x73\xD5\x19\x7F\x68\x9A\x26\x3D\x9C\x80\xF6\xAC\x1F\x59\x69\xB0\xC1\x6E\x30\xA9\xF5\x8A\x76\xFA\x81\x76\x8D\x2D\xB6\x3E\x36\x29\x09\xFE\xF0\x37\xC0\x9F\x6B\x10\xDA\xCC\x49\x03\x1E\xE6\x28\x41\x93\x0C\x5D\xF1\x7F\x7E\x41\x40\x9B\xB8\x02\x1F\x40\xB9\x29\x2D\xDA\xE0\xB0\xBC\x51\x80\xF6\x3D\xFF\x88\x73\xE2\x63\x2A\xD0\xBF\x03\xED\x59\x3F\x55\xDB\x84\x7F\xF8\x99\x14\xAB\x44\xEF\x85\xB1\xBB\x55\x9E\x0C\xC1\x42\xAE\x77\xD8\x4F\xC8\xD5\xB8\x0A\xDA\xFC\xF1\xF5\xB0\x8F\x87\x2F\x8C\x79\x5A\x36\xBA\x18\x82\xAF\x73\xA5\x68\xF1\x87\x9C\x0B\xD7\x95\xA3\x6A\x4F\xF9\x56\xB1\x45\xC7\xE1\xC3\x95\xA2\xC0\x9A\x71\xB1\x5F\xA8\xA9\xD0\xC6\x2D\xDF\x22\xB7\xC0\x6A\x86\x69\x47\xD2\xF4\x1E\x47\x81\x76\x25\x94\xAA\x3B\x24\xB4\x23\xF9\xD0\x3A\xF2\x6B\x22\xED\xFC\x54\x68\x65\x9B\xC9\x10\xDA\x9E\x90\xDB\x9C\xE3\x4B\xF9\xCA\xDD\x71\x02\xB4\x3B\xC2\x37\x6B\xCE\x9A\xFD\x36\x17\x21\xBD\xD1\x4C\x6A\x5B\xD2\x7F\x24\x33\xD4\xB8\x79\xAF\x5B\x42\xDB\xFB\x4F\xFB\x29\x7B\x38\xAF\xE2\xBC\x41\xC9\x46\x68\x4B\x6A\x6E\x8C\xE4\x39\x57\xEA\xA3\x77\x03\xDA\x5C\xE6\x6A\xD8\x99\x68\x13\x17\xEF\x71\x28\x6D\xEE\xB6\x6E\x29\x1B\x6D\xE2\x3A\xA3\x7E\x4E\x1D\x50\x29\xCA\x31\x32\x1B\x7D\xCA\x6A\x43\x7A\x11\xD0\x8E\xE4\x70\x6D\xDA\x80\x60\x8D\x8B\x68\xD3\xDD\xC9\x0C\xB4\x49\xDE\xE8\x16\xD1\xA6\x1B\x9D\xAA\x52\x14\xE5\x1B\x5C\x0F\x72\x25\x11\x6D\xEF\xD3\xAC\xB4\x69\xBF\x24\xCA\xCF\x23\x59\x69\xD3\xF9\x5C\x40\x5B\x67\x2D\xAD\x01\x79\x06\x13\x2C\xB2\x96\x0F\x4A\xB3\x3B\x9E\x14\x44\x26\xD1\x88\x1D\xEB\x9E\x34\xF5\x8E\xF1\x69\x4A\x37\xE6\x0B\x4E\x5C\xC9\x10\x34\x20\x0F\xD5\x4D\x32\x1A\x5F\x33\xBA\x95\xDE\x8B\x50\x0E\xC9\x30\xF1\x71\x5E\xD9\x9B\x3A\x01\x46\x88\x6F\x10\xAC\x82\xE2\x8B\x57\x53\x49\x45\x9A\xDF\x48\x55\x77\xC1\x65\xC9\xCD\x05\xB7\xD8\xEA\x65\xE7\xC9\x04\x6C\xE8\x2D\x3B\xF8\x8A\xA4\xE8\xDC\x89\x3D\x6E\xA4\x5E\x2A\x9B\x3B\x9F\xD8\x9B\x43\xC1\x5C\xCD\x67\x19\x25\x51\x68\x71\x1F\x86\x97\xB3\xCF\x98\xB9\x59\xCA\x9A\xD2\x4F\x82\x96\x4A\xDB\xDF\xD8\x85\xAD\xC2\x6C\xB7\xD9\x36\xB7\x94\xB4\xF3\x6C\x5A\x65\x0C\x99\x5B\x4A\x62\x87\xE3\xCD\x18\xDB\xAC\x91\x03\x15\xDF\xEF\xDB\xC1\xAC\x32\x86\x4C\x63\x93\x91\x15\x7A\x78\x0D\xDA\xEA\x2F\x2D\x1E\x27\x26\x77\x75\x2A\xBC\x32\xF6\x02\x8E\xA0\xFC\x67\x3A\xB4\x95\xA6\xC3\xC5\x5D\xB6\xF5\x5A\x0D\x95\x3A\x76\x64\x97\xC0\x24\xB6\xFB\x85\x26\xB6\xCE\x0B\xA8\x9A\xED\x6B\x4B\xB1\x75\xDE\x40\xD5\x35\xB8\x06\x36\xE4\x71\xBD\x9E\xDE\x69\x9D\x9F\xA8\xBF\x82\xAA\x4D\x9B\xBC\x2A\xA9\x48\x5B\xFF\xBD\xF0\xBD\xAD\xA3\xAD\x1C\x3C\x29\x68\xAB\x3A\xCA\xFC\xAE\x14\xD8\x8A\x7B\x70\x7D\x28\x8D\x1C\x6B\x19\x6D\x84\x9E\x68\x1D\x6D\x94\x3F\xAB\x40\x7B\x47\x3A\xEC\xD8\xB1\x21\x1B\x6D\x15\x4F\x49\x4D\x5B\x30\x73\xF0\x72\x1A\xA5\x96\x4A\xCB\x68\x27\xBB\x78\x06\xDA\x49\xC4\xB3\xD0\x0E\x6F\x3A\x1A\xA6\x1D\xFF\xF7\x0F\xD9\x68\xF3\xCF\x9D\x8D\xD2\x46\xE8\xAD\x96\xD1\x8E\x0B\xFC\x9B\x08\xB5\x8A\xF8\x7C\x29\x3B\xB6\x8C\xB8\x01\xDA\x32\xE2\x26\x68\xCB\x88\x9F\x44\x46\xE4\x0D\x4F\xF5\x91\x7C\x0A\xE2\xC3\x2D\xA3\x2D\xB2\xB8\x29\xDA\x22\x8B\x4F\x22\x63\xC2\xA7\xC3\x0F\x4A\xE6\xB0\xAD\xF0\xDF\xDE\xD5\x0F\x21\x83\xB2\x2E\x08\x5E\xBF\x80\x8C\x4A\xE0\xAF\x06\xEB\xA7\x6D\xB3\xD8\x68\xDD\xC7\xD4\x13\x07\x2F\x98\x86\xC6\xF2\xE6\x4F\x83\x5E\x7D\xE8\xBB\x9D\xA8\x15\xD2\xB9\x72\xF7\xEE\x9D\x25\xD4\x96\xB6\xB4\xA5\x2D\x6D\x59\x52\xF9\x1F\xCA\x06\x82\x80\x90\xD2\xCA\x30\x00\x00\x00\x00\x49\x45\x4E\x44\xAE\x42\x60\x82"