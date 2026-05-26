local TweenService = game:GetService("TweenService")
local Selection = game:GetService("Selection")
local HttpService = game:GetService("HttpService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local HOST = "http://127.0.0.1:54321"

local ACCENT_COLOR = Color3.fromHex("ccff00")
local BORDER_COLOR = Color3.fromHex("1e1e28")
local TEXT_COLOR = Color3.fromHex("f5f5f5")
local MUTED_COLOR = Color3.fromHex("71717a")

local SPRING = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local Toolbar = plugin:CreateToolbar("B-SNATCHER")
local ToolbarButton = Toolbar:CreateButton("Open B-SNATCHER", "Open the B-SNATCHER Plugin UI", "rbxassetid://107814281854748")

local CoreGui = game:GetService("CoreGui")
local ScreenGui = CoreGui:FindFirstChild("BSpoofGui") or script:WaitForChild("BSpoofGui")
if ScreenGui.Parent ~= CoreGui then ScreenGui.Parent = CoreGui end
local MainFrame = ScreenGui:WaitForChild("MainFrame")
local Sidebar = MainFrame:WaitForChild("Sidebar")
local Header = Sidebar:WaitForChild("Header")
local Nav = Sidebar:WaitForChild("Nav")
local Footer = Sidebar:WaitForChild("Footer")
local FooterStatus = Footer:WaitForChild("StatusText")
local MainContent = MainFrame:WaitForChild("MainContent")
local CloseBtn = MainFrame:WaitForChild("CloseBtn")

local PulseActive = Header:WaitForChild("PulseLine"):WaitForChild("PulseActive")
RunService.RenderStepped:Connect(function()
	PulseActive.Position = UDim2.new(0.5 + 0.5 * math.sin(tick() * 2), 0, 0, 0)
end)

local Dragging, DragInput, DragStart, StartPos
MainFrame.InputBegan:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 then
		Dragging = true
		DragStart = Input.Position
		StartPos = MainFrame.Position
	end
end)
MainFrame.InputEnded:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 then
		Dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseMovement then
		DragInput = Input
	end
end)
RunService.RenderStepped:Connect(function()
	if Dragging and DragInput then
		local Delta = DragInput.Position - DragStart
		MainFrame.Position = UDim2.new(
			StartPos.X.Scale, StartPos.X.Offset + Delta.X,
			StartPos.Y.Scale, StartPos.Y.Offset + Delta.Y
		)
	end
end)

local function SetupNav(Btn)
	local Line = Btn:WaitForChild("ActiveLine")
	local Icon = Btn:WaitForChild("Icon")
	Btn.MouseEnter:Connect(function()
		if Line.BackgroundTransparency ~= 0 then
			TweenService:Create(Btn, QUICK, {BackgroundTransparency = 0.95, TextColor3 = TEXT_COLOR}):Play()
			TweenService:Create(Icon, QUICK, {ImageColor3 = TEXT_COLOR}):Play()
		end
	end)
	Btn.MouseLeave:Connect(function()
		if Line.BackgroundTransparency ~= 0 then
			TweenService:Create(Btn, QUICK, {BackgroundTransparency = 1, TextColor3 = MUTED_COLOR}):Play()
			TweenService:Create(Icon, QUICK, {ImageColor3 = MUTED_COLOR}):Play()
		end
	end)
end

local BMain = Nav:WaitForChild("MAINBtn")
local BConfig = Nav:WaitForChild("CONFIGBtn")
SetupNav(BMain)
SetupNav(BConfig)

local VMain = MainContent:WaitForChild("MainView")
local VConfig = MainContent:WaitForChild("ConfigView")

