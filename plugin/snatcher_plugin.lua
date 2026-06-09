if not plugin then return end
local Modules = script:WaitForChild("Modules")
local Scanner = require(Modules:WaitForChild("Scanner"))
local Network = require(Modules:WaitForChild("Network"))
local Patcher = require(Modules:WaitForChild("Patcher"))
local UI = require(Modules:WaitForChild("UI"))

local BtnSoundAll, BtnSoundSel, BtnAnimAll, BtnAnimSel, BtnMonetAll, BtnMonetSel = UI.Init(plugin, script)

local function RunSoundProcess(ScopeMode)
	UI.SetStatus("SCANNING...")
	local Instances = Scanner.GetInstances(ScopeMode)
	local Config = UI.GetConfig()
	local Ids, Names = Scanner.ScanForSounds(Instances, Config)

	if #Ids == 0 then
		UI.SetStatus("NO SOUNDS FOUND")
		return
	end

	UI.SetStatus("CHECKING OWNERSHIP (" .. #Ids .. ")...")
	local FilteredIds, FilteredNames, SoundSkipped = Scanner.FilterOwnedIds(Ids, Names)

	if #FilteredIds == 0 then
		UI.SetStatus("ALL " .. #Ids .. " SOUNDS ALREADY OWNED")
		return
	end

	local SkipNote = SoundSkipped > 0 and " (" .. SoundSkipped .. " OWNED)" or ""
	UI.SetStatus("FOUND " .. #FilteredIds .. " IDS" .. SkipNote .. " - CONNECTING...")

	local PostOk = Network.PostSounds(FilteredIds, FilteredNames, Config.PlaceIds)
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
				UI.SetStatus("DONE -" .. (Data.ok or 0) .. " OK, " .. (Data.failed or 0) .. " FAILED")
			elseif Data.status == "error" then
				Done = true
				UI.SetStatus("ERROR: " .. (Data.error or "UNKNOWN"))
			elseif Data.status == "running" then
				UI.SetStatus("PROCESSING " .. (Data.done or 0) .. "/" .. (Data.total or #Ids) .. "...")
			end
		end
	end
end

local function RunAnimProcess(ScopeMode)
	UI.SetAnimStatus("SCANNING...")
	local Instances = Scanner.GetInstances(ScopeMode)
	local Config = UI.GetConfig()
	local Ids, Names = Scanner.ScanForAnimations(Instances)

	if #Ids == 0 then
		UI.SetAnimStatus("NO ANIMATIONS FOUND")
		return
	end

	UI.SetAnimStatus("CHECKING OWNERSHIP (" .. #Ids .. ")...")
	local FilteredIds, FilteredNames, AnimSkipped = Scanner.FilterOwnedIds(Ids, Names)

	if #FilteredIds == 0 then
		UI.SetAnimStatus("ALL " .. #Ids .. " ANIMATIONS ALREADY OWNED")
		return
	end

	local AnimSkipNote = AnimSkipped > 0 and " (" .. AnimSkipped .. " OWNED)" or ""
	UI.SetAnimStatus("FOUND " .. #FilteredIds .. " IDS" .. AnimSkipNote .. " - CONNECTING...")

	local PostOk = Network.PostAnimations(FilteredIds, FilteredNames, Config.PlaceIds)
	if not PostOk then
		UI.SetAnimStatus("ERROR: APP OFFLINE")
		return
	end

	local Done = false
	while not Done do
		task.wait(1)
		local PollOk, Data = Network.PollAnimationStatus()

		if not PollOk then
			UI.SetAnimStatus("ERROR: LOST CONNECTION")
			Done = true
		else
			if Data.status == "complete" then
				Done = true
				Patcher.PatchAnimations(Instances, Data.mapping)
				UI.SetAnimStatus("DONE -" .. (Data.ok or 0) .. " OK, " .. (Data.failed or 0) .. " FAILED")
			elseif Data.status == "error" then
				Done = true
				UI.SetAnimStatus("ERROR: " .. (Data.error or "UNKNOWN"))
			elseif Data.status == "running" then
				UI.SetAnimStatus("PROCESSING " .. (Data.done or 0) .. "/" .. (Data.total or #Ids) .. "...")
			end
		end
	end
end

local function RunMonetProcess(ScopeMode)
	local MarketplaceService = game:GetService("MarketplaceService")

	if game.GameId == 0 then
		UI.SetMonetStatus("ERROR: GAME MUST BE PUBLISHED")
		return
	end

	UI.SetMonetStatus("SCANNING...")
	local Instances = Scanner.GetInstances(ScopeMode)
	local Config = UI.GetConfig()

	local CandidateIds = Scanner.ScanForMonetizationCandidates(Instances)

	if #CandidateIds == 0 then
		UI.SetMonetStatus("NO CANDIDATES FOUND")
		return
	end

	UI.SetMonetStatus("VERIFYING " .. #CandidateIds .. " IDS...")

	local VerifiedItems = {}
	for Index, Id in ipairs(CandidateIds) do
		if Index % 5 == 0 then
			UI.SetMonetStatus("VERIFYING " .. Index .. "/" .. #CandidateIds .. "...")
		end
		local NumId = tonumber(Id)
		if NumId then
			local ProdOk, ProdInfo = pcall(function()
				return MarketplaceService:GetProductInfo(NumId, Enum.InfoType.Product)
			end)
			if ProdOk and ProdInfo and ProdInfo.Name and ProdInfo.Name ~= "" then
				table.insert(VerifiedItems, {
					id = Id,
					type = "DeveloperProduct",
					name = ProdInfo.Name,
					price = ProdInfo.PriceInRobux or 0,
					description = ProdInfo.Description or "",
				})
			else
				local PassOk, PassInfo = pcall(function()
					return MarketplaceService:GetProductInfo(NumId, Enum.InfoType.GamePass)
				end)
				if PassOk and PassInfo and PassInfo.Name and PassInfo.Name ~= "" then
					table.insert(VerifiedItems, {
						id = Id,
						type = "GamePass",
						name = PassInfo.Name,
						price = PassInfo.PriceInRobux or 0,
						description = PassInfo.Description or "",
					})
				end
			end
		end
		task.wait(0.1)
	end

	if #VerifiedItems == 0 then
		UI.SetMonetStatus("NO GAMEPASSES OR PRODUCTS FOUND")
		return
	end

	UI.SetMonetStatus("FOUND " .. #VerifiedItems .. " ITEMS - CONNECTING...")

	local PostOk = Network.PostMonetization(VerifiedItems, game.GameId, Config.PlaceIds)
	if not PostOk then
		UI.SetMonetStatus("ERROR: APP OFFLINE")
		return
	end

	local Done = false
	while not Done do
		task.wait(1)
		local PollOk, Data = Network.PollMonetizationStatus()
		if not PollOk then
			UI.SetMonetStatus("ERROR: LOST CONNECTION")
			Done = true
		else
			if Data.status == "complete" then
				Done = true
				Patcher.PatchMonetization(Instances, Data.mapping)
				UI.SetMonetStatus("DONE - " .. (Data.ok or 0) .. " OK, " .. (Data.failed or 0) .. " FAILED")
			elseif Data.status == "error" then
				Done = true
				UI.SetMonetStatus("ERROR: " .. (Data.error or "UNKNOWN"))
			elseif Data.status == "running" then
				UI.SetMonetStatus("CREATING " .. (Data.done or 0) .. "/" .. (Data.total or #VerifiedItems) .. "...")
			end
		end
	end
end

BtnSoundAll.MouseButton1Click:Connect(function() task.spawn(RunSoundProcess, "all") end)
BtnSoundSel.MouseButton1Click:Connect(function() task.spawn(RunSoundProcess, "selected") end)
BtnAnimAll.MouseButton1Click:Connect(function() task.spawn(RunAnimProcess, "all") end)
BtnAnimSel.MouseButton1Click:Connect(function() task.spawn(RunAnimProcess, "selected") end)
BtnMonetAll.MouseButton1Click:Connect(function() task.spawn(RunMonetProcess, "all") end)
BtnMonetSel.MouseButton1Click:Connect(function() task.spawn(RunMonetProcess, "selected") end)
