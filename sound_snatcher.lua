local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

local Background = Color3.fromRGB(9, 9, 11)
local CardColor = Color3.fromRGB(14, 14, 17)
local BlackPanel = Color3.fromRGB(5, 5, 7)
local Primary = Color3.fromRGB(196, 255, 0)
local PrimaryFg = Color3.fromRGB(9, 9, 11)
local Foreground = Color3.fromRGB(242, 242, 242)
local MutedFg = Color3.fromRGB(161, 161, 170)
local BorderColor = Color3.fromRGB(34, 34, 38)
local Destructive = Color3.fromRGB(239, 68, 68)

local DisplayFont = Enum.Font.GothamBlack
local BoldFont = Enum.Font.GothamBold
local MediumFont = Enum.Font.GothamMedium
local MonoFont = Enum.Font.Code

local Quick = TweenInfo.new(0.13, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local WindowWidth = 540
local WindowHeight = 404

local SoundIds = {}
local Seen = {}
local Rows = {}

local function ResolveParents()
	local Candidates = {}
	local Ok, Hidden = pcall(function()
		return gethui and gethui()
	end)
	if Ok and Hidden then
		table.insert(Candidates, Hidden)
	end
	pcall(function()
		table.insert(Candidates, game:GetService("CoreGui"))
	end)
	pcall(function()
		local LocalPlayer = Players.LocalPlayer
		if LocalPlayer then
			table.insert(Candidates, LocalPlayer:WaitForChild("PlayerGui", 5))
		end
	end)
	return Candidates
end

local ParentList = ResolveParents()

for _, Parent in ipairs(ParentList) do
	pcall(function()
		local Old = Parent:FindFirstChild("BarbSoundSnatcher")
		if Old then
			Old:Destroy()
		end
	end)
end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "BarbSoundSnatcher"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.IgnoreGuiInset = true
ScreenGui.DisplayOrder = 9999

local Protected = false
pcall(function()
	if syn and syn.protect_gui then
		syn.protect_gui(ScreenGui)
		ScreenGui.Parent = game:GetService("CoreGui")
		Protected = true
	elseif protectgui then
		protectgui(ScreenGui)
		ScreenGui.Parent = game:GetService("CoreGui")
		Protected = true
	end
end)

if not Protected then
	for _, Parent in ipairs(ParentList) do
		local Ok = pcall(function()
			ScreenGui.Parent = Parent
		end)
		if Ok and ScreenGui.Parent == Parent then
			break
		end
	end
end

if not ScreenGui.Parent then
	warn("[SoundSnatcher] failed to parent gui into any container")
	return
end

warn("[SoundSnatcher] gui parented into " .. ScreenGui.Parent:GetFullName())

local function ApplyStroke(Target, Color, Thickness)
	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color
	Stroke.Thickness = Thickness
	Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	Stroke.LineJoinMode = Enum.LineJoinMode.Miter
	Stroke.Parent = Target
	return Stroke
end

local function ApplyPadding(Target, Left, Right, Top, Bottom)
	local Padding = Instance.new("UIPadding")
	Padding.PaddingLeft = UDim.new(0, Left)
	Padding.PaddingRight = UDim.new(0, Right)
	Padding.PaddingTop = UDim.new(0, Top)
	Padding.PaddingBottom = UDim.new(0, Bottom)
	Padding.Parent = Target
	return Padding
end

local Main = Instance.new("Frame")
Main.Name = "Main"
Main.Size = UDim2.new(0, WindowWidth, 0, WindowHeight)
Main.Position = UDim2.new(0.5, -WindowWidth / 2, 0.5, -WindowHeight / 2)
Main.BackgroundColor3 = Background
Main.BorderSizePixel = 0
Main.ClipsDescendants = true
Main.Active = true
Main.Parent = ScreenGui
ApplyStroke(Main, BorderColor, 2)

local GridLayer = Instance.new("Frame")
GridLayer.Name = "GridLayer"
GridLayer.Size = UDim2.new(1, 0, 1, 0)
GridLayer.BackgroundTransparency = 1
GridLayer.ClipsDescendants = true
GridLayer.ZIndex = 0
GridLayer.Parent = Main

for X = 0, WindowWidth, 48 do
	local Line = Instance.new("Frame")
	Line.Size = UDim2.new(0, 1, 1, 0)
	Line.Position = UDim2.new(0, X, 0, 0)
	Line.BackgroundColor3 = Primary
	Line.BackgroundTransparency = 0.96
	Line.BorderSizePixel = 0
	Line.ZIndex = 0
	Line.Parent = GridLayer
end
for Y = 0, WindowHeight, 48 do
	local Line = Instance.new("Frame")
	Line.Size = UDim2.new(1, 0, 0, 1)
	Line.Position = UDim2.new(0, 0, 0, Y)
	Line.BackgroundColor3 = Primary
	Line.BackgroundTransparency = 0.96
	Line.BorderSizePixel = 0
	Line.ZIndex = 0
	Line.Parent = GridLayer
end

local AccentBar = Instance.new("Frame")
AccentBar.Name = "AccentBar"
AccentBar.Size = UDim2.new(1, 0, 0, 2)
AccentBar.BackgroundColor3 = Primary
AccentBar.BorderSizePixel = 0
AccentBar.ZIndex = 6
AccentBar.Parent = Main

local AccentPulse = Instance.new("Frame")
AccentPulse.Size = UDim2.new(0.4, 0, 1, 0)
AccentPulse.BackgroundColor3 = Foreground
AccentPulse.BackgroundTransparency = 0.6
AccentPulse.BorderSizePixel = 0
AccentPulse.ZIndex = 7
AccentPulse.Parent = AccentBar
TweenService:Create(AccentPulse, TweenInfo.new(1.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	BackgroundTransparency = 1,
}):Play()

local TopStrip = Instance.new("Frame")
TopStrip.Name = "TopStrip"
TopStrip.Size = UDim2.new(1, 0, 0, 30)
TopStrip.Position = UDim2.new(0, 0, 0, 2)
TopStrip.BackgroundTransparency = 1
TopStrip.ZIndex = 5
TopStrip.Parent = Main

local function CreateWindowButton(Symbol, OffsetX, HoverColor)
	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(0, 24, 0, 22)
	Button.Position = UDim2.new(1, OffsetX, 0.5, -11)
	Button.BackgroundColor3 = Foreground
	Button.BackgroundTransparency = 1
	Button.AutoButtonColor = false
	Button.Text = Symbol
	Button.TextColor3 = MutedFg
	Button.Font = BoldFont
	Button.TextSize = 13
	Button.ZIndex = 6
	Button.Parent = TopStrip

	Button.MouseEnter:Connect(function()
		TweenService:Create(Button, Quick, { BackgroundTransparency = 0.85, TextColor3 = HoverColor }):Play()
	end)
	Button.MouseLeave:Connect(function()
		TweenService:Create(Button, Quick, { BackgroundTransparency = 1, TextColor3 = MutedFg }):Play()
	end)
	return Button
end

local CloseButton = CreateWindowButton("\u{2715}", -28, Destructive)
local MinimizeButton = CreateWindowButton("\u{2013}", -56, Foreground)

local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, -32, 0, 52)
Header.Position = UDim2.new(0, 16, 0, 34)
Header.BackgroundTransparency = 1
Header.ZIndex = 5
Header.Parent = Main

