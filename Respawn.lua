--!strict
-- ================================================================
-- ⚡ CIPHER // QUANTUM RESPAWN V4.0 (STANDALONE SSS EDITION)
-- Ultra-Low Latency Auto-Respawn & Guide Pre-Trigger Engine
-- Early Damage Detection | High MS Ping Fail-Safe | Cyber SSS UI
-- ================================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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

local TOGGLE_KEY: Enum.KeyCode = Enum.KeyCode.R
local HEALTH_THRESHOLD: number = 20    -- Early detection: pre-empts death packet latency
local FAILSAFE_TIME: number    = 0.10  -- Immediate local respawn if remote fails
local BACKUP_DELAY: number     = 0.05
local MIN_FIRE_INTERVAL: number = 0.20

-- State
local Active: boolean          = false
local isFiring: boolean        = false
local lastRequestTime: number  = 0
local characterToken: number   = 0
local activeCharConns: { RBXScriptConnection } = {}

local function disconnectCharConns()
	for _, c in ipairs(activeCharConns) do
		if c and c.Connected then
			c:Disconnect()
		end
	end
	table.clear(activeCharConns)
end

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
local existingUI = guiContainer:FindFirstChild("CipherRespawnUI")
if existingUI then existingUI:Destroy() end

-- ================================================================
-- 3. REMOTE DISCOVERY CACHING
-- ================================================================
local cachedRemotes: { RemoteEvent } = {}

local function refreshRespawnRemotes()
	table.clear(cachedRemotes)
	if not ReplicatedStorage then return end

	for _, o in ipairs(ReplicatedStorage:GetDescendants()) do
		if o:IsA("RemoteEvent") then
			local n = string.lower(o.Name)
			if string.find(n, "respawn", 1, true)
				or string.find(n, "spawn", 1, true)
				or string.find(n, "guide", 1, true)
				or string.find(n, "reset", 1, true)
				or string.find(n, "death", 1, true)
				or string.find(n, "load", 1, true) then
				table.insert(cachedRemotes, o)
			end
		end
	end
end

refreshRespawnRemotes()
if ReplicatedStorage then
	ReplicatedStorage.DescendantAdded:Connect(function(inst: Instance)
		if inst:IsA("RemoteEvent") then
			local n = string.lower(inst.Name)
			if string.find(n, "respawn", 1, true)
				or string.find(n, "spawn", 1, true)
				or string.find(n, "guide", 1, true) then
				table.insert(cachedRemotes, inst)
			end
		end
	end)
end

-- ================================================================
-- 4. QUANTUM RESPAWN ENGINE (PARALLEL DISPATCH)
-- ================================================================
local function fireRespawn()
	if isFiring then return end
	local now = os.clock()
	if now - lastRequestTime < MIN_FIRE_INTERVAL then return end

	isFiring = true
	lastRequestTime = now
	characterToken += 1
	disconnectCharConns()

	-- Parallel dispatch to all candidate remotes
	if #cachedRemotes > 0 then
		for _, r in ipairs(cachedRemotes) do
			if r and r.Parent then
				task.spawn(function()
					pcall(r.FireServer, r)
				end)
			end
		end
	else
		task.delay(BACKUP_DELAY, function()
			if Active then
				pcall(LocalPlayer.LoadCharacter, LocalPlayer)
			end
		end)
	end

	-- High MS Ping failsafe
	task.delay(FAILSAFE_TIME, function()
		if not Active then return end
		if os.clock() - lastRequestTime >= FAILSAFE_TIME then
			pcall(LocalPlayer.LoadCharacter, LocalPlayer)
		end
	end)

	task.delay(0.12, function()
		isFiring = false
	end)
end

-- ================================================================
-- 5. EARLY HEALTH & STATE MONITOR
-- ================================================================
local function hookCharacter(char: Model)
	characterToken += 1
	local myToken = characterToken
	disconnectCharConns()

	local hum = char:WaitForChild("Humanoid", 5)
	if not (hum and hum:IsA("Humanoid")) then return end

	local triggered = false
	local function trigger()
		if triggered then return end
		if not Active then return end
		if characterToken ~= myToken then return end
		triggered = true
		fireRespawn()
	end

	-- 1. Pre-emptive health threshold trigger
	table.insert(activeCharConns, hum.HealthChanged:Connect(function(hp: number)
		if hp <= HEALTH_THRESHOLD then
			trigger()
		end
	end))

	-- 2. State trigger (Dead, Ragdoll, FallingDown)
	table.insert(activeCharConns, hum.StateChanged:Connect(function(_, newState: Enum.HumanoidStateType)
		if newState == Enum.HumanoidStateType.Dead
			or newState == Enum.HumanoidStateType.Ragdoll then
			trigger()
		end
	end))

	-- 3. Died fallback
	table.insert(activeCharConns, hum.Died:Connect(trigger))
