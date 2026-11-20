script_name('RestoreSuite')
script_author('quesada / Codex (merged)')
script_version('1.0')

require('lib.moonloader')
local ffi = require('ffi')
local sampev = require 'samp.events'
local acef = require 'arizona-events'


ffi.cdef[[
    void* LoadLibraryA(const char* lpLibFileName);
    void* GetProcAddress(void* hModule, const char* lpProcName);
    int   FreeLibrary(void* hModule);
]]

local kernel32 = ffi.load('kernel32')

local function format_with_dots(num) -- https://www.blast.hk/threads/253262/
    num = math.floor(tonumber(num) or 0)
    local s = tostring(num)
    local rev = s:reverse():gsub("(%d%d%d)", "%1.")
    s = rev:reverse()
    if s:sub(1, 1) == "." then
        s = s:sub(2)
    end
    return s
end

local function parse_k_value(str) -- https://www.blast.hk/threads/253262/
    str = tostring(str or "")
    str = str:gsub("%.", "")
    return tonumber(str) or 0
end

local function build_money(m, kk, k) -- https://www.blast.hk/threads/253262/
    local total = 0
    if m then total = total + (tonumber(m) or 0) * 1000000000 end
    if kk then total = total + (tonumber(kk) or 0) * 1000000 end
    if k then total = total + parse_k_value(k) end
    return format_with_dots(total)
end

local function convert_money_tags(text) -- https://www.blast.hk/threads/253262/
    if type(text) ~= "string" or text == "" then
        return text
    end

    text = text:gsub(":M:%s*(%d+)%s*:KK:%s*(%d+)%s*:K:%s*([%d%.]+)", function(m, kk, k)
        return build_money(m, kk, k)
    end)
    text = text:gsub(":M:%s*(%d+)%s*:KK:%s*(%d+)", function(m, kk)
        return build_money(m, kk, nil)
    end)
    text = text:gsub(":M:%s*(%d+)%s*:K:%s*([%d%.]+)", function(m, k)
        return build_money(m, nil, k)
    end)
    text = text:gsub(":KK:%s*(%d+)%s*:K:%s*([%d%.]+)", function(kk, k)
        return build_money(nil, kk, k)
    end)
    text = text:gsub(":M:%s*(%d+)", function(m)
        return build_money(m, nil, nil)
    end)
    text = text:gsub(":KK:%s*(%d+)", function(kk)
        return build_money(nil, kk, nil)
    end)
    text = text:gsub(":K:%s*([%d%.]+)", function(k)
        return build_money(nil, nil, k)
    end)

    return text
end

local function convert_cash_tags(text)
    if type(text) ~= "string" or text == "" then
        return text
    end

    text = text:gsub(":CASH:%s*([%d%.]+)", function(v)
        return format_with_dots(parse_k_value(v))
    end)

    return text
end

local function loadDll()
    local hDll = kernel32.LoadLibraryA('vorbisFile.dll')
    if hDll == nil or hDll == ffi.cast('void*', 0) then
        print('[RestoreSuite] error in LoadLibraryA')
        return nil, nil
    end
    local fnToggle = kernel32.GetProcAddress(hDll, 'ToggleCefDialogs')
    local fnAreEnabled = kernel32.GetProcAddress(hDll, 'AreCefDialogsEnabled')
    if fnToggle == nil or fnToggle == ffi.cast('void*', 0) then
        print('[RestoreSuite] ToggleCefDialogs not found')
        return nil, nil
    end
    if fnAreEnabled == nil or fnAreEnabled == ffi.cast('void*', 0) then
        print('[RestoreSuite] AreCefDialogsEnabled not found')
        return nil, nil
    end
    return ffi.cast('void(__cdecl*)(int)', fnToggle),
           ffi.cast('int(__cdecl*)(void)', fnAreEnabled)
end

local toggleFn, areEnabledFn

function sampev.onShowDialog(id, style, title, button1, button2, text)
    if style == 6 then
        title = convert_money_tags(title)
        text = convert_money_tags(text)
        return {id, 1, title, button1, button2, text}
    end

    if style == 8 then
        title = convert_cash_tags(title)
        text = convert_cash_tags(text)

        if pendingCurrencyInfo then
            local info = pendingCurrencyInfo
            pendingCurrencyInfo = nil

            if info.money then
                text = text .. ('\n{FFFFFF}Р”РѕСЃС‚СѓРїРЅРѕ: {FFD700}%s'):format(format_with_dots(info.money))
            end
            if info.minMoney and info.maxMoney then
                text = text .. ('\n{AAAAAA}Р›РёРјРёС‚: %s - %s'):format(
                    format_with_dots(info.minMoney), format_with_dots(info.maxMoney)
                )
            end
        end

        return {id, 1, title, button1, button2, text}
    end
end


local WM_KEYDOWN = 0x0100
local VK_ESCAPE = 0x1B

local FIX_JS = [[
try {
  if (window && window.cef && typeof window.cef.HandleGameMenu === 'function') {
    window.cef.HandleGameMenu(false);
  }
  if (typeof window.executeEvent === 'function') {
    window.executeEvent('event.mainMenu.setMainMenuDisabled', `[true]`);
  }
} catch (e) {}
]]