local HeaderRule = Instance.new("Frame")
HeaderRule.Size = UDim2.new(1, 0, 0, 2)
HeaderRule.Position = UDim2.new(0, 0, 1, 0)
HeaderRule.BackgroundColor3 = BorderColor
HeaderRule.BorderSizePixel = 0
HeaderRule.ZIndex = 5
HeaderRule.Parent = Header

local Kicker = Instance.new("Frame")
Kicker.Size = UDim2.new(0, 200, 0, 12)
Kicker.Position = UDim2.new(0, 0, 0, 4)
Kicker.BackgroundTransparency = 1
Kicker.ZIndex = 5
Kicker.Parent = Header

local KickerMark = Instance.new("Frame")
KickerMark.Size = UDim2.new(0, 8, 0, 8)
KickerMark.Position = UDim2.new(0, 0, 0.5, -4)
KickerMark.BackgroundColor3 = Primary
KickerMark.BorderSizePixel = 0
KickerMark.ZIndex = 5
KickerMark.Parent = Kicker

local KickerLabel = Instance.new("TextLabel")
KickerLabel.Size = UDim2.new(1, -14, 1, 0)
KickerLabel.Position = UDim2.new(0, 14, 0, 0)
KickerLabel.BackgroundTransparency = 1
KickerLabel.Text = "S Y S . R E A D Y"
KickerLabel.TextColor3 = Primary
KickerLabel.TextXAlignment = Enum.TextXAlignment.Left
KickerLabel.Font = MonoFont
KickerLabel.TextSize = 9
KickerLabel.ZIndex = 5
KickerLabel.Parent = Kicker

