--!strict
-- ================================================================
-- ⚡ CIPHER // USE TOOLS V4.2 (STANDALONE SSS EDITION)
-- Simultaneous Multi-Tool Equipper & Steady High-Rate Activation Engine
-- Multi-Weapon Concurrency (MAX_TOOLS) | Zero Ping-Spike Cadence Pacer
-- Anti-Snag 1v1 Escape Physics | Draggable SSS Red Cyber Hacker UI
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

-- ================================================================
-- 1. SSS RED CYBER HACKER THEME & CONSTANTS
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

-- Executor API Resolver
local fireTouch: ((BasePart, BasePart, number) -> ())? = firetouchinterest
	or (getgenv and (getgenv().firetouchinterest or getgenv().fire_touch_interest))
	or (syn and syn.firetouchinterest)

-- Configuration (10 - 150 APS, 1 - 10 Tools)
local APS: number                = 60
local MAX_TOOLS: number          = 5
local TOUCH_ASSIST_RANGE: number = 16
local TOUCH_ASSIST_SQ: number    = TOUCH_ASSIST_RANGE * TOUCH_ASSIST_RANGE

-- Modes: "Normal" (Activate only), "Event" (FightEvent only), "Max" (Both with steady 25 APS)
local Mode: string               = "Normal"
local Active: boolean            = false

-- State - cached references for zero GC overhead
local ToolsCache: { Tool }       = {}
local CurrentCharacter: Model?   = nil
local CurrentRoot: BasePart?     = nil
local LastPulse: number          = 0
local CharacterConnections: { RBXScriptConnection } = {}
local ReequipToken: number       = 0

-- Pre-allocated tables to reduce GC pressure
local TargetPartsBuffer: { BasePart } = {}
local TempToolsBuffer: { Tool }       = {}

-- ================================================================
-- 2. GUI RESOLVER
-- ================================================================
local function getGuiParent(): Instance
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

local parentGui = getGuiParent()
local existing = parentGui:FindFirstChild("CipherUseToolsUI")
if existing then existing:Destroy() end

local Connections: { RBXScriptConnection } = {}

local function track(conn: RBXScriptConnection): RBXScriptConnection
	table.insert(Connections, conn)
	return conn
end

-- ================================================================
-- 3. CHARACTER UTILITIES & ANTI-SNAG TOOL PHYSICS
-- ================================================================
local function getHRP(char: Model?): BasePart?
	if not char then return nil end
	local r = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
	return (r and r:IsA("BasePart")) and r or nil
end

local function sanitizeToolPhysics(tool: Tool)
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		handle.CanCollide = false
		handle.Massless = true
		handle.CanTouch = true
	end
end

-- ================================================================
-- 4. FAST TOOL CACHING ENGINE
-- ================================================================
local function cacheTools()
	table.clear(TempToolsBuffer)
	local char = CurrentCharacter
	if not char then return end

	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			sanitizeToolPhysics(child)
			table.insert(TempToolsBuffer, child)
			if #TempToolsBuffer >= MAX_TOOLS then break end
		end
	end

	table.clear(ToolsCache)
	for i = 1, #TempToolsBuffer do
		ToolsCache[i] = TempToolsBuffer[i]
	end
end

