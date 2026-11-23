script_name("Old ESC Restore")
script_version("1.0")
script_author("Codex")

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

function main()
    if not isSampLoaded() or not isSampfuncsLoaded() then
        return
    end

    while not isSampAvailable() do
        wait(250)
    end

    sampRegisterChatCommand("oldesc", function()
        applyOldEscFix()
        sampAddChatMessage("{55FF55}[old-esc]{FFFFFF} Старый ESC зафиксирован.", -1)
    end)

    wait(1500)
    applyOldEscFix()
    sampAddChatMessage("{55FF55}[old-esc]{FFFFFF} Фикс загружен. Если вернется новое меню: /oldesc", -1)

    local seconds = 0
    while true do
        wait(1000)
        seconds = seconds + 1

        -- Some client views reset menu flags; re-apply periodically.
        if seconds >= 10 then
            seconds = 0
            applyOldEscFix()
        end
    end
end