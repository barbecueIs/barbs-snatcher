local HttpService = game:GetService("HttpService")

local Network = {}
Network.HOST = "http://127.0.0.1:54321"

function Network.PostSounds(Ids, Names, PlaceIds)
	local CreatorType = game.CreatorType == Enum.CreatorType.Group and "Group" or "User"
	local CreatorId = game.CreatorId
	local Payload = HttpService:JSONEncode({
		ids = Ids,
		names = Names,
		placeIds = PlaceIds,
		creatorType = CreatorType,
		creatorId = CreatorId,
	})
	local PostOk = pcall(function()
		return HttpService:PostAsync(Network.HOST .. "/sounds-process", Payload, Enum.HttpContentType.ApplicationJson)
	end)
	return PostOk
end

function Network.PollStatus()
	local PollOk, PollRes = pcall(function()
		return HttpService:GetAsync(Network.HOST .. "/sounds-status")
	end)
	if not PollOk then
		return false, nil
	end
	local Data = HttpService:JSONDecode(PollRes)
	return true, Data
end

function Network.PostAnimations(Ids, Names, PlaceIds)
	local CreatorType = game.CreatorType == Enum.CreatorType.Group and "Group" or "User"
	local CreatorId = game.CreatorId
	local Payload = HttpService:JSONEncode({
		ids = Ids,
		names = Names,
		placeIds = PlaceIds,
		creatorType = CreatorType,
		creatorId = CreatorId,
	})
	local PostOk = pcall(function()
		return HttpService:PostAsync(Network.HOST .. "/animations-process", Payload, Enum.HttpContentType.ApplicationJson)
	end)
	return PostOk
end

function Network.PostMonetization(Items, UniverseId, PlaceIds)
	local CreatorType = game.CreatorType == Enum.CreatorType.Group and "Group" or "User"
	local CreatorId = game.CreatorId
	local Payload = HttpService:JSONEncode({
		items = Items,
		universeId = UniverseId,
		placeIds = PlaceIds,
		creatorType = CreatorType,
		creatorId = CreatorId,
	})
	local PostOk = pcall(function()
		return HttpService:PostAsync(Network.HOST .. "/monetization-process", Payload, Enum.HttpContentType.ApplicationJson)
	end)
	return PostOk
end

function Network.PollMonetizationStatus()
	local PollOk, PollRes = pcall(function()
		return HttpService:GetAsync(Network.HOST .. "/monetization-status")
	end)
	if not PollOk then
		return false, nil
	end
	local Data = HttpService:JSONDecode(PollRes)
	return true, Data
end

function Network.PollAnimationStatus()
	local PollOk, PollRes = pcall(function()
		return HttpService:GetAsync(Network.HOST .. "/animations-status")
	end)
	if not PollOk then
		return false, nil
	end
	local Data = HttpService:JSONDecode(PollRes)
	return true, Data
end

return Network
