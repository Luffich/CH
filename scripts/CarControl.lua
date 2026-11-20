--====================================================--
--####################################################--
--#####          _                              ######--
--#####         | |                             ######--
--#####    ___  | |__     __ _   _ __     ___   ######--
--#####   / __| | '_ \   / _` | | '_ \   / _ \  ######--
--#####  | (__  | | | | | (_| | | |_) | | (_) | ######--
--#####   \___| |_| |_|  \__,_| | .__/   \___/  ######--
--#####                         | |             ######--
--#####                         |_|             ######--
--####################################################--
--#####/----------------------------------------\#####--
--#####|                                        |#####--
--#####|  https://www.blast.hk/members/112329/  |#####--
--#####|                                        |#####--
--#####\----------------------------------------/#####--
--####################################################--
--====================================================--

local imgui = require('imgui')
local encoding = require 'encoding'
encoding.default = 'CP1251'
u8 = encoding.UTF8

local window = imgui.ImBool(false)
local td_Id = 1981
local elements = {
    --doors
    {
        [0] = {imgui.ImBool(true), 'Капот'},
        [1] = {imgui.ImBool(true), 'Багажник'},
        [2] = {imgui.ImBool(true), 'Левая передняя дверь'},
        [3] = {imgui.ImBool(true), 'Правая передняя дверь'},
        [4] = {imgui.ImBool(true), 'Левая задняя дверь'},
        [5] = {imgui.ImBool(true), 'Правая задняя дверь'},
    },
    --panels
    {
        [0] = {imgui.ImBool(true), 'nil'},
        [1] = {imgui.ImBool(true), 'nil'},
        [2] = {imgui.ImBool(true), 'nil'},
        [3] = {imgui.ImBool(true), 'хз дверь'},
        [4] = {imgui.ImBool(true), 'Лобовое стекло'},
        [5] = {imgui.ImBool(true), 'Передний бампер'},
        [6] = {imgui.ImBool(true), 'Задний бампер'},
    }
}

local winPos = {x = 1, y = 1}

function main()
    while not isSampAvailable() do wait(200) end
    sampRegisterChatCommand('cpc', function()
        window.v = not window.v
    end)
    sampTextdrawCreate(td_Id, _, 1000, 1000)
    sampTextdrawSetStyle(td_Id, 5)
    sampTextdrawSetBoxColorAndSize(td_Id, 0, 0xFFff004d, 100, 100)
    sampTextdrawSetModelRotationZoomVehColor(td_Id, 560, 270, 0, 180, 1, 3, 3)
    sampTextdrawSetShadow(td_Id, _, 0x00)
    imgui.Process = false
    window.v = false  --show window
    while true do
        wait(0)
        imgui.Process = window.v
        if isCharInAnyCar(PLAYER_PED) and not isCharOnAnyBike(PLAYER_PED) and not isCharInAnyHeli(PLAYER_PED) and not isCharInAnyTrain(PLAYER_PED) and not isCharInAnyBoat(PLAYER_PED) and not isCharInAnyHeli(PLAYER_PED) then
            local veh = storeCarCharIsInNoSave(PLAYER_PED)
            if POHUI_NA_NAZVANIYE(getCarModel(veh)) then
                --doors
                for i = 0, 5 do
                    if not elements[1][i][1].v then
                        popCarDoor(veh, i)
                    else
                        fixCarDoor(veh, i)
                    end
                end
                --panels
                for i = 0, 6 do
                    if not elements[2][i][1].v then
                        popCarPanel(veh, i)
                    else
                        fixCarPanel(veh, i)
                    end
                end
                
            end
        end
        if window.v then
            local tx, ty = convertWindowScreenCoordsToGameScreenCoords(winPos.x - 50, winPos.y)
            sampTextdrawSetPos(td_Id, tx, ty)
        else
            sampTextdrawSetPos(td_Id, 1000, 1000)
        end
    end
end

function POHUI_NA_NAZVANIYE(model)
    local MEFEDRON = {
        581,
        509,
        481,
        462,
        521,
        463,
        510,
        522,
        461,
        448,
        468,
        586,
    }
    for i = 1, #MEFEDRON do
        if MEFEDRON[i] == model then
            return false
        end
    end
    return true
end

function onScriptTerminate(s, q)
    if s == thisScript() then
        if sampTextdrawIsExists(td_Id) then
            sampTextdrawDelete(td_Id)
        end
    end
end

function imgui.OnDrawFrame()
    if window.v then
        local resX, resY = getScreenResolution()
        imgui.SetNextWindowPos(imgui.ImVec2(resX / 2 - 200 / 2, resY / 2 - 245 / 2), imgui.Cond.FirstUseEver)
        imgui.SetNextWindowSize(imgui.ImVec2(200, 310), imgui.Cond.FirstUseEver)
        imgui.Begin('Window Title', window, imgui.WindowFlags.NoResize + imgui.WindowFlags.NoTitleBar)
        wp = imgui.GetWindowPos()
        winPos.x = wp.x
        winPos.y = wp.y
        
        imgui.SetCursorPos(imgui.ImVec2(90, 50))   imgui.HoveredCheckbox(1, 0)
        imgui.SetCursorPos(imgui.ImVec2(90, 190))  imgui.HoveredCheckbox(1, 1)
        imgui.SetCursorPos(imgui.ImVec2(50, 100))  imgui.HoveredCheckbox(1, 2)
        imgui.SetCursorPos(imgui.ImVec2(135, 100)) imgui.HoveredCheckbox(1, 3)
        imgui.SetCursorPos(imgui.ImVec2(50, 140))  imgui.HoveredCheckbox(1, 4)
        imgui.SetCursorPos(imgui.ImVec2(135, 140)) imgui.HoveredCheckbox(1, 5)
        imgui.NewLine()imgui.NewLine()imgui.NewLine()
        imgui.SetCursorPosX(5) imgui.Checkbox(u8'Лобовое стекло', elements[2][4][1])
        imgui.SetCursorPosX(5) imgui.Checkbox(u8'Передний бампер', elements[2][5][1])
        imgui.SetCursorPosX(5) imgui.Checkbox(u8'Задний бампер', elements[2][6][1])
    
        imgui.SetCursorPos(imgui.ImVec2(50, 290))
        if imgui.Button(u8'Закрыть', imgui.ImVec2(100, 20)) then
            window.v = false
        end

        imgui.End()
    end
end

function imgui.HoveredCheckbox(s, id)
    imgui.Checkbox('##'..tostring(s)..' '..tostring(id), elements[s][id][1])
    if imgui.IsItemHovered() then
        imgui.BeginTooltip()
            imgui.Text(u8(elements[s][id][2]))
        imgui.EndTooltip()
    end
end

--==[IMGUI FUNCS]==--
function applyTheme()
    imgui.SwitchContext()
    local style = imgui.GetStyle()
    local colors = style.Colors
    local clr = imgui.Col
    local ImVec4 = imgui.ImVec4
    local ImVec2 = imgui.ImVec2
    style.FrameRounding = 5.0
    colors[clr.WindowBg] = ImVec4(0.13, 0.14, 0.17, 0.2)
    colors[clr.FrameBg] = ImVec4(0.200, 0.220, 0.270, 0.85)
    colors[clr.Button] = ImVec4(1, 0, 0.3, 1.00)
    colors[clr.CheckMark] = ImVec4(1, 0, 0.3, 1.00)
end
applyTheme()