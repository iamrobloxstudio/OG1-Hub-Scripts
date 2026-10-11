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

local TOGGLE_KEY = Enum.KeyCode.B

-- Loopbring Target State
local LoopBrings: { [number]: boolean } = {}
local targetDistance: number = 3
local targetOffset: number   = 0

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
local existing = guiContainer:FindFirstChild("CipherLoopBringGUI")
if existing then existing:Destroy() end

-- ================================================================
-- 3. SSS RED CYBER HACKER DRAGGABLE GUI
-- ================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CipherLoopBringGUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiContainer

-- Draggable Main Container
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.fromOffset(260, 42)
MainFrame.Position = UDim2.new(0, 24, 0.25, 0)
MainFrame.BackgroundColor3 = THEME.VoidBg
MainFrame.BackgroundTransparency = 0.08
MainFrame.BorderSizePixel = 0
MainFrame.Active = true
MainFrame.ClipsDescendants = false
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.5
MainStroke.Color = THEME.BorderRed
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Parent = MainFrame

-- Control Bar (Always Visible / Acts as Drag Bar)
local ControlBar = Instance.new("Frame")
ControlBar.Name = "ControlBar"
ControlBar.Size = UDim2.new(1, -8, 0, 34)
ControlBar.Position = UDim2.new(0, 4, 0, 4)
ControlBar.BackgroundTransparency = 1
ControlBar.Parent = MainFrame

local BarLayout = Instance.new("UIListLayout")
BarLayout.FillDirection = Enum.FillDirection.Horizontal
BarLayout.SortOrder = Enum.SortOrder.LayoutOrder
BarLayout.VerticalAlignment = Enum.VerticalAlignment.Center
BarLayout.Padding = UDim.new(0, 4)
BarLayout.Parent = ControlBar

-- Helper: Create Cyber Micro-Buttons
local function createBarButton(text: string, width: number, order: number): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, width, 0, 28)
	btn.BackgroundColor3 = THEME.CardBg
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = THEME.TextPrimary
	btn.Text = text
	btn.AutoButtonColor = false
	btn.LayoutOrder = order
	btn.Parent = ControlBar

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

local ToggleButton = createBarButton("⚡ LOOPBRING [B]", 110, 1)
local LeftButton   = createBarButton("<", 26, 2)
local RightButton  = createBarButton(">", 26, 3)
local MinusButton  = createBarButton("-", 26, 4)
local PlusButton   = createBarButton("+", 26, 5)
local AllButton    = createBarButton("ALL", 36, 6)

ToggleButton.TextColor3 = THEME.AccentRed

-- Expanded Player List Panel
local DropPanel = Instance.new("Frame")
DropPanel.Name = "DropPanel"
DropPanel.Size = UDim2.new(1, 0, 0, 0)
DropPanel.Position = UDim2.new(0, 0, 0, 46)
DropPanel.BackgroundColor3 = THEME.VoidBg
DropPanel.BackgroundTransparency = 0.08
DropPanel.BorderSizePixel = 0
DropPanel.ClipsDescendants = true
DropPanel.Visible = false
DropPanel.Parent = MainFrame

local DropCorner = Instance.new("UICorner")
DropCorner.CornerRadius = UDim.new(0, 10)
DropCorner.Parent = DropPanel

local DropStroke = Instance.new("UIStroke")
DropStroke.Thickness = 1.5
DropStroke.Color = THEME.BorderRed
DropStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
DropStroke.Parent = DropPanel

-- Status & Offset Label inside DropPanel
local InfoBar = Instance.new("TextLabel")
InfoBar.Size = UDim2.new(1, -16, 0, 20)
InfoBar.Position = UDim2.new(0, 8, 0, 6)
InfoBar.BackgroundTransparency = 1
InfoBar.Font = Enum.Font.Code
InfoBar.TextSize = 10
InfoBar.TextColor3 = THEME.TextMuted
InfoBar.TextXAlignment = Enum.TextXAlignment.Left
InfoBar.Text = "OFFSET: 0 | DIST: 3 STUDS"
InfoBar.Parent = DropPanel

local function updateInfoBar()
	InfoBar.Text = string.format("OFFSET: %+d | DIST: %d STUDS", targetOffset, targetDistance)
end

local ScrollList = Instance.new("ScrollingFrame")
ScrollList.Size = UDim2.new(1, -16, 1, -34)
ScrollList.Position = UDim2.new(0, 8, 0, 28)
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

-- Draggable implementation for MainFrame
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

setupDraggable(MainFrame, MainFrame)

-- Dropdown Toggle
local isPanelOpen = false
local function togglePanel()
	isPanelOpen = not isPanelOpen
	local targetSize = isPanelOpen and UDim2.new(1, 0, 0, 230) or UDim2.new(1, 0, 0, 0)

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

-- Distance / Offset controls
LeftButton.MouseButton1Click:Connect(function()
	targetOffset = math.clamp(targetOffset - 1, -30, 30)
	updateInfoBar()
end)