end

LocalPlayer.CharacterAdded:Connect(function(char: Model)
	task.defer(function()
		if Active then
			hookCharacter(char)
		end
	end)
end)

-- ================================================================
-- 6. SSS RED CYBER HACKER DRAGGABLE GUI
-- ================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CipherRespawnUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiContainer

local MainCard = Instance.new("Frame")
MainCard.Name = "MainCard"
MainCard.Size = UDim2.fromOffset(230, 68)
MainCard.Position = UDim2.new(1, -250, 0.65, 0)
MainCard.BackgroundColor3 = THEME.VoidBg
MainCard.BackgroundTransparency = 0.08
MainCard.BorderSizePixel = 0
MainCard.Active = true
MainCard.Parent = ScreenGui

local CardCorner = Instance.new("UICorner")
CardCorner.CornerRadius = UDim.new(0, 10)
CardCorner.Parent = MainCard

local CardStroke = Instance.new("UIStroke")
CardStroke.Thickness = 1.5
CardStroke.Color = THEME.BorderRed
CardStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
CardStroke.Parent = MainCard

-- Header (Drag Handle)
local Header = Instance.new("Frame")
Header.Name = "Header"
Header.Size = UDim2.new(1, 0, 0, 24)
Header.BackgroundColor3 = THEME.CardBg
Header.BorderSizePixel = 0
Header.Parent = MainCard

local HeaderCorner = Instance.new("UICorner")
HeaderCorner.CornerRadius = UDim.new(0, 10)
HeaderCorner.Parent = Header

local HeaderTitle = Instance.new("TextLabel")
HeaderTitle.Size = UDim2.new(1, -20, 1, 0)
HeaderTitle.Position = UDim2.new(0, 10, 0, 0)
HeaderTitle.BackgroundTransparency = 1
HeaderTitle.Font = Enum.Font.GothamBold
HeaderTitle.TextSize = 10
HeaderTitle.TextColor3 = THEME.AccentRed
HeaderTitle.TextXAlignment = Enum.TextXAlignment.Left
HeaderTitle.Text = "⚡ CIPHER // FAST RESPAWN [R]"
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

-- Interactive Toggle Button
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "ToggleButton"
ToggleButton.Size = UDim2.new(1, -16, 0, 32)
ToggleButton.Position = UDim2.new(0, 8, 0, 28)
ToggleButton.BackgroundColor3 = THEME.CardBg
ToggleButton.Font = Enum.Font.GothamBold
ToggleButton.TextSize = 12
ToggleButton.TextColor3 = THEME.AccentRed
ToggleButton.Text = "⚡ RESPAWN: STANDBY [R]"
ToggleButton.AutoButtonColor = false
ToggleButton.Parent = MainCard

local BtnCorner = Instance.new("UICorner")
BtnCorner.CornerRadius = UDim.new(0, 6)
BtnCorner.Parent = ToggleButton

local BtnStroke = Instance.new("UIStroke")
BtnStroke.Thickness = 1
BtnStroke.Color = THEME.BorderRed
BtnStroke.Transparency = 0.4
BtnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
BtnStroke.Parent = ToggleButton

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

setupDraggable(MainCard, Header)

-- Hover
ToggleButton.MouseEnter:Connect(function()
	TweenService:Create(ToggleButton, TweenInfo.new(0.12), {BackgroundColor3 = THEME.AccentDim}):Play()
end)
ToggleButton.MouseLeave:Connect(function()
	TweenService:Create(ToggleButton, TweenInfo.new(0.12), {BackgroundColor3 = THEME.CardBg}):Play()
end)

local function updateUI()
	if Active then
		ToggleButton.Text = "⚡ RESPAWN: ACTIVE // ONLINE"
		ToggleButton.TextColor3 = THEME.ActiveGreen
		StatusDot.BackgroundColor3 = THEME.ActiveGreen
		CardStroke.Color = THEME.BorderRed
	else
		ToggleButton.Text = "⚡ RESPAWN: STANDBY [R]"
		ToggleButton.TextColor3 = THEME.TextMuted
		StatusDot.BackgroundColor3 = THEME.AccentDim
		CardStroke.Color = Color3.fromRGB(50, 50, 60)
	end
end
updateUI()

local function toggleActive()
	Active = not Active
	if Active then
		if LocalPlayer.Character then
			hookCharacter(LocalPlayer.Character)
		end
	else
		disconnectCharConns()
	end
	updateUI()
end

ToggleButton.MouseButton1Click:Connect(toggleActive)

UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
	if gpe then return end
	if input.KeyCode == TOGGLE_KEY then
		toggleActive()
	end
end)

print("[Respawn] CIPHER // QUANTUM RESPAWN V4.0 Loaded successfully.")
