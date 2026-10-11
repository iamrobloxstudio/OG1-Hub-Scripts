--!strict
-- ================================================================
-- ⚡ CIPHER // LOOP TOOLS V4.0 (STANDALONE SSS EDITION)
-- Continuous Tool Target Snapper & Torso Touch Burst Engine
-- High MS Ping Double-Tap Replication | Draggable Cyber SSS UI
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

-- ================================================================
-- 1. SSS RED CYBER HACKER THEME & CONFIG
-- ================================================================
local THEME = {
	VoidBg      = Color3.fromRGB(10, 10, 14),
	CardBg      = Color3.fromRGB(16, 16, 22),
	AccentRed   = Color3.fromRGB(255, 35, 60),
	AccentHover = Color3.fromRGB(255, 70, 95),
	AccentDim   = Color3.fromRGB(80, 20, 30),
	ActiveGreen = Color3.fromRGB(45, 225, 115),
	BorderRed   = Color3.fromRGB(255, 45, 70),
	TextPrimary = Color3.fromRGB(245, 245, 255),
	TextMuted   = Color3.fromRGB(140, 145, 165),
}

local TOGGLE_KEY = Enum.KeyCode.L
local FollowOffset = Vector3.new(0, 0.6, 0)
local AvoidCollisionOffset = Vector3.new(0, 0, 0.5)

-- Executor API Resolver
local fireTouch: ((BasePart, BasePart, number) -> ())? = firetouchinterest 
	or (getgenv and (getgenv().firetouchinterest or getgenv().fire_touch_interest))
	or (syn and syn.firetouchinterest)

if not fireTouch then
	warn("[Loop Tools] firetouchinterest executor closure not found. Touch damage disabled.")
end

-- State
local bringTargets: { [string]: boolean } = {}
local cachedToolParts: { BasePart } = {}
local cachedTorso: { [Model]: BasePart } = {}
local following = false

-- ================================================================
-- 2. GUI RESOLVER
-- ================================================================
local function getGuiContainer(): Instance
	local success, core = pcall(function() return CoreGui end)
	if success and core then
		local canWrite = pcall(function()
			local test = Instance.new("Folder")
			test.Parent = core
			test:Destroy()
		end)
		if canWrite then return core end
	end
	return LocalPlayer:WaitForChild("PlayerGui")
end

local guiContainer = getGuiContainer()
local existing = guiContainer:FindFirstChild("CipherLoopToolsUI")
if existing then existing:Destroy() end

-- ================================================================
-- 3. SSS RED CYBER HACKER DRAGGABLE GUI
-- ================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CipherLoopToolsUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiContainer

local MainCard = Instance.new("Frame")
MainCard.Name = "MainCard"
MainCard.Size = UDim2.fromOffset(240, 42)
MainCard.Position = UDim2.new(1, -250, 0.35, 0)
MainCard.BackgroundColor3 = THEME.VoidBg
MainCard.BackgroundTransparency = 0.08
MainCard.BorderSizePixel = 0
MainCard.Active = true
MainCard.ClipsDescendants = false
MainCard.Parent = ScreenGui

local CardCorner = Instance.new("UICorner")
CardCorner.CornerRadius = UDim.new(0, 10)
CardCorner.Parent = MainCard

local CardStroke = Instance.new("UIStroke")
CardStroke.Thickness = 1.5
CardStroke.Color = THEME.BorderRed
CardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
CardStroke.Parent = MainCard

-- Header Bar (Drag Handle)
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, -8, 0, 34)
Header.Position = UDim2.new(0, 4, 0, 4)
Header.BackgroundTransparency = 1
Header.Parent = MainCard

local HeaderLayout = Instance.new("UIListLayout")
HeaderLayout.FillDirection = Enum.FillDirection.Horizontal
HeaderLayout.SortOrder = Enum.SortOrder.LayoutOrder
HeaderLayout.VerticalAlignment = Enum.VerticalAlignment.Center
HeaderLayout.Padding = UDim.new(0, 4)
HeaderLayout.Parent = Header

