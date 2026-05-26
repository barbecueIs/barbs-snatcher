local Patcher = {}

function Patcher.PatchInstances(Instances, Mapping)
	for _, Inst in ipairs(Instances) do
		if Inst:IsA("Sound") then
			local Id = Inst.SoundId:match("%d+")
			if Id and Mapping[Id] then
				Inst.SoundId = "rbxassetid://" .. Mapping[Id]
			end
		end

		if Inst:IsA("LuaSourceContainer") then
			local Ok, Source = pcall(function() return Inst.Source end)
			if Ok and Source and Source ~= "" then
				local NewSource = Source
				local Changed = false
				for OldId, NewId in pairs(Mapping) do
					local Pattern = "rbxassetid://" .. OldId
					if NewSource:find(Pattern, 1, true) then
						NewSource = NewSource:gsub(Pattern, "rbxassetid://" .. NewId)
						Changed = true
					end
				end
				if Changed then
					pcall(function() Inst.Source = NewSource end)
				end
			end
		end

		if Inst:IsA("StringValue") and Inst.Value ~= "" then
			local NewVal = Inst.Value
			local Changed = false
			for OldId, NewId in pairs(Mapping) do
				local Pattern = "rbxassetid://" .. OldId
				if NewVal:find(Pattern, 1, true) then
					NewVal = NewVal:gsub(Pattern, "rbxassetid://" .. NewId)
					Changed = true
				end
			end
			if Changed then Inst.Value = NewVal end
		end

		if Inst:IsA("IntValue") then
			local Id = tostring(Inst.Value)
			if Mapping[Id] then
				local NewId = tonumber(Mapping[Id])
				if NewId then Inst.Value = NewId end
			end
		end
	end
end

return Patcher