local Wordmark = Instance.new("TextLabel")
Wordmark.Size = UDim2.new(1, -160, 0, 24)
Wordmark.Position = UDim2.new(0, 0, 0, 18)
Wordmark.BackgroundTransparency = 1
Wordmark.RichText = true
Wordmark.Text = 'B-<font color="rgb(196,255,0)">SNATCHER</font>'
Wordmark.TextColor3 = Foreground
Wordmark.TextXAlignment = Enum.TextXAlignment.Left
Wordmark.Font = DisplayFont
Wordmark.TextSize = 20
Wordmark.ZIndex = 5
Wordmark.Parent = Header

local PlaceTag = Instance.new("TextLabel")
PlaceTag.Size = UDim2.new(0, 160, 0, 16)
PlaceTag.Position = UDim2.new(1, -160, 0, 8)
PlaceTag.BackgroundTransparency = 1
PlaceTag.Text = "PLACE " .. tostring(game.PlaceId)
PlaceTag.TextColor3 = MutedFg
PlaceTag.TextXAlignment = Enum.TextXAlignment.Right
PlaceTag.Font = MonoFont
PlaceTag.TextSize = 11
PlaceTag.ZIndex = 5
PlaceTag.Parent = Header

local JobIdLabel = Instance.new("TextLabel")
JobIdLabel.Size = UDim2.new(0, 160, 0, 14)
JobIdLabel.Position = UDim2.new(1, -160, 0, 26)
JobIdLabel.BackgroundTransparency = 1
JobIdLabel.Text = "live capture"
JobIdLabel.TextColor3 = MutedFg
JobIdLabel.TextXAlignment = Enum.TextXAlignment.Right
JobIdLabel.Font = MonoFont
JobIdLabel.TextSize = 9
JobIdLabel.ZIndex = 5
JobIdLabel.Parent = Header

local Section = Instance.new("Frame")
Section.Name = "Section"
Section.Size = UDim2.new(1, -32, 0, 42)
Section.Position = UDim2.new(0, 16, 0, 96)
Section.BackgroundTransparency = 1
Section.ZIndex = 5
Section.Parent = Main

local SectionBar = Instance.new("Frame")
SectionBar.Size = UDim2.new(0, 4, 1, -8)
SectionBar.Position = UDim2.new(0, 0, 0, 4)
SectionBar.BackgroundColor3 = Primary
SectionBar.BorderSizePixel = 0
SectionBar.ZIndex = 5
SectionBar.Parent = Section

local SectionTitle = Instance.new("TextLabel")
SectionTitle.Size = UDim2.new(1, -200, 0, 22)
SectionTitle.Position = UDim2.new(0, 16, 0, 0)
SectionTitle.BackgroundTransparency = 1
SectionTitle.Text = "SOUND LOG"
SectionTitle.TextColor3 = Foreground
SectionTitle.TextXAlignment = Enum.TextXAlignment.Left
SectionTitle.Font = DisplayFont
SectionTitle.TextSize = 20
SectionTitle.ZIndex = 5
SectionTitle.Parent = Section