local function createHeaderButton(text: string, width: number, order: number): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, width, 0, 28)
	btn.BackgroundColor3 = THEME.CardBg
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = THEME.TextPrimary
	btn.Text = text
	btn.AutoButtonColor = false
	btn.LayoutOrder = order
	btn.Parent = Header

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, 6)
	c.Parent = btn

	local s = Instance.new("UIStroke")
	s.Thickness = 1
	s.Color = THEME.BorderRed
	s.Transparency = 0.4
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = btn

	btn.MouseEnter:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = THEME.AccentDim}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.1), {BackgroundColor3 = THEME.CardBg}):Play()
	end)

	return btn
end

local ToggleButton = createHeaderButton("⚡ LOOP TOOLS [L]", 136, 1)
local SelectAllBtn  = createHeaderButton("ALL", 44, 2)
local ClearAllBtn   = createHeaderButton("CLR", 44, 3)

ToggleButton.TextColor3 = THEME.AccentRed

-- Dropdown Panel for Players
local DropPanel = Instance.new("Frame")
DropPanel.Name = "DropPanel"
DropPanel.Size = UDim2.new(1, 0, 0, 0)
DropPanel.Position = UDim2.new(0, 0, 0, 46)
DropPanel.BackgroundColor3 = THEME.VoidBg
DropPanel.BackgroundTransparency = 0.08
DropPanel.BorderSizePixel = 0
DropPanel.ClipsDescendants = true
DropPanel.Visible = false
DropPanel.Parent = MainCard

local DropCorner = Instance.new("UICorner")
DropCorner.CornerRadius = UDim.new(0, 10)
DropCorner.Parent = DropPanel

local DropStroke = Instance.new("UIStroke")
DropStroke.Thickness = 1.5
DropStroke.Color = THEME.BorderRed
DropStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
DropStroke.Parent = DropPanel

local ScrollList = Instance.new("ScrollingFrame")
ScrollList.Size = UDim2.new(1, -16, 1, -12)
ScrollList.Position = UDim2.new(0, 8, 0, 6)
ScrollList.BackgroundTransparency = 1
ScrollList.ScrollBarThickness = 4
ScrollList.ScrollBarImageColor3 = THEME.AccentRed
ScrollList.CanvasSize = UDim2.new(0, 0, 0, 0)
ScrollList.Parent = DropPanel

local ListLayout = Instance.new("UIListLayout")
ListLayout.Padding = UDim.new(0, 4)
ListLayout.SortOrder = Enum.SortOrder.Name
ListLayout.Parent = ScrollList

ListLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	ScrollList.CanvasSize = UDim2.new(0, 0, 0, ListLayout.AbsoluteContentSize.Y + 6)
end)

-- Draggable implementation
local function setupDraggable(frame: Frame, dragHandle: Frame)
	local dragging = false
	local dragInput: InputObject? = nil
	local dragStart: Vector3 = Vector3.zero
	local startPos: UDim2 = UDim2.new()

	dragHandle.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			dragStart = input.Position
			startPos = frame.Position
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)

	dragHandle.InputChanged:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)

	UserInputService.InputChanged:Connect(function(input: InputObject)
		if input == dragInput and dragging then
			local delta = input.Position - dragStart
			frame.Position = UDim2.new(
				startPos.X.Scale,
				startPos.X.Offset + delta.X,
				startPos.Y.Scale,
				startPos.Y.Offset + delta.Y
			)
		end
	end)
end

setupDraggable(MainCard, MainCard)

-- Dropdown Toggle
local isPanelOpen = false
local function togglePanel()
	isPanelOpen = not isPanelOpen
	local targetSize = isPanelOpen and UDim2.new(1, 0, 0, 220) or UDim2.new(1, 0, 0, 0)

	if isPanelOpen then
		DropPanel.Visible = true
	end

	local tween = TweenService:Create(DropPanel, TweenInfo.new(0.2, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {Size = targetSize})
	tween:Play()

	if not isPanelOpen then
		tween.Completed:Connect(function()
			if not isPanelOpen then
				DropPanel.Visible = false
			end
		end)
	end
end

ToggleButton.MouseButton1Click:Connect(togglePanel)

UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
	if gpe then return end
	if input.KeyCode == TOGGLE_KEY then
		togglePanel()
	end
end)