RightButton.MouseButton1Click:Connect(function()
	targetOffset = math.clamp(targetOffset + 1, -30, 30)
	updateInfoBar()
end)

MinusButton.MouseButton1Click:Connect(function()
	targetDistance = math.clamp(targetDistance - 1, 1, 50)
	updateInfoBar()
end)

PlusButton.MouseButton1Click:Connect(function()
	targetDistance = math.clamp(targetDistance + 1, 1, 50)
	updateInfoBar()
end)

-- Keybind [B]
UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
	if gpe then return end
	if input.KeyCode == TOGGLE_KEY then
		togglePanel()
	end
end)

-- ================================================================
-- 4. AGGRESSIVE LOOPBRING ENGINE (ANTI-RUBBERBANDING)
-- ================================================================
local function executeBringCycle()
	local myChar = LocalPlayer.Character
	if not myChar then return end
	local myHRP = myChar:FindFirstChild("HumanoidRootPart")
	if not (myHRP and myHRP:IsA("BasePart")) then return end

	local targetCFrame = myHRP.CFrame * CFrame.new(targetOffset, 0, -targetDistance)

	for userId, isActive in pairs(LoopBrings) do
		if isActive then
			local targetPlayer = Players:GetPlayerByUserId(userId)
			if targetPlayer and targetPlayer.Character then
				local targetHRP = targetPlayer.Character:FindFirstChild("HumanoidRootPart")
				local targetHum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")

				if targetHRP and targetHRP:IsA("BasePart") then
					-- Instant CFrame teleport
					targetHRP.CFrame = targetCFrame

					-- Zero out target velocities to crush momentum / interpolation
					targetHRP.AssemblyLinearVelocity = Vector3.zero
					targetHRP.AssemblyAngularVelocity = Vector3.zero

					-- Lock target humanoid mobility
					if targetHum then
						targetHum.WalkSpeed = 0
						targetHum.JumpPower = 0
					end
				end
			end
		end
	end
end

-- Fire on Stepped, PreRender, and Heartbeat to overpower server rubberband replication
RunService.Stepped:Connect(executeBringCycle)
RunService.PreRender:Connect(executeBringCycle)
RunService.Heartbeat:Connect(executeBringCycle)

-- ================================================================
-- 5. PLAYER LIST GENERATION & CONTROLS
-- ================================================================
local function loopBringToggle(targetPlayer: Player, button: TextButton)
	local uid = targetPlayer.UserId
	if LoopBrings[uid] then
		LoopBrings[uid] = nil
		button.Text = targetPlayer.Name
		button.BackgroundColor3 = THEME.CardBg
		button.TextColor3 = THEME.TextPrimary

		if targetPlayer.Character then
			local hum = targetPlayer.Character:FindFirstChildOfClass("Humanoid")
			if hum then
				hum.WalkSpeed = 16
				hum.JumpPower = 50
			end
		end
	else
		LoopBrings[uid] = true
		button.Text = "★ " .. targetPlayer.Name .. " [LOCKED]"
		button.BackgroundColor3 = THEME.AccentDim
		button.TextColor3 = THEME.AccentRed
	end
end

local function updatePlayerList()
	for _, child in ipairs(ScrollList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local isLocked = LoopBrings[player.UserId] == true

			local btn = Instance.new("TextButton")
			btn.Name = player.Name
			btn.Size = UDim2.new(1, -6, 0, 26)
			btn.BackgroundColor3 = isLocked and THEME.AccentDim or THEME.CardBg
			btn.TextColor3 = isLocked and THEME.AccentRed or THEME.TextPrimary
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 11
			btn.AutoButtonColor = false
			btn.Text = (isLocked and "★ " or "") .. player.Name .. (isLocked and " [LOCKED]" or "")
			btn.Parent = ScrollList

			local c = Instance.new("UICorner")
			c.CornerRadius = UDim.new(0, 6)
			c.Parent = btn

			local s = Instance.new("UIStroke")
			s.Thickness = 1
			s.Color = THEME.BorderRed
			s.Transparency = isLocked and 0.2 or 0.6
			s.Parent = btn

			btn.MouseButton1Click:Connect(function()
				loopBringToggle(player, btn)
			end)
		end
	end
end

-- Bring ALL / Stop ALL toggle
AllButton.MouseButton1Click:Connect(function()
	local allLocked = true
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer and not LoopBrings[p.UserId] then
			allLocked = false
			break
		end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			if allLocked then
				LoopBrings[p.UserId] = nil
				if p.Character then
					local hum = p.Character:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.WalkSpeed = 16
						hum.JumpPower = 50
					end
				end
			else
				LoopBrings[p.UserId] = true
			end
		end
	end
	updatePlayerList()
end)

Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(function(player: Player)
	LoopBrings[player.UserId] = nil
	updatePlayerList()
end)

updatePlayerList()
print("[Loopbring] CIPHER // AGGRESSIVE LOOPBRING V4.0 Loaded successfully.")