local SubRow = Instance.new("Frame")
SubRow.Size = UDim2.new(1, -200, 0, 12)
SubRow.Position = UDim2.new(0, 16, 0, 24)
SubRow.BackgroundTransparency = 1
SubRow.ZIndex = 5
SubRow.Parent = Section

local LiveDot = Instance.new("Frame")
LiveDot.Size = UDim2.new(0, 6, 0, 6)
LiveDot.Position = UDim2.new(0, 0, 0.5, -3)
LiveDot.BackgroundColor3 = Primary
LiveDot.BorderSizePixel = 0
LiveDot.ZIndex = 5
LiveDot.Parent = SubRow
TweenService:Create(LiveDot, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
	BackgroundTransparency = 0.6,
}):Play()

local Subtitle = Instance.new("TextLabel")
Subtitle.Size = UDim2.new(1, -14, 1, 0)
Subtitle.Position = UDim2.new(0, 12, 0, 0)
Subtitle.BackgroundTransparency = 1
Subtitle.Text = "live sounds captured this session"
Subtitle.TextColor3 = MutedFg
Subtitle.TextXAlignment = Enum.TextXAlignment.Left
Subtitle.Font = MonoFont
Subtitle.TextSize = 10
Subtitle.ZIndex = 5
Subtitle.Parent = SubRow

local CountBadge = Instance.new("TextLabel")
CountBadge.Size = UDim2.new(0, 84, 0, 24)
CountBadge.Position = UDim2.new(1, -84, 0, 6)
CountBadge.BackgroundColor3 = Primary
CountBadge.BackgroundTransparency = 0.94
CountBadge.Text = "0 IDS"
CountBadge.TextColor3 = Primary
CountBadge.Font = BoldFont
CountBadge.TextSize = 11
CountBadge.ZIndex = 5
CountBadge.Parent = Section
ApplyStroke(CountBadge, Primary, 2).Transparency = 0.7

local Body = Instance.new("Frame")
Body.Name = "Body"
Body.Size = UDim2.new(1, -32, 1, -156)
Body.Position = UDim2.new(0, 16, 0, 144)
Body.BackgroundTransparency = 1
Body.ZIndex = 5
Body.Parent = Main

local ListCard = Instance.new("Frame")
ListCard.Name = "ListCard"
ListCard.Size = UDim2.new(1, -132, 1, 0)
ListCard.Position = UDim2.new(0, 0, 0, 0)
ListCard.BackgroundColor3 = CardColor
ListCard.BorderSizePixel = 0
ListCard.ClipsDescendants = true
ListCard.ZIndex = 5
ListCard.Parent = Body
ApplyStroke(ListCard, BorderColor, 2)

local ColumnHeader = Instance.new("Frame")
ColumnHeader.Size = UDim2.new(1, 0, 0, 24)
ColumnHeader.BackgroundColor3 = BlackPanel
ColumnHeader.BackgroundTransparency = 0.4
ColumnHeader.BorderSizePixel = 0
ColumnHeader.ZIndex = 5
ColumnHeader.Parent = ListCard

local ColumnRule = Instance.new("Frame")
ColumnRule.Size = UDim2.new(1, 0, 0, 1)
ColumnRule.Position = UDim2.new(0, 0, 1, 0)
ColumnRule.BackgroundColor3 = BorderColor
ColumnRule.BorderSizePixel = 0
ColumnRule.ZIndex = 5
ColumnRule.Parent = ColumnHeader

local ColIndex = Instance.new("TextLabel")
ColIndex.Size = UDim2.new(0, 40, 1, 0)
ColIndex.Position = UDim2.new(0, 10, 0, 0)
ColIndex.BackgroundTransparency = 1
ColIndex.Text = "#"
ColIndex.TextColor3 = MutedFg
ColIndex.TextXAlignment = Enum.TextXAlignment.Left
ColIndex.Font = MonoFont
ColIndex.TextSize = 9
ColIndex.ZIndex = 5
ColIndex.Parent = ColumnHeader

