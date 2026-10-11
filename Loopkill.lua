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

local TOGGLE_KEY = Enum.KeyCode.T
local TOUCH_BURST = 6
local REMOTE_BURST = 3

-- Executor API Resolver
local fireTouch: ((BasePart, BasePart, number) -> ())? = firetouchinterest 
	or (getgenv and (getgenv().firetouchinterest or getgenv().fire_touch_interest))
	or (syn and syn.firetouchinterest)

if not fireTouch then
	warn("[Target Aura] firetouchinterest executor closure not found. Touch damage disabled.")
end

-- Localized Standalone State
local TargetList: { [Player]: boolean } = {}
local Active: boolean = true

-- Priority Parts for Full Body Coverage
local PRIORITY_PARTS = {
	"HumanoidRootPart",
	"Head",
	"UpperTorso",
	"LowerTorso",
	"Torso",
	"Right Arm",
	"Left Arm",
	"Right Leg",
	"Left Leg",
}

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
local existingUI = guiContainer:FindFirstChild("CipherTargetAuraUI")
if existingUI then existingUI:Destroy() end

-- ================================================================
-- 3. SSS RED CYBER HACKER DRAGGABLE GUI
-- ================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CipherTargetAuraUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiContainer

local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.fromOffset(250, 42)
MainFrame.Position = UDim2.new(0.5, -125, 0.01, 0)
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

-- Control Bar (Drag Handle)
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

-- Micro Button Factory
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

local ToggleButton = createBarButton("⚡ TARGET AURA [T]", 136, 1)
local SelectAllBtn  = createBarButton("ALL", 46, 2)
local ClearAllBtn   = createBarButton("CLR", 46, 3)

ToggleButton.TextColor3 = THEME.AccentRed

-- Dropdown Panel for Targets
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

setupDraggable(MainFrame, MainFrame)

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
-- 4. PLAYER LIST SELECTION CONTROLS
-- ================================================================
local function updatePlayerList()
	for _, child in ipairs(ScrollList:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local isSelected = TargetList[player] == true

			local btn = Instance.new("TextButton")
			btn.Name = player.Name
			btn.Size = UDim2.new(1, -6, 0, 26)
			btn.BackgroundColor3 = isSelected and THEME.AccentDim or THEME.CardBg
			btn.TextColor3 = isSelected and THEME.AccentRed or THEME.TextPrimary
			btn.Font = Enum.Font.GothamBold
			btn.TextSize = 11
			btn.AutoButtonColor = false
			btn.Text = (isSelected and "⚡ " or "") .. player.Name .. (isSelected and " [TARGET]" or "")
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
				if TargetList[player] then
					TargetList[player] = nil
				else
					TargetList[player] = true
				end
				updatePlayerList()
			end)
		end
	end
end

SelectAllBtn.MouseButton1Click:Connect(function()
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			TargetList[p] = true
		end
	end
	updatePlayerList()
end)

ClearAllBtn.MouseButton1Click:Connect(function()
	table.clear(TargetList)
	updatePlayerList()
end)

Players.PlayerAdded:Connect(updatePlayerList)
Players.PlayerRemoving:Connect(function(player: Player)
	TargetList[player] = nil
	updatePlayerList()
end)

updatePlayerList()

-- ================================================================
-- 5. ATTACK ENGINE (DUAL-DISPATCH: TOUCH BURST + REMOTE FIRE)
-- ================================================================
local function getTouchInterest(tool: Tool): BasePart?
	for _, obj in ipairs(tool:GetDescendants()) do
		if obj:IsA("TouchTransmitter") and obj.Parent and obj.Parent:IsA("BasePart") then
			return obj.Parent
		end
	end
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle
	end
	return nil
end

local function findFightRemote(tool: Tool): RemoteEvent?
	local r = tool:FindFirstChild("FightEvent")
	if r and r:IsA("RemoteEvent") then return r end
	for _, o in ipairs(tool:GetDescendants()) do
		if o:IsA("RemoteEvent") then
			local n = string.lower(o.Name)
			if string.find(n, "fight", 1, true) or string.find(n, "slap", 1, true) or string.find(n, "event", 1, true) then
				return o
			end
		end
	end
	return nil
end

local function executeTargetAttack()
	if not Active then return end
	if not next(TargetList) then return end

	local char = LocalPlayer.Character
	if not char then return end

	-- Find active target characters
	local targetsToHit: { Model } = {}
	for plr, isTargeted in pairs(TargetList) do
		if isTargeted and plr.Character then
			local hum = plr.Character:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				table.insert(targetsToHit, plr.Character)
			end
		end
	end

	if #targetsToHit == 0 then return end

	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local touch = getTouchInterest(tool)
			local remote = findFightRemote(tool)

			if touch and touch.Parent then
				touch.CanCollide = false
				touch.Massless = true
				touch.CanTouch = true

				for _, targetChar in ipairs(targetsToHit) do
					local targetHRP = targetChar:FindFirstChild("HumanoidRootPart") or targetChar:FindFirstChild("Torso")

					-- 1. Full Body Multi-Touch Burst
					if fireTouch then
						for p = 1, #PRIORITY_PARTS do
							local part = targetChar:FindFirstChild(PRIORITY_PARTS[p])
							if part and part:IsA("BasePart") and part.Parent then
								for _ = 1, TOUCH_BURST do
									pcall(fireTouch, touch, part, 0)
									pcall(fireTouch, touch, part, 1)
								end
							end
						end
					end

					-- 2. Direct Combat Remote Dispatch
					if remote and targetHRP then
						for _ = 1, REMOTE_BURST do
							pcall(remote.FireServer, remote, targetHRP)
						end
					end
				end
			end
		end
	end
end

-- Dual-phase frame execution on Stepped AND Heartbeat for instantaneous damage delivery
RunService.Stepped:Connect(executeTargetAttack)
RunService.Heartbeat:Connect(executeTargetAttack)

print("[Target Aura] CIPHER // TARGET AURA V5.0 Loaded (Dual-Dispatch SSS Edition).")