-- ================================================================
-- 4. TOOL CACHE & PHYSICS SYNERGY (ANTI-SNAG 1V1 ESCAPE)
-- ================================================================
local function getToolPart(tool: Tool): BasePart?
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle
	end
	if tool.PrimaryPart and tool.PrimaryPart:IsA("BasePart") then
		return tool.PrimaryPart
	end
	for _, v in ipairs(tool:GetDescendants()) do
		if v:IsA("BasePart") then
			return v
		end
	end
	return nil
end

local function updateToolCache()
	table.clear(cachedToolParts)
	if not LocalPlayer.Character then return end

	for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
		if tool:IsA("Tool") then
			local part = getToolPart(tool)
			if part then
				part.CanCollide = false
				part.Massless = true
				part.CanTouch = true
				table.insert(cachedToolParts, part)
			end
		end
	end
end

local function getCachedTorso(char: Model): BasePart?
	if cachedTorso[char] and cachedTorso[char].Parent then
		return cachedTorso[char]
	end
	local torso = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	if torso and torso:IsA("BasePart") then
		cachedTorso[char] = torso
		return torso
	end
	return nil
end

-- ================================================================
-- 5. TOOL FOLLOW ENGINE (HIGH MS PING DOUBLE-TAP REPLICATION)
-- ================================================================
local function moveToolsToTarget(targetChar: Model)
	local torso = getCachedTorso(targetChar)
	if not (torso and torso:IsA("BasePart")) then return end

	local targetPos = torso.Position + FollowOffset + AvoidCollisionOffset

	for _, part in ipairs(cachedToolParts) do
		if part and part.Parent then
			part.Position = targetPos

			if fireTouch then
				pcall(fireTouch, part, torso, 0)
				pcall(fireTouch, part, torso, 1)
			end
		end
	end
end

local function startFollowing()
	if following then return end
	following = true

	RunService.Heartbeat:Connect(function()
		if not next(bringTargets) then return end
		if not LocalPlayer.Character then return end

		for name, isTargeted in pairs(bringTargets) do
			if isTargeted then
				local plr = Players:FindFirstChild(name)
				if plr and plr:IsA("Player") and plr.Character then
					moveToolsToTarget(plr.Character)
				end
			end
		end
	end)
end

-- Respawn & Tool Change Hook
local function hookCharacter(char: Model)
	char:WaitForChild("HumanoidRootPart", 5)
	updateToolCache()

	char.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") then
			task.defer(function()
				updateToolCache()
			end)
		end
	end)

	char.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") then
			task.defer(updateToolCache)
		end
	end)
end

if LocalPlayer.Character then
	hookCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(hookCharacter)

-- ================================================================
-- 6. PLAYER LIST CONTROLS
-- ================================================================
local function updatePlayerList()
	for _, child in ipairs(ScrollList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local isSelected = bringTargets[p.Name] == true

			local btn = Instance.new("TextButton")
			btn.Name = p.Name
			btn.Size = UDim2.new(1, -6, 0, 26)
			btn.BackgroundColor3 = isSelected and THEME.AccentDim or THEME.CardBg
			btn.TextColor3 = isSelected and THEME.AccentRed or THEME.TextPrimary
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 11
			btn.AutoButtonColor = false
			btn.Text = (isSelected and "⚡ " or "") .. p.Name .. (isSelected and " [FOLLOWING]" or "")
			btn.Parent = ScrollList

			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = btn

			local s = Instance.new("UIStroke")
			s.Thickness = 1
			s.Color = THEME.BorderRed
			s.Transparency = isSelected and 0.2 or 0.6
			s.Parent = btn

			btn.MouseButton1Click:Connect(function()
				if bringTargets[p.Name] then
					bringTargets[p.Name] = nil
				else
					bringTargets[p.Name] = true
					startFollowing()
				end
				updatePlayerList()
			end)
		end
	end
end

SelectAllBtn.MouseButton1Click:Connect(function()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			bringTargets[p.Name] = true
		end
	end
	startFollowing()
	updatePlayerList()
end)

ClearAllBtn.MouseButton1Click:Connect(function()
	table.clear(bringTargets)
	updatePlayerList()
end)

Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(function(p: Player)
	bringTargets[p.Name] = nil
	updatePlayerList()
end)

updatePlayerList()
startFollowing()

print("[Loop Tools] CIPHER // LOOP TOOLS V4.0 Loaded successfully.")