local ColId = Instance.new("TextLabel")
ColId.Size = UDim2.new(1, -60, 1, 0)
ColId.Position = UDim2.new(0, 50, 0, 0)
ColId.BackgroundTransparency = 1
ColId.Text = "SOUND ID"
ColId.TextColor3 = MutedFg
ColId.TextXAlignment = Enum.TextXAlignment.Left
ColId.Font = MonoFont
ColId.TextSize = 9
ColId.ZIndex = 5
ColId.Parent = ColumnHeader

local List = Instance.new("ScrollingFrame")
List.Name = "List"
List.Size = UDim2.new(1, 0, 1, -24)
List.Position = UDim2.new(0, 0, 0, 24)
List.BackgroundTransparency = 1
List.BorderSizePixel = 0
List.ScrollBarThickness = 4
List.ScrollBarImageColor3 = BorderColor
List.CanvasSize = UDim2.new(0, 0, 0, 0)
List.AutomaticCanvasSize = Enum.AutomaticSize.Y
List.ScrollingDirection = Enum.ScrollingDirection.Y
List.ZIndex = 5
List.Parent = ListCard

local ListLayout = Instance.new("UIListLayout")
ListLayout.FillDirection = Enum.FillDirection.Vertical
ListLayout.SortOrder = Enum.SortOrder.LayoutOrder
ListLayout.Parent = List

local EmptyState = Instance.new("TextLabel")
EmptyState.Name = "EmptyState"
EmptyState.Size = UDim2.new(1, 0, 0, 60)
EmptyState.Position = UDim2.new(0, 0, 0, 30)
EmptyState.BackgroundTransparency = 1
EmptyState.Text = "NO SOUNDS CAPTURED YET"
EmptyState.TextColor3 = MutedFg
EmptyState.Font = MonoFont
EmptyState.TextSize = 10
EmptyState.ZIndex = 5
EmptyState.Parent = ListCard

local SidePanel = Instance.new("Frame")
SidePanel.Name = "SidePanel"
SidePanel.Size = UDim2.new(0, 120, 1, 0)
SidePanel.Position = UDim2.new(1, -120, 0, 0)
SidePanel.BackgroundTransparency = 1
SidePanel.ZIndex = 5
SidePanel.Parent = Body

local SideLayout = Instance.new("UIListLayout")
SideLayout.FillDirection = Enum.FillDirection.Vertical
SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
SideLayout.Padding = UDim.new(0, 10)
SideLayout.Parent = SidePanel

local function CreateBrutalButton(LabelText, Order, Variant)
	local Holder = Instance.new("Frame")
	Holder.Name = LabelText
	Holder.Size = UDim2.new(1, -4, 0, 38)
	Holder.BackgroundTransparency = 1
	Holder.LayoutOrder = Order
	Holder.ZIndex = 5
	Holder.Parent = SidePanel

	local Shadow = Instance.new("Frame")
	Shadow.Size = UDim2.new(1, 0, 1, 0)
	Shadow.Position = UDim2.new(0, 4, 0, 4)
	Shadow.BackgroundColor3 = Primary
	Shadow.BorderSizePixel = 0
	Shadow.ZIndex = 5
	Shadow.Parent = Holder

	local Button = Instance.new("TextButton")
	Button.Size = UDim2.new(1, 0, 1, 0)
	Button.Position = UDim2.new(0, 0, 0, 0)
	Button.AutoButtonColor = false
	Button.Text = LabelText
	Button.Font = BoldFont
	Button.TextSize = 11
	Button.ZIndex = 6
	Button.Parent = Holder

	if Variant == "filled" then
		Button.BackgroundColor3 = Primary
		Button.TextColor3 = PrimaryFg
		ApplyStroke(Button, Primary, 2)
	else
		Shadow.Visible = false
		Button.BackgroundColor3 = Background
		Button.BackgroundTransparency = 1
		Button.TextColor3 = MutedFg
		ApplyStroke(Button, BorderColor, 2)
	end

	Button.MouseButton1Down:Connect(function()
		Button.Position = UDim2.new(0, 4, 0, 4)
	end)
	Button.MouseButton1Up:Connect(function()
		Button.Position = UDim2.new(0, 0, 0, 0)
	end)
	Button.MouseEnter:Connect(function()
		if Variant == "filled" then
			Button.Position = UDim2.new(0, -1, 0, -1)
		else
			TweenService:Create(Button, Quick, { TextColor3 = Foreground }):Play()
		end
	end)
	Button.MouseLeave:Connect(function()
		Button.Position = UDim2.new(0, 0, 0, 0)
		if Variant ~= "filled" then
			TweenService:Create(Button, Quick, { TextColor3 = MutedFg }):Play()
		end
	end)

	return Button
