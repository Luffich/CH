local inicfg = require 'inicfg'
local directIni = 'PohuiNaCarskillByChapo.ini'
local ini = inicfg.load(inicfg.load({
    main = {
        carskill_speed = false,
        anticarskill = true,
    },
}, directIni))
inicfg.save(ini, directIni)

local settings = {
    carskill_speed = ini.main.carskill_speed,
    anticarskill = ini.main.anticarskill,
}

function main()
    while not isSampAvailable() do wait(0) end
    while 'chapo' ~= 'gay' do
        wait(0)
        local result, button, list, input = sampHasDialogRespond(812)
        if result then
            if button == 1 then
                if list == 0 then
                    settings.carskill_speed = not settings.carskill_speed
                elseif list == 1 then
                    settings.anticarskill = not settings.anticarskill
                end
                callDialog()
            end
        end
    end
end

function callDialog()
    ini.main.carskill_speed = settings.carskill_speed
    ini.main.anticarskill = settings.anticarskill
    inicfg.save(ini, directIni)
    sampShowDialog(812, 'Похуй на карскилл by {ff004d}chapo', 'Блокировать изменение скорости: '..(settings.carskill_speed and '{64bf43}включено' or '{ff004d}выключено')..'\nБлокировать падение карскилла: '..(settings.anticarskill and '{64bf43}включено' or '{ff004d}выключено'), 'Выбрать', 'Закрыть', 4)
end

function onSendRpc(id, bs)
    if id == 50 then
        local cmd_len = raknetBitStreamReadInt32(bs)
        local cmd_text = raknetBitStreamReadString(bs, cmd_len)
        if cmd_text == '/cskill' then
            callDialog()
            return false
        end
    elseif id == 106 and settings.anticarskill then
        return false
    end
end

function onReceiveRpc(id, bs)
    --INCOMING_RPCS[RPC.SETVEHICLEVELOCITY]         = {'onSetVehicleVelocity', {turn = 'bool8'}, {velocity = 'vector3d'}}
    if id == 91 and settings.carskill_speed then
        local MINIMUM_VALUE = 0.05
        local turn = raknetBitStreamReadBool(bs)
        local x = raknetBitStreamReadFloat(bs)
        local y = raknetBitStreamReadFloat(bs)
        local z = raknetBitStreamReadFloat(bs)
        --if x < MINIMUM_VALUE or y < MINIMUM_VALUE or z < MINIMUM_VALUE then 
            return false 
        --end
    end
end