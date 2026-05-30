local Modules = script:WaitForChild("Modules")
local Scanner = require(Modules:WaitForChild("Scanner"))
local Network = require(Modules:WaitForChild("Network"))
local Patcher = require(Modules:WaitForChild("Patcher"))
local UI = require(Modules:WaitForChild("UI"))

local BtnSoundAll, BtnSoundSel = UI.Init(plugin, script)

local function RunProcess(ScopeMode)
	UI.SetStatus("SCANNING...")
	local Instances = Scanner.GetInstances(ScopeMode)
	local Config = UI.GetConfig()
	local Ids, Names = Scanner.ScanForSounds(Instances, Config)

	if #Ids == 0 then
		UI.SetStatus("NO SOUNDS FOUND")
		return
	end

	UI.SetStatus("FOUND " .. #Ids .. " IDS, CONNECTING...")

	local PostOk = Network.PostSounds(Ids, Names, Config.PlaceIds)
	if not PostOk then
		UI.SetStatus("ERROR: APP OFFLINE")
		return
	end

	local Done = false
	while not Done do
		task.wait(1)
		local PollOk, Data = Network.PollStatus()

		if not PollOk then
			UI.SetStatus("ERROR: LOST CONNECTION")
			Done = true
		else
			if Data.status == "complete" then
				Done = true
				Patcher.PatchInstances(Instances, Data.mapping)
				UI.SetStatus("DONE: " .. (Data.ok or 0) .. " OK, " .. (Data.failed or 0) .. " FAILED")
			elseif Data.status == "error" then
				Done = true
				UI.SetStatus("ERROR: " .. (Data.error or "UNKNOWN"))
			elseif Data.status == "running" then
				UI.SetStatus("PROCESSING " .. (Data.done or 0) .. "/" .. (Data.total or #Ids) .. "...")
			end
		end
	end
end

BtnSoundAll.MouseButton1Click:Connect(function() task.spawn(RunProcess, "all") end)
BtnSoundSel.MouseButton1Click:Connect(function() task.spawn(RunProcess, "selected") end)