end

local CopyButton = CreateBrutalButton("COPY LIST", 1, "filled")
local ClearButton = CreateBrutalButton("CLEAR", 2, "ghost")

local AutoCard = Instance.new("Frame")
AutoCard.Name = "AutoCard"
AutoCard.Size = UDim2.new(1, -4, 0, 52)
AutoCard.LayoutOrder = 3
AutoCard.BackgroundColor3 = BlackPanel
AutoCard.BackgroundTransparency = 0.3
AutoCard.BorderSizePixel = 0
AutoCard.ZIndex = 5
AutoCard.Parent = SidePanel
ApplyStroke(AutoCard, BorderColor, 2)
ApplyPadding(AutoCard, 10, 10, 8, 8)

local AutoLabel = Instance.new("TextLabel")
AutoLabel.Size = UDim2.new(1, 0, 0, 12)
AutoLabel.BackgroundTransparency = 1
AutoLabel.Text = "AUTO-CAPTURE"
AutoLabel.TextColor3 = Primary
AutoLabel.TextXAlignment = Enum.TextXAlignment.Left
AutoLabel.Font = BoldFont
AutoLabel.TextSize = 9
AutoLabel.ZIndex = 5
AutoLabel.Parent = AutoCard

local AutoHint = Instance.new("TextLabel")
AutoHint.Size = UDim2.new(1, 0, 0, 22)
AutoHint.Position = UDim2.new(0, 0, 0, 14)
AutoHint.BackgroundTransparency = 1
AutoHint.Text = "click any id to copy it"
AutoHint.TextColor3 = MutedFg
AutoHint.TextWrapped = true
AutoHint.TextXAlignment = Enum.TextXAlignment.Left
AutoHint.TextYAlignment = Enum.TextYAlignment.Top
AutoHint.Font = MonoFont
AutoHint.TextSize = 9
AutoHint.ZIndex = 5
AutoHint.Parent = AutoCard

local function ToClipboard(Text)
	local Ok = pcall(function()
		(setclipboard or toclipboard or set_clipboard)(Text)
	end)
	return Ok
end

local function UpdateCount()
	CountBadge.Text = #SoundIds .. (#SoundIds == 1 and " ID" or " IDS")
	EmptyState.Visible = #SoundIds == 0
end

local function RemoveId(Target)
	for Index, Value in ipairs(SoundIds) do
		if Value == Target then
			table.remove(SoundIds, Index)
			break
		end
	end
	Seen[Target] = nil
	local Row = Rows[Target]
	if Row then
		Row:Destroy()
		Rows[Target] = nil
	end
	for Index, Value in ipairs(SoundIds) do
		local Existing = Rows[Value]
		if Existing then
			Existing.LayoutOrder = Index
			local IndexLabel = Existing:FindFirstChild("IndexLabel")
			if IndexLabel then
				IndexLabel.Text = string.format("[%02d]", Index)
			end
		end
	end
	UpdateCount()
end