local function SetupCyberBtn(Cont)
	local B = Cont:WaitForChild("Button")
	local Shadow = Cont:WaitForChild("Shadow")
	B.MouseEnter:Connect(function()
		TweenService:Create(B, QUICK, {Position = UDim2.new(0, -2, 0, -2)}):Play()
		TweenService:Create(Shadow, QUICK, {Position = UDim2.new(0, 4, 0, 6)}):Play()
	end)
	B.MouseLeave:Connect(function()
		TweenService:Create(B, QUICK, {Position = UDim2.new(0, 0, 0, 0)}):Play()
		TweenService:Create(Shadow, QUICK, {Position = UDim2.new(0, 4, 0, 4)}):Play()
	end)
	B.MouseButton1Down:Connect(function()
		TweenService:Create(B, QUICK, {Position = UDim2.new(0, 4, 0, 4)}):Play()
		TweenService:Create(Shadow, QUICK, {Position = UDim2.new(0, 0, 0, 0)}):Play()
	end)
	B.MouseButton1Up:Connect(function()
		TweenService:Create(B, QUICK, {Position = UDim2.new(0, -2, 0, -2)}):Play()
		TweenService:Create(Shadow, QUICK, {Position = UDim2.new(0, 4, 0, 6)}):Play()
	end)
	return B
end

local SoundsSection = VMain:WaitForChild("Inner"):WaitForChild("SoundsSection")
local BtnSoundAll = SetupCyberBtn(SoundsSection:WaitForChild("AllCont"))
local BtnSoundSel = SetupCyberBtn(SoundsSection:WaitForChild("SelectedCont"))
local StatusLabel = SoundsSection:WaitForChild("StatusLabel")

local Toggles = VConfig:WaitForChild("Inner"):WaitForChild("Toggles")
local RowScripts = Toggles:WaitForChild("LookInScripts")
local RowIntValues = Toggles:WaitForChild("LookInIntValues")
local RowAllValues = Toggles:WaitForChild("LookInAllValues")

local function RefreshToggle(Row)
	local Active = Row:GetAttribute("Value")
	local Bg = Row:WaitForChild("ToggleBg")
	local Dot = Bg:WaitForChild("Dot")
	TweenService:Create(Dot, QUICK, {
		Position = Active and UDim2.new(1, -14, 0.5, -6) or UDim2.new(0, 2, 0.5, -6),
		BackgroundColor3 = Active and ACCENT_COLOR or MUTED_COLOR,
	}):Play()
	TweenService:Create(Bg, QUICK, {
		BackgroundColor3 = Active and Color3.fromHex("1a2200") or BORDER_COLOR,
	}):Play()
end

local function SetupToggle(Row)
	Row:WaitForChild("ToggleBtn").MouseButton1Click:Connect(function()
		Row:SetAttribute("Value", not Row:GetAttribute("Value"))
		RefreshToggle(Row)
	end)
	RefreshToggle(Row)
end

SetupToggle(RowScripts)
SetupToggle(RowIntValues)
SetupToggle(RowAllValues)

local ActiveView = VMain
local function SwitchView(NewView, ActiveBtn, OtherBtn)
	if ActiveView == NewView then return end
	local AL = ActiveBtn:WaitForChild("ActiveLine")
	local AI = ActiveBtn:WaitForChild("Icon")
	local OL = OtherBtn:WaitForChild("ActiveLine")
	local OI = OtherBtn:WaitForChild("Icon")
	TweenService:Create(OtherBtn, QUICK, {BackgroundTransparency = 1, TextColor3 = MUTED_COLOR}):Play()
	TweenService:Create(OL, QUICK, {BackgroundTransparency = 1}):Play()
	TweenService:Create(OI, QUICK, {ImageColor3 = MUTED_COLOR}):Play()
	TweenService:Create(ActiveBtn, QUICK, {BackgroundTransparency = 0.9, TextColor3 = ACCENT_COLOR}):Play()
	TweenService:Create(AL, QUICK, {BackgroundTransparency = 0}):Play()
	TweenService:Create(AI, QUICK, {ImageColor3 = ACCENT_COLOR}):Play()
	local OldView = ActiveView
	ActiveView = NewView
	NewView.Position = UDim2.new(0, 30, 0, 0)
	NewView.Visible = true
	TweenService:Create(OldView, SPRING, {GroupTransparency = 1, Position = UDim2.new(0, -30, 0, 0)}):Play()
	TweenService:Create(NewView, SPRING, {GroupTransparency = 0, Position = UDim2.new(0, 0, 0, 0)}):Play()
	task.delay(0.5, function()
		if OldView ~= ActiveView then OldView.Visible = false end
	end)
