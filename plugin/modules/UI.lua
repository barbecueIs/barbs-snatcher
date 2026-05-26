local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local ACCENT_COLOR = Color3.fromHex("ccff00")
local BORDER_COLOR = Color3.fromHex("1e1e28")
local TEXT_COLOR = Color3.fromHex("f5f5f5")
local MUTED_COLOR = Color3.fromHex("71717a")
local ROW_BG = Color3.fromHex("0e0e11")

local SPRING = TweenInfo.new(0.5, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
local QUICK = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local UI = {}
UI.StatusLabel = nil
UI.FooterStatus = nil
UI.RowScripts = nil
UI.RowIntValues = nil
UI.RowAllValues = nil
UI.PlaceIds = {}
UI.PlaceList = nil
UI.PluginRef = nil

function UI.SavePlaceIds()
	if UI.PluginRef then
		UI.PluginRef:SetSetting("BSnatcher_PlaceIds", UI.PlaceIds)
	end
end

function UI.RebuildPlaceList()
	if not UI.PlaceList then return end
	for _, Child in ipairs(UI.PlaceList:GetChildren()) do
		if Child:IsA("Frame") then Child:Destroy() end
	end
	for _, Id in ipairs(UI.PlaceIds) do
		local Row = Instance.new("Frame")
		Row.Name = "PlaceEntry"
		Row.Size = UDim2.new(1, 0, 0, 28)
		Row.BackgroundColor3 = ROW_BG
		Row.BackgroundTransparency = 0
		Row.BorderSizePixel = 1
		Row.Parent = UI.PlaceList

		local IdLabel = Instance.new("TextLabel")
		IdLabel.Name = "IdLabel"
		IdLabel.Size = UDim2.new(1, -38, 1, 0)
		IdLabel.Position = UDim2.new(0, 8, 0, 0)
		IdLabel.BackgroundTransparency = 1
		IdLabel.BorderSizePixel = 1
		IdLabel.Text = Id
		IdLabel.TextColor3 = TEXT_COLOR
		IdLabel.TextXAlignment = Enum.TextXAlignment.Left
		IdLabel.Font = Enum.Font.GothamBold
		IdLabel.TextSize = 10
		IdLabel.Parent = Row

		local RemoveBtn = Instance.new("TextButton")
		RemoveBtn.Name = "RemoveBtn"
		RemoveBtn.Size = UDim2.new(0, 20, 0, 20)
		RemoveBtn.Position = UDim2.new(1, -28, 0.5, -10)
		RemoveBtn.BackgroundColor3 = BORDER_COLOR
		RemoveBtn.BackgroundTransparency = 0
		RemoveBtn.BorderSizePixel = 1
		RemoveBtn.Text = "x"
		RemoveBtn.TextColor3 = MUTED_COLOR
		RemoveBtn.Font = Enum.Font.GothamBold
		RemoveBtn.TextSize = 10
		RemoveBtn.Parent = Row

		local CapturedId = Id
		RemoveBtn.MouseButton1Click:Connect(function()
			for I, Existing in ipairs(UI.PlaceIds) do
				if Existing == CapturedId then
					table.remove(UI.PlaceIds, I)
					break
				end
			end
			UI.SavePlaceIds()
			UI.RebuildPlaceList()
		end)
	end
	UI.PlaceList.CanvasSize = UDim2.new(0, 0, 0, #UI.PlaceIds * 32)
end

function UI.Init(PluginRef, PluginScript)
	UI.PluginRef = PluginRef
	local Loaded = PluginRef:GetSetting("BSnatcher_PlaceIds")
	if type(Loaded) == "table" then
		UI.PlaceIds = Loaded
	end

	local CoreGui = game:GetService("CoreGui")
	local Stale = CoreGui:FindFirstChild("BSpoofGui")
	if Stale then Stale:Destroy() end
	local ScreenGui = PluginScript:WaitForChild("BSpoofGui")
	ScreenGui.Parent = CoreGui
	local MainFrame = ScreenGui:WaitForChild("MainFrame")
	local Sidebar = MainFrame:WaitForChild("Sidebar")
	local Header = Sidebar:WaitForChild("Header")
	local Nav = Sidebar:WaitForChild("Nav")
	local Footer = Sidebar:WaitForChild("Footer")
	UI.FooterStatus = Footer:WaitForChild("StatusText")
	local MainContent = MainFrame:WaitForChild("MainContent")
	local CloseBtn = MainFrame:WaitForChild("CloseBtn")

	local PulseActive = Header:WaitForChild("PulseLine"):WaitForChild("PulseActive")
	RunService.RenderStepped:Connect(function()
		PulseActive.Position = UDim2.new(0.5 + 0.5 * math.sin(tick() * 2), 0, 0, 0)
	end)

	UI.SetupDrag(MainFrame)

	MainFrame.MouseEnter:Connect(function()
		PluginRef:Activate(true)
	end)
	MainFrame.MouseLeave:Connect(function()
		if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
			PluginRef:Deactivate()
		end
	end)
	UserInputService.InputEnded:Connect(function(Input)
		if Input.UserInputType ~= Enum.UserInputType.MouseButton1 then return end
		local Pos = UserInputService:GetMouseLocation()
		local Abs = MainFrame.AbsolutePosition
		local Sz = MainFrame.AbsoluteSize
		if Pos.X < Abs.X or Pos.X > Abs.X + Sz.X or Pos.Y < Abs.Y or Pos.Y > Abs.Y + Sz.Y then
			PluginRef:Deactivate()
		end
	end)

	local BMain = Nav:WaitForChild("MAINBtn")
	local BConfig = Nav:WaitForChild("CONFIGBtn")
	UI.SetupNav(BMain)
	UI.SetupNav(BConfig)

	local VMain = MainContent:WaitForChild("MainView")
	local VConfig = MainContent:WaitForChild("ConfigView")

	local SoundsSection = VMain:WaitForChild("Inner"):WaitForChild("SoundsSection")
	local BtnSoundAll = UI.SetupCyberBtn(SoundsSection:WaitForChild("AllCont"))
	local BtnSoundSel = UI.SetupCyberBtn(SoundsSection:WaitForChild("SelectedCont"))
	UI.StatusLabel = SoundsSection:WaitForChild("StatusLabel")

	local ConfigInner = VConfig:WaitForChild("Inner")
	local Toggles = ConfigInner:WaitForChild("Toggles")
	UI.RowScripts = Toggles:WaitForChild("LookInScripts")
	UI.RowIntValues = Toggles:WaitForChild("LookInIntValues")
	UI.RowAllValues = Toggles:WaitForChild("LookInAllValues")
	UI.SetupToggle(UI.RowScripts)
	UI.SetupToggle(UI.RowIntValues)
	UI.SetupToggle(UI.RowAllValues)

	local PlaceSection = ConfigInner:WaitForChild("PlaceSection")
	local InputRow = PlaceSection:WaitForChild("InputRow")
	local PlaceInput = InputRow:WaitForChild("PlaceInput")
	local AddBtn = UI.SetupCyberBtn(InputRow:WaitForChild("AddCont"))
	UI.PlaceList = PlaceSection:WaitForChild("PlaceList")
	UI.RebuildPlaceList()

	local function TryAddId()
		local Val = PlaceInput.Text:match("^%s*(%d+)%s*$")
		if not Val or Val == "" then return end
		for _, Existing in ipairs(UI.PlaceIds) do
			if Existing == Val then
				PlaceInput.Text = ""
				return
			end
		end
		table.insert(UI.PlaceIds, Val)
		UI.SavePlaceIds()
		UI.RebuildPlaceList()
		PlaceInput.Text = ""
	end

	AddBtn.MouseButton1Click:Connect(TryAddId)
	PlaceInput.FocusLost:Connect(function(Pressed)
		if Pressed then TryAddId() end
	end)

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

	local Toolbar = PluginRef:CreateToolbar("B-SNATCHER")
	local ToolbarButton = Toolbar:CreateButton("Open B-SNATCHER", "Open the B-SNATCHER Plugin UI", "rbxassetid://107814281854748")
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

	return BtnSoundAll, BtnSoundSel
end

function UI.SetupDrag(MainFrame)
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
end

function UI.SetupNav(Btn)
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

function UI.SetupCyberBtn(Cont)
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

function UI.RefreshToggle(Row)
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

function UI.SetupToggle(Row)
	Row:WaitForChild("ToggleBtn").MouseButton1Click:Connect(function()
		Row:SetAttribute("Value", not Row:GetAttribute("Value"))
		UI.RefreshToggle(Row)
	end)
	UI.RefreshToggle(Row)
end

function UI.SetStatus(Msg)
	if UI.StatusLabel then UI.StatusLabel.Text = Msg end
	if UI.FooterStatus then UI.FooterStatus.Text = Msg end
end

function UI.GetConfig()
	return {
		LookInScripts = UI.RowScripts and UI.RowScripts:GetAttribute("Value") or false,
		LookInIntValues = UI.RowIntValues and UI.RowIntValues:GetAttribute("Value") or false,
		LookInAllValues = UI.RowAllValues and UI.RowAllValues:GetAttribute("Value") or false,
		PlaceIds = UI.PlaceIds,
	}
end

return UI