local function AddRow(Id, Numeric)
	local Order = #SoundIds
	local Row = Instance.new("Frame")
	Row.Name = "Row"
	Row.Size = UDim2.new(1, 0, 0, 26)
	Row.BackgroundColor3 = Foreground
	Row.BackgroundTransparency = 1
	Row.BorderSizePixel = 0
	Row.LayoutOrder = Order
	Row.ZIndex = 5
	Row.Parent = List
	Rows[Id] = Row

	local RowRule = Instance.new("Frame")
	RowRule.Size = UDim2.new(1, 0, 0, 1)
	RowRule.Position = UDim2.new(0, 0, 1, -1)
	RowRule.BackgroundColor3 = BorderColor
	RowRule.BackgroundTransparency = 0.4
	RowRule.BorderSizePixel = 0
	RowRule.ZIndex = 5
	RowRule.Parent = Row

	local IndexLabel = Instance.new("TextLabel")
	IndexLabel.Name = "IndexLabel"
	IndexLabel.Size = UDim2.new(0, 40, 1, 0)
	IndexLabel.Position = UDim2.new(0, 10, 0, 0)
	IndexLabel.BackgroundTransparency = 1
	IndexLabel.Text = string.format("[%02d]", Order)
	IndexLabel.TextColor3 = MutedFg
	IndexLabel.TextXAlignment = Enum.TextXAlignment.Left
	IndexLabel.Font = MonoFont
	IndexLabel.TextSize = 10
	IndexLabel.ZIndex = 5
	IndexLabel.Parent = Row

	local IdButton = Instance.new("TextButton")
	IdButton.Name = "IdButton"
	IdButton.Size = UDim2.new(1, -88, 1, 0)
	IdButton.Position = UDim2.new(0, 50, 0, 0)
	IdButton.BackgroundTransparency = 1
	IdButton.AutoButtonColor = false
	IdButton.Text = Numeric
	IdButton.TextColor3 = Foreground
	IdButton.TextXAlignment = Enum.TextXAlignment.Left
	IdButton.TextTruncate = Enum.TextTruncate.AtEnd
	IdButton.Font = BoldFont
	IdButton.TextSize = 11
	IdButton.ZIndex = 5
	IdButton.Parent = Row

	local StatusLabel = Instance.new("TextLabel")
	StatusLabel.Name = "StatusLabel"
	StatusLabel.Size = UDim2.new(0, 30, 1, 0)
	StatusLabel.Position = UDim2.new(1, -64, 0, 0)
	StatusLabel.BackgroundTransparency = 1
	StatusLabel.Text = "OK"
	StatusLabel.TextColor3 = Primary
	StatusLabel.TextXAlignment = Enum.TextXAlignment.Right
	StatusLabel.Font = MonoFont
	StatusLabel.TextSize = 9
	StatusLabel.ZIndex = 5
	StatusLabel.Parent = Row

	local RemoveButton = Instance.new("TextButton")
	RemoveButton.Name = "RemoveButton"
	RemoveButton.Size = UDim2.new(0, 22, 0, 20)
	RemoveButton.Position = UDim2.new(1, -26, 0.5, -10)
	RemoveButton.BackgroundTransparency = 1
	RemoveButton.AutoButtonColor = false
	RemoveButton.Text = "\u{2715}"
	RemoveButton.TextColor3 = MutedFg
	RemoveButton.Font = BoldFont
	RemoveButton.TextSize = 11
	RemoveButton.ZIndex = 5
	RemoveButton.Parent = Row

	IdButton.MouseEnter:Connect(function()
		TweenService:Create(Row, Quick, { BackgroundTransparency = 0.95 }):Play()
	end)
	IdButton.MouseLeave:Connect(function()
		TweenService:Create(Row, Quick, { BackgroundTransparency = 1 }):Play()
	end)
	IdButton.MouseButton1Click:Connect(function()
		ToClipboard(Id)
		StatusLabel.Text = "COPIED"
		task.delay(0.7, function()
			if StatusLabel.Parent then
				StatusLabel.Text = "OK"
			end
		end)
	end)

	RemoveButton.MouseEnter:Connect(function()
		TweenService:Create(RemoveButton, Quick, { TextColor3 = Destructive }):Play()
	end)
	RemoveButton.MouseLeave:Connect(function()
		TweenService:Create(RemoveButton, Quick, { TextColor3 = MutedFg }):Play()
	end)
	RemoveButton.MouseButton1Click:Connect(function()
		RemoveId(Id)
	end)
