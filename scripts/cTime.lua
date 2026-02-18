script_name('TimeOnScreen')
script_author('Meow Brightside')
--[[
  ____       _       _     _       _     _      
 | __ ) _ __(_) __ _| |__ | |_ ___(_) __| | ___ 
 |  _ \| '__| |/ _` | '_ \| __/ __| |/ _` |/ _ \
 | |_) | |  | | (_| | | | | |_\__ \ | (_| |  __/
 |____/|_|  |_|\__, |_| |_|\__|___/_|\__,_|\___|
  ____         |___/          _                 
 |  _ \ _ __ ___ (_) ___  ___| |_ ___           
 | |_) | '__/ _ \| |/ _ \/ __| __/ __|          
 |  __/| | | (_) | |  __/ (__| |_\__ \          
 |_|   |_|  \___// |\___|\___|\__|___/          
               |__/                             
--]]
--~ =========================================================[LIBS]=========================================================
local res                   = pcall(require, 'lib.moonloader')                      assert(res, 'Lib MOONLOADER not found!')
local res                   = pcall(require, 'lib.sampfuncs')                       assert(res, 'Lib SAMPFUNCS not found')
local res, inicfg           = pcall(require, 'inicfg')                              assert(res, 'Lib INICFG not found')
local res, socket           = pcall(require, 'socket')                              assert(res, 'Lib SOCKET not found')
--~ =========================================================[VARS]=========================================================
local moving = false
--~ =========================================================[INI]=========================================================
local f_ini         = getGameDirectory().."\\moonloader\\BrightsideProjects\\TimeOnScreen\\settings.ini"
ini = {
    settings = {
        activate = false,
        x = 300,
        y = 300,
        color = "FFFFFF",
        msColor = "???",
        fontsize = 12
    }
}
local config = inicfg.load(nil, f_ini)
--~ =========================================================[MAIN]=========================================================
function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then error(script_name..' needs SA:MP and SAMPFUNCS!') end
    while not isSampAvailable() do wait(100) end
    ----------------------------------------------------------------
    if config == nil then
        createDirectory(getGameDirectory().."\\moonloader\\BrightsideProjects\\TimeOnScreen")
        local f = io.open(f_ini, "w")
        f:close()
        if inicfg.save(ini, f_ini) then 
            config = inicfg.load(nil, f_ini)
        end
        print("Created default settings.ini") 
    end
    ----------------------------------------------------------------
    font = renderCreateFont("Arial", config.settings.fontsize, 5)
    ----------------------------------------------------------------
    sampRegisterChatCommand('ctime', cmd_stime)
    ----------------------------------------------------------------------
    local hour = tonumber(os.date("%H"))
    local name = sampGetPlayerNickname(select(2, sampGetPlayerIdByCharHandle(PLAYER_PED)))
    if hour >= 5 and hour <= 10 then chatmsg(string.format("Доброе утро, %s! {C3C3C3}(/ctime)", name)) end
    if hour >= 11 and hour <= 16 then chatmsg(string.format("Добрый день, %s! {C3C3C3}(/ctime)", name)) end
    if hour >= 17 and hour <= 22 then chatmsg(string.format("Добрый вече? %s! {C3C3C3}(/ctime)", name)) end
    if hour >= 23 or hour <= 4 then chatmsg(string.format("Доброй ночи, %s! {C3C3C3}(/ctime)", name)) end
    ----------------------------------------------------------------
    while true do
        wait(0)
        if config.settings.activate or moving then
            if moving then
                sampToggleCursor(true)
                local x, y = getCursorPos()
                config.settings.x = x
                config.settings.y = y
                if isKeyJustPressed(0x01) then
                    moving = false
                    sampToggleCursor(false)
                    inicfg.save(config, f_ini)
                end
            end
            local date_table = os.date("*t")
            local ms = tostring(math.ceil(socket.gettime()*1000))
            local ms = tonumber(string.sub(ms, #ms-2, #ms))
            local hour, minute, second = date_table.hour, date_table.min, date_table.sec
            local result = string.format("%02d:%02d:%02d{" ..config.settings.msColor.. "}.%03d", hour, minute, second, ms)

            renderFontDrawText(font, result, config.settings.x, config.settings.y, "0xFF"..config.settings.color)
        end
    end
end
--~ =========================================================[FUNC]=========================================================
function chatmsg(text)
    sampAddChatMessage(string.format("[cTime]: {FFFFFF}%s", text), 0xA77BCA)
end
--~ =========================================================[CMDS]=========================================================
function cmd_stime()
    lua_thread.create(function()
        local dtext = "Отображать время на экране\t" .. (config.settings.activate and "{45d900}ON\n" or "{ff0000}OFF\n") -- 0
        dtext = dtext .. "Размер шрифта:\t" .. config.settings.fontsize .. "\n"                    -- 1
        dtext = dtext .. "Цвет времени:\t{" .. config.settings.color .. "}||||||||||\n"           -- 2
        dtext = dtext .. "Цвет миллисекунд:\t{" .. config.settings.msColor .. "}||||||||||\n"     -- 3
        dtext = dtext .. "Изменить положение\n"                                                  -- 4
        
        sampShowDialog(10, "{A77BCA}Time On Screen", dtext, "OK", "Отмена", DIALOG_STYLE_TABLIST)
        while sampIsDialogActive(10) do wait(0) end
        local result, button, list, input = sampHasDialogRespond(10)

        if result and button == 1 then
            if list == 0 then
                config.settings.activate = not config.settings.activate
                inicfg.save(config, f_ini)
                return true
            end

            if list == 1 then
                sampShowDialog(11, "{A77BCA}Time On Screen", "{FFFFFF}Введит?ново?значение шрифта:", "OK", "Отмена", DIALOG_STYLE_INPUT)
                while sampIsDialogActive(11) do wait(0) end
                local result, button, list, input = sampHasDialogRespond(11)
                if result then
                    if tonumber(input) then
                        config.settings.fontsize = tonumber(input)
                        font = renderCreateFont('Comic Sans MS', config.settings.fontsize, 5)
                        inicfg.save(config, f_ini)
                        return true
                    else
                        chatmsg("Значение должно быть числом!")
                        return true
                    end
                else
                    return true
                end
            end

            if list == 2 then
                sampShowDialog(11, "{A77BCA}Time On Screen", "{FFFFFF}Введит?ново?значение цвет?\n{c3c3c3}Например: AE433D ил?A77BCA (по умолчани?FFFFFF)", "OK", "Отмена", DIALOG_STYLE_INPUT)
                while sampIsDialogActive(11) do wait(0) end
                local result, button, list, input = sampHasDialogRespond(11)
                if result then
                    if not input:match("[?я?ЯЁё]+") then
                        config.settings.color = input
                        inicfg.save(config, f_ini)
                        return true
                    else
                        chatmsg("Неправильный ввод.")
                        return true
                    end
                else
                    return true
                end
            end

            if list == 3 then
                sampShowDialog(11, "{A77BCA}Time On Screen", "{FFFFFF}Введит?ново?значение цвет?\n{c3c3c3}Например: AE433D ил?A77BCA (по умолчани?858585)", "OK", "Отмена", DIALOG_STYLE_INPUT)
                while sampIsDialogActive(11) do wait(0) end
                local result, button, list, input = sampHasDialogRespond(11)
                if result then
                    if not input:match("[?я?ЯЁё]+") then
                        config.settings.msColor = input
                        inicfg.save(config, f_ini)
                        return true
                    else
                        chatmsg("Неправильный ввод.")
                        return true
                    end
                else
                    return true
                end
            end

            if list == 4 then
                moving = true
                chatmsg("Нажмит?ЛК?для сохранен? положения.")
            end
        end
    end)
end