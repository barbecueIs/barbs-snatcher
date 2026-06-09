local Selection = game:GetService("Selection")

local Scanner = {}

function Scanner.GetInstances(ScopeMode)
	if ScopeMode == "all" then return game:GetDescendants() end
	local Selected = Selection:Get()
	local Instances = {}
	local Seen = {}
	for _, Sel in ipairs(Selected) do
		if not Seen[Sel] then
			Seen[Sel] = true
			table.insert(Instances, Sel)
		end
		for _, Desc in ipairs(Sel:GetDescendants()) do
			if not Seen[Desc] then
				Seen[Desc] = true
				table.insert(Instances, Desc)
			end
		end
	end
	return Instances
end

function Scanner.ScanForSounds(Instances, Config)
	local Ids = {}
	local Names = {}
	local Seen = {}
	local DoScripts = Config.LookInScripts
	local DoIntValues = Config.LookInIntValues
	local DoAllValues = Config.LookInAllValues

	for _, Inst in ipairs(Instances) do
		if Inst:IsA("Sound") and Inst.SoundId ~= "" then
			local Id = Inst.SoundId:match("%d+")
			if Id and Id ~= "0" and not Seen[Id] then
				Seen[Id] = true
				table.insert(Ids, Id)
				Names[Id] = Inst.Name
			end
		end

		if DoScripts and Inst:IsA("LuaSourceContainer") then
			local Ok, Source = pcall(function() return Inst.Source end)
			if Ok and Source then
				for MatchedId in Source:gmatch("rbxassetid://(%d+)") do
					if not Seen[MatchedId] then
						Seen[MatchedId] = true
						table.insert(Ids, MatchedId)
						Names[MatchedId] = Inst.Name
					end
				end
			end
		end

		if DoIntValues and Inst:IsA("IntValue") and Inst.Value > 0 then
			local Id = tostring(Inst.Value)
			if not Seen[Id] then
				Seen[Id] = true
				table.insert(Ids, Id)
				Names[Id] = Inst.Name
			end
		end

		if DoAllValues and Inst:IsA("StringValue") and Inst.Value ~= "" then
			for MatchedId in Inst.Value:gmatch("rbxassetid://(%d+)") do
				if not Seen[MatchedId] then
					Seen[MatchedId] = true
					table.insert(Ids, MatchedId)
					Names[MatchedId] = Inst.Name
				end
			end
		end
	end
	return Ids, Names
end

function Scanner.ScanForMonetizationCandidates(Instances)
	local Seen = {}
	local Candidates = {}

	for _, Inst in ipairs(Instances) do
		pcall(function()
			for Name, Value in pairs(Inst:GetAttributes()) do
				local Lower = string.lower(Name)
				if string.find(Lower, "gamepass") or string.find(Lower, "product") or string.find(Lower, "passid") then
					local Num = tonumber(tostring(Value))
					if Num and Num >= 100000000 then
						local Id = tostring(math.floor(Num))
						if not Seen[Id] then
							Seen[Id] = true
							table.insert(Candidates, Id)
						end
					end
				end
			end
		end)
	end

	for _, Inst in ipairs(Instances) do
		if Inst:IsA("LuaSourceContainer") then
			pcall(function()
				for NumStr in Inst.Source:gmatch("%d+") do
					local Num = tonumber(NumStr)
					if Num and Num >= 100000000 and Num <= 99999999999 then
						local Id = tostring(Num)
						if not Seen[Id] then
							Seen[Id] = true
							table.insert(Candidates, Id)
						end
					end
				end
			end)
		end
	end

	return Candidates
end

function Scanner.ScanForAnimations(Instances)
	local Ids = {}
	local Names = {}
	local Seen = {}

	for _, Inst in ipairs(Instances) do
		if Inst:IsA("Animation") and Inst.AnimationId ~= "" then
			local Id = Inst.AnimationId:match("rbxassetid://(%d+)") or Inst.AnimationId:match("id=(%d+)")
			if Id and Id ~= "0" and not Seen[Id] then
				Seen[Id] = true
				table.insert(Ids, Id)
				Names[Id] = Inst.Name
			end
		end
	end

	return Ids, Names
end

function Scanner.FilterOwnedIds(Ids, Names)
	local MarketplaceService = game:GetService("MarketplaceService")
	local FilteredIds = {}
	local FilteredNames = {}
	local SkippedCount = 0

	for _, Id in ipairs(Ids) do
		local NumId = tonumber(Id)
		local IsOwned = false

		if NumId then
			local Ok, Info = pcall(function()
				return MarketplaceService:GetProductInfo(NumId)
			end)
			if Ok and Info and Info.Creator then
				if game.CreatorType == Enum.CreatorType.Group then
					IsOwned = Info.Creator.CreatorType == "Group" and Info.Creator.CreatorTargetId == game.CreatorId
				else
					IsOwned = Info.Creator.CreatorType == "User" and Info.Creator.CreatorTargetId == game.CreatorId
				end
			end
			task.wait(0.05)
		end

		if IsOwned then
			SkippedCount = SkippedCount + 1
		else
			table.insert(FilteredIds, Id)
			FilteredNames[Id] = Names[Id]
		end
	end

	return FilteredIds, FilteredNames, SkippedCount
end

return Scanner
