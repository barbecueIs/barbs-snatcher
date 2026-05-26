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

return Scanner