-- ================================================================
-- 5. SIMULTANEOUS MULTI-TOOL CONCURRENCY ENGINE
-- ================================================================
-- Enforces that exactly MAX_TOOLS are equipped at the exact same time
local function syncEquippedTools()
	if not Active then return end
	local char = CurrentCharacter
	if not char then return end

	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end

	-- 1. Scan currently equipped tools in character
	local equippedTools: { Tool } = {}
	for _, child in ipairs(char:GetChildren()) do
		if child:IsA("Tool") then
			table.insert(equippedTools, child)
		end
	end

	local count = #equippedTools

	-- 2. If more tools than MAX_TOOLS, unequip excess to backpack
	if count > MAX_TOOLS then
		for i = MAX_TOOLS + 1, count do
			local tool = equippedTools[i]
			if tool and tool.Parent == char then
				tool.Parent = backpack
			end
		end
	-- 3. If fewer tools than MAX_TOOLS, equip tools from backpack concurrently
	elseif count < MAX_TOOLS then
		local needed = MAX_TOOLS - count
		for _, tool in ipairs(backpack:GetChildren()) do
			if tool:IsA("Tool") then
				sanitizeToolPhysics(tool)
				-- Parenting directly to character allows multiple tools equipped simultaneously
				tool.Parent = char
				needed -= 1
				if needed <= 0 then break end
			end
		end
	end

	cacheTools()
end

-- ================================================================
-- 6. DAMAGE PULSE (STEADY HIGH-RATE ACTIVATION // NO PING SPIKES)
-- ================================================================
local function getToolTouchPart(tool: Tool): BasePart?
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle
	end
	for _, obj in ipairs(tool:GetDescendants()) do
		if obj:IsA("TouchTransmitter") and obj.Parent and obj.Parent:IsA("BasePart") then
			return obj.Parent
		end
	end
	return nil
end

local function damagePulse()
	if #ToolsCache == 0 then return end
	local char = CurrentCharacter
	local root = CurrentRoot
	if not char or not root then return end

	-- Find enemy parts within touch range using squared distance
	table.clear(TargetPartsBuffer)
	local myPos = root.Position

	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local pChar = player.Character
			if pChar then
				local hum = pChar:FindFirstChildOfClass("Humanoid")
				local pRoot = pChar:FindFirstChild("HumanoidRootPart")
				if hum and pRoot and pRoot:IsA("BasePart") and hum.Health > 0 then
					local dx = pRoot.Position.X - myPos.X
					local dy = pRoot.Position.Y - myPos.Y
					local dz = pRoot.Position.Z - myPos.Z
					if (dx * dx + dy * dy + dz * dz) <= TOUCH_ASSIST_SQ then
						table.insert(TargetPartsBuffer, pRoot)
					end
				end
			end
		end
	end

	-- Dispatch tool actions to ALL simultaneously equipped tools
	for i = 1, #ToolsCache do
		local tool = ToolsCache[i]
		if tool and tool.Parent == char then
			-- 1. Fast steady activation spam
			if Mode == "Normal" or Mode == "Max" then
				pcall(tool.Activate, tool)
			end

			-- 2. FightEvent Remote Trigger (Single steady fire per tool per pulse)
			if Mode == "Event" or Mode == "Max" then
				local remote = tool:FindFirstChild("FightEvent")
				if not remote then
					for _, d in ipairs(tool:GetDescendants()) do
						if d:IsA("RemoteEvent") then
							local n = string.lower(d.Name)
							if string.find(n, "fight", 1, true) or string.find(n, "slap", 1, true) then
								remote = d
								break
							end
						end
					end
				end
				if remote and remote:IsA("RemoteEvent") then
					pcall(remote.FireServer, remote)
				end
			end

			-- 3. Touch Interest Assistance
			if fireTouch and #TargetPartsBuffer > 0 then
				local touchPart = getToolTouchPart(tool)
				if touchPart and touchPart.Parent then
					for p = 1, #TargetPartsBuffer do
						local enemyPart = TargetPartsBuffer[p]
						if enemyPart and enemyPart.Parent then
							pcall(fireTouch, touchPart, enemyPart, 0)
							pcall(fireTouch, touchPart, enemyPart, 1)
						end
					end
				end
			end
		end
	end
end

-- ================================================================
-- 7. SSS RED CYBER HACKER DRAGGABLE GUI
-- ================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CipherUseToolsUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = parentGui

-- Draggable Main Container
local MainPanel = Instance.new("Frame")
MainPanel.Name = "MainPanel"
MainPanel.Size = UDim2.fromOffset(220, 215)
MainPanel.Position = UDim2.new(1, -240, 0.5, -107)
MainPanel.BackgroundColor3 = THEME.VoidBg
MainPanel.BackgroundTransparency = 0.08
MainPanel.BorderSizePixel = 0
MainPanel.Active = true
MainPanel.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainPanel

local MainStroke = Instance.new("UIStroke")
MainStroke.Thickness = 1.5
MainStroke.Color = THEME.BorderRed
MainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
MainStroke.Parent = MainPanel

-- Header (Drag Handle)
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 28)
Header.BackgroundColor3 = THEME.CardBg
Header.BorderSizePixel = 0
Header.Parent = MainPanel

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size = UDim2.new(1, -20, 1, 0)
HeaderTitle.Position = UDim2.new(0, 10, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextSize = 11
HeaderTitle.TextColor3 = THEME.AccentRed
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.Text = "⚡ CIPHER // USE TOOLS [E]"
HeaderTitle.Parent = Header

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.fromOffset(8, 8)
StatusDot.Position = UDim2.new(1, -16, 0.5, -4)
StatusDot.BackgroundColor3 = THEME.AccentDim
StatusDot.BorderSizePixel = 0
StatusDot.Parent = Header

local DotCorner = Instance.new("UICorner")
DotCorner.CornerRadius = UDim.new(1, 0)
DotCorner.Parent = StatusDot

-- Content Container
local Content = Instance.new("Frame")
Content.Size = UDim2.new(1, -16, 1, -36)
Content.Position = UDim2.new(0, 8, 0, 32)
Content.BackgroundTransparency = 1
Content.Parent = MainPanel

local ContentLayout = Instance.new("UIListLayout")
ContentLayout.SortOrder = Enum.SortOrder.LayoutOrder
ContentLayout.Padding = UDim.new(0, 5)
ContentLayout.Parent = Content

-- Cyber Button Factory
local function createCyberButton(text: string, height: number, order: number): TextButton
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, 0, 0, height)
	btn.BackgroundColor3 = THEME.CardBg
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 12
	btn.TextColor3 = THEME.TextPrimary
	btn.Text = text
	btn.AutoButtonColor = false
	btn.LayoutOrder = order
	btn.Parent = Content

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
		TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = THEME.AccentDim}):Play()
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.12), {BackgroundColor3 = THEME.CardBg}):Play()
	end)

	return btn