end

local function NormalizeId(Raw)
	if not Raw or Raw == "" then
		return nil
	end
	local Number = string.match(Raw, "%d+")
	if not Number then
		return nil
	end
	return "rbxassetid://" .. Number, Number
end

local function LogSound(SoundInstance)
	local Id, Numeric = NormalizeId(SoundInstance.SoundId)
	if not Id or Seen[Id] then
		return
	end
	Seen[Id] = true
	table.insert(SoundIds, Id)
	AddRow(Id, Numeric)
	UpdateCount()
end

local function HookSound(SoundInstance)
	if SoundInstance:GetAttribute("BarbHooked") then
		return
	end
	SoundInstance:SetAttribute("BarbHooked", true)

	SoundInstance.Played:Connect(function()
		LogSound(SoundInstance)
	end)
	if SoundInstance.IsPlaying then
		LogSound(SoundInstance)
	end
end

CopyButton.MouseButton1Click:Connect(function()
	if #SoundIds == 0 then
		return
	end
	local Lines = {}
	for _, Value in ipairs(SoundIds) do
		table.insert(Lines, (string.match(Value, "%d+")))
	end
	ToClipboard(table.concat(Lines, "\n"))
	CopyButton.Text = "COPIED " .. #SoundIds
	task.delay(0.8, function()
		CopyButton.Text = "COPY LIST"
	end)
end)

ClearButton.MouseButton1Click:Connect(function()
	for _, Row in pairs(Rows) do
		Row:Destroy()
	end
	table.clear(Rows)
	table.clear(Seen)
	table.clear(SoundIds)
	UpdateCount()
end)

CloseButton.MouseButton1Click:Connect(function()
	ScreenGui:Destroy()
end)

local Minimized = false
MinimizeButton.MouseButton1Click:Connect(function()
	Minimized = not Minimized
	if Minimized then
		TweenService:Create(Main, Quick, { Size = UDim2.new(0, WindowWidth, 0, 32) }):Play()
	else
		TweenService:Create(Main, Quick, { Size = UDim2.new(0, WindowWidth, 0, WindowHeight) }):Play()
	end
end)

local Dragging = false
local DragStart = nil
local StartPosition = nil

local function BeginDrag(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
		Dragging = true
		DragStart = Input.Position
		StartPosition = Main.Position
	end
end

TopStrip.InputBegan:Connect(BeginDrag)
Header.InputBegan:Connect(BeginDrag)

UserInputService.InputChanged:Connect(function(Input)
	if Dragging and (Input.UserInputType == Enum.UserInputType.MouseMovement or Input.UserInputType == Enum.UserInputType.Touch) then
		local Delta = Input.Position - DragStart
		Main.Position = UDim2.new(
			StartPosition.X.Scale,
			StartPosition.X.Offset + Delta.X,
			StartPosition.Y.Scale,
			StartPosition.Y.Offset + Delta.Y
		)
	end
end)

UserInputService.InputEnded:Connect(function(Input)
	if Input.UserInputType == Enum.UserInputType.MouseButton1 or Input.UserInputType == Enum.UserInputType.Touch then
		Dragging = false
	end
end)

for _, Descendant in ipairs(game:GetDescendants()) do
	if Descendant:IsA("Sound") then
		HookSound(Descendant)
	end
end

game.DescendantAdded:Connect(function(Descendant)
	if Descendant:IsA("Sound") then
		HookSound(Descendant)
	end
end)

UpdateCount()
