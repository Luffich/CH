local ffi = require("ffi")
local hook_t = require("hooks")
local samem = require("SAMemory")
local inicfg = require("inicfg")

samem.require("CCam")

local cfg = inicfg.load {
	main = {
		asp = 1
	}
}

local CCam_Process_Hook
local fAspectRatio = ffi.cast("float*", 0xC3EFA4)
local old = 70

function main()
	while not isSampAvailable() do wait(0) end

	ffi.fill(ffi.cast("void*", 0x6FF452), 6, 0x90)
	ffi.fill(ffi.cast("void*", 0x524B7F), 2, 0x90)
	fAspectRatio[0] = cfg.main.asp

	sampRegisterChatCommand("asp", function(asp)
		asp = tonumber(asp)
		if asp then
			if asp < 0.1 or asp > 1 then
				asp = fAspectRatio[0]
			end
			fAspectRatio[0] = asp
			cfg.main.asp = fAspectRatio[0]
			inicfg.save(cfg)
			printString(("Aspect Ratio: %s"):format(fAspectRatio[0]), 1000)
		else
			printString("Use /asp [value]", 1000)
		end
	end)

	local function CCam_Process(cam)
		local result

		if cam.nMode ~= ffi.C.MODE_SNIPER then
			cam.fFOV = old
			result = CCam_Process_Hook(cam)

			if cam.nMode == ffi.C.MODE_BEHINDCAR or cam.nMode == ffi.C.MODE_CAM_ON_A_STRING or cam.nMode == ffi.C.MODE_BEHINDBOAT then
				old = cam.fFOV
			elseif cam.nMode == ffi.C.MODE_AIMWEAPON_FROMCAR then
				old = cam.fFOV
			else
				old = 70
			end

			local fov = (cam.fFOV * fAspectRatio[0]) * 0.8
			if fov > 120 then fov = 120 end
			cam.fFOV = fov
		else
			result = CCam_Process_Hook(cam)
		end

		return result
	end

	CCam_Process_Hook = hook_t.jmp.new("void(__thiscall*)(CCam *this)", CCam_Process, 0x526FC0)

	wait(-1)
end