end

-- Primary Toggle Button
local ToggleButton = createCyberButton("STATUS: STANDBY", 32, 1)
ToggleButton.TextColor3 = THEME.AccentRed

-- Mode Button
local ModeButton = createCyberButton("MODE: NORMAL [F]", 26, 2)
ModeButton.TextSize = 11

-- Row Factory (APS & Tools Stepper)
local function createStepperRow(title: string, order: number)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 26)
	row.BackgroundColor3 = THEME.CardBg
	row.BackgroundTransparency = 0.5
	row.LayoutOrder = order
	row.Parent = Content

	local rc = Instance.new("UICorner")
	rc.CornerRadius = UDim.new(0, 6)
	rc.Parent = row

	local rs = Instance.new("UIStroke")
	rs.Thickness = 1
	rs.Color = THEME.BorderRed
	rs.Transparency = 0.6
	rs.Parent = row

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(0.42, 0, 1, 0)
	label.Position = UDim2.new(0, 6, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextSize = 11
	label.TextColor3 = THEME.TextMuted
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = title
	label.Parent = row

	local minusBtn = Instance.new("TextButton")
	minusBtn.Size = UDim2.new(0, 24, 0, 20)
	minusBtn.Position = UDim2.new(0.45, 0, 0.5, -10)
	minusBtn.BackgroundColor3 = THEME.CardBg
	minusBtn.Font = Enum.Font.GothamBold
	minusBtn.TextSize = 12
	minusBtn.TextColor3 = THEME.AccentRed
	minusBtn.Text = "-"
	minusBtn.AutoButtonColor = false
	minusBtn.Parent = row
	local mc = Instance.new("UICorner")
	mc.CornerRadius = UDim.new(0, 4)
	mc.Parent = minusBtn

	local valLabel = Instance.new("TextLabel")
	valLabel.Size = UDim2.new(0, 40, 1, 0)
	valLabel.Position = UDim2.new(0.60, 0, 0, 0)
	valLabel.BackgroundTransparency = 1
	valLabel.Font = Enum.Font.Code
	valLabel.TextSize = 12
	valLabel.TextColor3 = THEME.TextPrimary
	valLabel.Text = "0"
	valLabel.Parent = row

	local plusBtn = Instance.new("TextButton")
	plusBtn.Size = UDim2.new(0, 24, 0, 20)
	plusBtn.Position = UDim2.new(1, -28, 0.5, -10)
	plusBtn.BackgroundColor3 = THEME.CardBg
	plusBtn.Font = Enum.Font.GothamBold
	plusBtn.TextSize = 12
	plusBtn.TextColor3 = THEME.AccentRed
	plusBtn.Text = "+"
	plusBtn.AutoButtonColor = false
	plusBtn.Parent = row
	local pc = Instance.new("UICorner")
	pc.CornerRadius = UDim.new(0, 4)
	pc.Parent = plusBtn

	return valLabel, minusBtn, plusBtn
end

local APSLabel, APSMinus, APSPlus = createStepperRow("APS RATE", 3)
local ToolsLabel, ToolsMinus, ToolsPlus = createStepperRow("MAX WEAPONS", 4)

-- Sub-badge: Latency Compensator Indicator
local PingBadge = Instance.new("TextLabel")
PingBadge.Size = UDim2.new(1, 0, 0, 18)
PingBadge.BackgroundTransparency = 1
PingBadge.Font = Enum.Font.Code
PingBadge.TextSize = 10
PingBadge.TextColor3 = THEME.TextMuted
PingBadge.Text = "// MS PING COMP: 0ms CLAMP"
PingBadge.LayoutOrder = 5
PingBadge.Parent = Content

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

setupDraggable(MainPanel, Header)

-- ================================================================
-- 8. UI CONTROLS & STATE SYNC
-- ================================================================
local function updateUI()
	if Active then
		ToggleButton.Text = "STATUS: ACTIVE // ONLINE"
		ToggleButton.TextColor3 = THEME.ActiveGreen
		StatusDot.BackgroundColor3 = THEME.ActiveGreen
		MainStroke.Color = THEME.AccentRed
	else
		ToggleButton.Text = "STATUS: STANDBY [E]"
		ToggleButton.TextColor3 = THEME.AccentRed
		StatusDot.BackgroundColor3 = THEME.AccentDim
		MainStroke.Color = THEME.BorderRed
	end

	ModeButton.Text = "MODE: " .. string.upper(Mode) .. " [F]"
	APSLabel.Text = tostring(Mode == "Max" and 25 or APS)
	ToolsLabel.Text = tostring(MAX_TOOLS)

	local isMax = (Mode == "Max")
	APSMinus.Visible = not isMax
	APSPlus.Visible = not isMax
end

local function setState(newState: boolean)
	Active = newState
	updateUI()

	if Active then
		syncEquippedTools()
	else
		ReequipToken += 1

		local char = CurrentCharacter
		if char then
			local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
			if backpack then
				for _, tool in ipairs(char:GetChildren()) do
					if tool:IsA("Tool") then
						tool.Parent = backpack
					end
				end
			end
		end
		table.clear(ToolsCache)
	end
end

local function cycleMode()
	if Mode == "Normal" then
		Mode = "Event"
	elseif Mode == "Event" then
		Mode = "Max"
	else
		Mode = "Normal"
	end
	updateUI()
end

-- UI Listeners
ToggleButton.MouseButton1Click:Connect(function()
	setState(not Active)
end)

ModeButton.MouseButton1Click:Connect(cycleMode)

APSMinus.MouseButton1Click:Connect(function()
	if Mode ~= "Max" then
		APS = math.max(10, APS - 10)
		updateUI()
	end
end)

APSPlus.MouseButton1Click:Connect(function()
	if Mode ~= "Max" then
		APS = math.min(150, APS + 10)
		updateUI()
	end
end)

ToolsMinus.MouseButton1Click:Connect(function()
	MAX_TOOLS = math.max(1, MAX_TOOLS - 1)
	updateUI()
	if Active then
		syncEquippedTools()
	end
end)

ToolsPlus.MouseButton1Click:Connect(function()
	MAX_TOOLS = math.min(10, MAX_TOOLS + 1)
	updateUI()
	if Active then
		syncEquippedTools()
	end
end)

-- Keybinds: [E] Toggle, [F] Mode
track(UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.E then
		setState(not Active)
	elseif input.KeyCode == Enum.KeyCode.F then
		cycleMode()
	end
end))