end

BMain.MouseButton1Click:Connect(function() SwitchView(VMain, BMain, BConfig) end)
BConfig.MouseButton1Click:Connect(function() SwitchView(VConfig, BConfig, BMain) end)
CloseBtn.MouseButton1Click:Connect(function() ScreenGui.Enabled = false end)

ToolbarButton.Click:Connect(function()
	ScreenGui.Enabled = not ScreenGui.Enabled
	if ScreenGui.Enabled then
		MainFrame.Position = UDim2.new(0.5, -475, 0.5, -285)
		MainFrame.BackgroundTransparency = 1
		TweenService:Create(MainFrame, SPRING, {
			Position = UDim2.new(0.5, -475, 0.5, -325),
			BackgroundTransparency = 0,
		}):Play()
	end
end)

local function GetInstances(ScopeMode)
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

local function ScanForSounds(Instances)
	local Ids = {}
	local Names = {}
	local Seen = {}
	local DoScripts = RowScripts:GetAttribute("Value")
	local DoIntValues = RowIntValues:GetAttribute("Value")
	local DoAllValues = RowAllValues:GetAttribute("Value")

	for _, Inst in ipairs(Instances) do
		if Inst:IsA("Sound") and Inst.SoundId ~= "" then
			local Id = Inst.SoundId:match("%d+")
			if Id and not Seen[Id] then
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

local function PatchInstances(Instances, Mapping)
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

local function SetStatus(Msg)
	StatusLabel.Text = Msg
	FooterStatus.Text = Msg
end

local function RunProcess(ScopeMode)
	SetStatus("SCANNING...")
	local Instances = GetInstances(ScopeMode)
	local Ids, Names = ScanForSounds(Instances)

	if #Ids == 0 then
		SetStatus("NO SOUNDS FOUND")
		return
	end

	SetStatus("FOUND " .. #Ids .. " IDS — CONNECTING...")

	local Payload = HttpService:JSONEncode({ ids = Ids, names = Names, placeId = game.PlaceId })
	local PostOk = pcall(function()
		return HttpService:PostAsync(HOST .. "/sounds-process", Payload, Enum.HttpContentType.ApplicationJson)
	end)

	if not PostOk then
		SetStatus("ERROR: APP OFFLINE")
		return
	end

	local Done = false
	while not Done do
		task.wait(1)
		local PollOk, PollRes = pcall(function()
			return HttpService:GetAsync(HOST .. "/sounds-status")
		end)

		if not PollOk then
			SetStatus("ERROR: LOST CONNECTION")
			Done = true
		else
			local Data = HttpService:JSONDecode(PollRes)
			if Data.status == "complete" then
				Done = true
				PatchInstances(Instances, Data.mapping)
				SetStatus("DONE — " .. (Data.ok or 0) .. " OK, " .. (Data.failed or 0) .. " FAILED")
			elseif Data.status == "error" then
				Done = true
				SetStatus("ERROR: " .. (Data.error or "UNKNOWN"))
			elseif Data.status == "running" then
				SetStatus("PROCESSING " .. (Data.done or 0) .. "/" .. (Data.total or #Ids) .. "...")
			end
		end
	end
end

BtnSoundAll.MouseButton1Click:Connect(function() task.spawn(RunProcess, "all") end)
BtnSoundSel.MouseButton1Click:Connect(function() task.spawn(RunProcess, "selected") end)