local function evalcef(code, encoded)
    encoded = encoded or 0
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 17)
    raknetBitStreamWriteInt32(bs, 0)
    raknetBitStreamWriteInt16(bs, #code)
    raknetBitStreamWriteInt8(bs, encoded)
    raknetBitStreamWriteString(bs, code)
    raknetEmulPacketReceiveBitStream(220, bs)
    raknetDeleteBitStream(bs)
end

local function applyOldEscFix()
    evalcef(("(() => {%s})()"):format(FIX_JS))
end

function onWindowMessage(msg, wparam, lparam)
    if msg == WM_KEYDOWN and wparam == VK_ESCAPE then
        applyOldEscFix()
    end
end


local function closeTimeWidget()
    local bs = raknetNewBitStream()
    raknetBitStreamWriteInt8(bs, 220)
    raknetBitStreamWriteInt8(bs, 0)
    raknetBitStreamWriteInt8(bs, 27)
    raknetBitStreamWriteInt8(bs, 64)
    raknetSendBitStream(bs)
    raknetDeleteBitStream(bs)
end

local pendingCurrencyInfo = nil

local function extract_json_number(text, key)
    return tonumber(text:match('"' .. key .. '"%s*:%s*(%-?[%d%.]+)'))
end

function acef.onArizonaDisplay(packet)
    local played = tonumber(packet.text:match('"playedHour"%s*:%s*(%d+)'))
    if played then
        local t = os.date('!*t', os.time() + 3 * 3600)

        printStyledString(
            ('~y~%02d %s~n~~w~%02d:%02d~n~ ~g~ Played ~w~%d min.'):format(
                t.day,
                os.date('%B', os.time()),
                t.hour,
                t.min,
                math.floor(played / 60)
            ),
            1500,
            2
        )

        closeTimeWidget()
        return false
    end

    if packet.text:find('"minMoney"', 1, true) and packet.text:find('"maxMoney"', 1, true) then
        pendingCurrencyInfo = {
            minMoney = extract_json_number(packet.text, 'minMoney'),
            maxMoney = extract_json_number(packet.text, 'maxMoney'),
            money    = extract_json_number(packet.text, 'money'),
        }

        return false
    end
end


local TAB_FIX_JS = [[
try {
    function forceDisableCEFTab() {
        if (window && window.cef) {
            for (let key in window.cef) {
                let k = key.toLowerCase();
                if ((k.includes('score') || k.includes('tab')) && typeof window.cef[key] === 'function') {
                    window.cef[key](false);
                }
            }
        }
        if (typeof window.executeEvent === 'function') {
            window.executeEvent('event.scoreboard.setDisabled', `[true]`);
            window.executeEvent('event.scoreboard.setScoreboardDisabled', `[true]`);
        }
    }

    forceDisableCEFTab();

    if (!window._oldTabHook) {
        window._oldTabHook = true;
        const origExec = window.executeEvent;
        if (origExec) {
            window.executeEvent = function(evt, args) {
                let e = evt.toLowerCase();
                if (e.includes('score') || e.includes('tab')) {
                    if (e.includes('show') || e.includes('toggle') || e.includes('enable')) {
                        return;
                    }
                }
                return origExec(evt, args);
            };
        }
        setInterval(forceDisableCEFTab, 2000);
    }
} catch (e) {}
]]

local function applyOldTabFix()
    evalcef(("(() => {%s})()"):format(TAB_FIX_JS))
end

function onSendPacket(id, bs, priority, reliability, orderingChannel)
    if id == 220 then
        raknetBitStreamReadInt8(bs)
        if raknetBitStreamReadInt8(bs) == 18 then
            local strlen = raknetBitStreamReadInt16(bs)
            if raknetBitStreamReadString(bs, strlen):find("onSvelteAppVersion") then
                applyOldTabFix()
            end
        end
        raknetBitStreamResetReadPointer(bs)
    end
end


function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then return end
    while not isSampAvailable() do wait(100) end

    toggleFn, areEnabledFn = loadDll()
    if toggleFn then
        local ok, err = pcall(function() toggleFn(0) end)
        if ok then
            print('[RestoreSuite] CEF Dialogs disabled!')
        else
            print('[RestoreSuite] error call ToggleCefDialogs: ' .. tostring(err))
        end
    else
        print('[RestoreSuite] error load dll! (модуль CEF-диалогов пропущен)')
    end

    wait(1500)
    applyOldEscFix()
    applyOldTabFix()
    sampAddChatMessage("{FFFFFF}RestoreDialogs {AAAAAA}by {FFFFFF}hiroto", -1)

    local escTicker = 0
    local dllTicker = 0
    while true do
        wait(1000)
        escTicker = escTicker + 1
        dllTicker = dllTicker + 1

        if escTicker >= 10 then
            escTicker = 0
            applyOldEscFix()
        end

        if dllTicker >= 2 and areEnabledFn then
            dllTicker = 0
            local ok2, result = pcall(areEnabledFn)
            if ok2 and result ~= 0 then
                pcall(function() toggleFn(0) end)
            end
        end
    end
end