-- ================================================================
-- 9. CHARACTER BIND & INSTANT HEALTH MONITORING
-- ================================================================
local function hookCharacter(char: Model)
	CurrentCharacter = char
	CurrentRoot = getHRP(char)

	for _, conn in ipairs(CharacterConnections) do
		if conn and conn.Connected then conn:Disconnect() end
	end
	table.clear(CharacterConnections)

	local hum = char:WaitForChild("Humanoid", 5)
	if hum and hum:IsA("Humanoid") then
		table.insert(CharacterConnections, hum.HealthChanged:Connect(function(hp: number)
			if Active and hp <= 20 and hp > 0 then
				syncEquippedTools()
			end
		end))

		table.insert(CharacterConnections, hum.Died:Connect(function()
			if Active then
				syncEquippedTools()
			end
		end))
	end

	table.insert(CharacterConnections, char.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") and Active then
			cacheTools()
		end
	end))

	table.insert(CharacterConnections, char.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") and Active then
			task.defer(syncEquippedTools)
		end
	end))

	if Active then
		syncEquippedTools()
	end
end

if LocalPlayer.Character then
	hookCharacter(LocalPlayer.Character)
end
track(LocalPlayer.CharacterAdded:Connect(hookCharacter))

local function bindBackpack(backpack: Backpack?)
	if not backpack then return end
	track(backpack.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") and Active then
			task.defer(syncEquippedTools)
		end
	end))
end

bindBackpack(LocalPlayer:FindFirstChildOfClass("Backpack"))
track(LocalPlayer.ChildAdded:Connect(function(child: Instance)
	if child:IsA("Backpack") then
		bindBackpack(child :: Backpack)
		if Active then
			syncEquippedTools()
		end
	end
end))

-- ================================================================
-- 10. STEADY HIGH-RATE RUNNER (ZERO PING-SPIKE PACER)
-- ================================================================
track(RunService.PreSimulation:Connect(function()
	if not Active then return end

	local now = os.clock()
	-- Cadenced rate pacing: Max uses 25 APS, Normal uses user APS (10-150)
	local effectiveAPS = (Mode == "Max" and 25 or math.clamp(APS, 10, 150))
	local pulseInterval = 1 / effectiveAPS

	if now - LastPulse < pulseInterval then return end
	LastPulse = now

	local char = CurrentCharacter
	if not char then return end

	-- Continuously verify that the exact MAX_TOOLS count is equipped
	if #ToolsCache ~= MAX_TOOLS then
		syncEquippedTools()
	else
		cacheTools()
	end

	if #ToolsCache > 0 then
		damagePulse()
	end
end))

updateUI()
print("[Use Tools] CIPHER // USE TOOLS V4.2 Loaded successfully (Max Weapons Simultaneous Equipper).")
