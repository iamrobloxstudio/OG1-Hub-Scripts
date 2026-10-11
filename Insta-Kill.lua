--!strict
-- ================================================================
-- ⚡ CIPHER // INSTA-KILL BURST AURA V4.0 (STANDALONE SSS EDITION)
-- Hyper-Burst Target Lock & 90Hz Multi-Part Destruction Engine
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

-- Executor API Resolver
local fireTouch: ((BasePart, BasePart, number) -> ())? = firetouchinterest 
	or (getgenv and (getgenv().firetouchinterest or getgenv().fire_touch_interest))
	or (syn and syn.firetouchinterest)

if not fireTouch then
	warn("[Insta-Kill] firetouchinterest executor closure not found. Touch damage disabled.")
end

-- Configuration
local RANGE: number           = 40
local RANGE_SQ: number        = RANGE * RANGE
local TOUCH_BURST: number     = 4      -- touch pairs per target part per pulse
local REMOTE_BURST: number    = 3      -- remote fires per remote per pulse
local TARGET_REFRESH: number  = 1 / 60 -- 60 Hz target scan
local ACTIVE_INTERVAL: number = 1 / 90 -- 90 Hz attack while target exists
local IDLE_INTERVAL: number   = 1 / 30
local TOGGLE_KEY              = Enum.KeyCode.J
local Active: boolean         = true

-- State & Tool Caches
local toolList: { Tool }                   = {}
local touchCache: { [Tool]: BasePart }     = {}
local remoteCache: { [Tool]: RemoteEvent } = {}
local remotes: { RemoteEvent }             = {}

local currentTarget: Model?
local currentTargetRoot: BasePart?
local currentTargetHum: Humanoid?
local currentParts: { BasePart }           = {}

local lastTargetUpdate: number = 0
local lastAttack: number       = 0
local activeState: boolean     = false

local localCharacter: Model?
local localRoot: BasePart?
local charEpoch: number        = 0

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
local existingUI = guiContainer:FindFirstChild("CipherInstaKillUI")
if existingUI then existingUI:Destroy() end

-- ================================================================
-- 3. SSS RED CYBER HACKER DRAGGABLE GUI
-- ================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CipherInstaKillUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiContainer

local MainCard = Instance.new("Frame")
MainCard.Name = "MainCard"
MainCard.Size = UDim2.fromOffset(240, 68)
MainCard.Position = UDim2.new(0.5, -120, 0.12, 0)
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
HeaderTitle.Text = "⚡ CIPHER // INSTA-KILL [J]"
HeaderTitle.Parent = Header

local StatusDot = Instance.new("Frame")
StatusDot.Size = UDim2.fromOffset(8, 8)
StatusDot.Position = UDim2.new(1, -16, 0.5, -4)
StatusDot.BackgroundColor3 = THEME.ActiveGreen
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
ToggleButton.TextColor3 = THEME.ActiveGreen
ToggleButton.Text = "⚡ INSTA-KILL: ACTIVE // 90Hz"
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
		ToggleButton.Text = "⚡ INSTA-KILL: ACTIVE // 90Hz"
		ToggleButton.TextColor3 = THEME.ActiveGreen
		StatusDot.BackgroundColor3 = THEME.ActiveGreen
		CardStroke.Color = THEME.BorderRed
	else
		ToggleButton.Text = "⚡ INSTA-KILL: STANDBY [J]"
		ToggleButton.TextColor3 = THEME.TextMuted
		StatusDot.BackgroundColor3 = THEME.AccentDim
		CardStroke.Color = Color3.fromRGB(50, 50, 60)
	end
end
updateUI()

local function toggleActive()
	Active = not Active
	updateUI()
end

ToggleButton.MouseButton1Click:Connect(toggleActive)

UserInputService.InputBegan:Connect(function(input: InputObject, gpe: boolean)
	if gpe then return end
	if input.KeyCode == TOGGLE_KEY then
		toggleActive()
	end
end)

-- ================================================================
-- 4. REMOTE DISCOVERY
-- ================================================================
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

-- ================================================================
-- 5. CHARACTER BIND & TOOL MONITOR
-- ================================================================
local function bindCharacter(char: Model)
	charEpoch += 1
	local myEpoch = charEpoch
	localCharacter = char
	localRoot = nil
	if not char then return end

	local r = char:FindFirstChild("HumanoidRootPart")
	if not r then r = char:WaitForChild("HumanoidRootPart", 5) end
	if charEpoch == myEpoch and r and r:IsA("BasePart") then
		localRoot = r
	end
end

local function rebuildCache()
	table.clear(toolList)
	table.clear(touchCache)
	table.clear(remoteCache)
	table.clear(remotes)

	local char = localCharacter
	if not char then return end

	for _, o in ipairs(char:GetChildren()) do
		if o:IsA("Tool") then
			table.insert(toolList, o)

			local tx = o:FindFirstChildWhichIsA("TouchTransmitter", true)
			local touch = tx and tx.Parent
			if not (touch and touch:IsA("BasePart")) then
				touch = o:FindFirstChild("Handle")
			end
			if touch and touch:IsA("BasePart") then
				touchCache[o] = touch
				touch.CanCollide = false
				touch.Massless = true
				touch.CanTouch = true
			end

			local rem = findFightRemote(o)
			if rem then
				remoteCache[o] = rem
				table.insert(remotes, rem)
			end
		end
	end
end

local function hookTools(char: Model)
	if not char then return end
	local function refresh()
		task.defer(rebuildCache)
	end
	char.ChildAdded:Connect(function(o: Instance)
		if o:IsA("Tool") then refresh() end
	end)
	char.ChildRemoved:Connect(function(o: Instance)
		if o:IsA("Tool") then refresh() end
	end)
	rebuildCache()
end

if LocalPlayer.Character then
	bindCharacter(LocalPlayer.Character)
	hookTools(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char: Model)
	bindCharacter(char)
	hookTools(char)
end)

-- ================================================================
-- 6. TARGET PARTS EXPANDER (R6 & R15)
-- ================================================================
local PRIORITY_PARTS = {
	"HumanoidRootPart",
	"Head",
	"UpperTorso",
	"LowerTorso",
	"Torso",
}

local function buildParts(char: Model): { BasePart }
	local t: { BasePart } = {}
	for i = 1, #PRIORITY_PARTS do
		local p = char:FindFirstChild(PRIORITY_PARTS[i])
		if p and p:IsA("BasePart") then
			table.insert(t, p)
		end
	end
	if #t == 0 then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			table.insert(t, hrp)
		end
	end
	return t
end

-- ================================================================
-- 7. TARGET ACQUISITION (SQUARED DISTANCE)
-- ================================================================
local function updateTarget()
	local now = os.clock()
	if now - lastTargetUpdate < TARGET_REFRESH then return end
	lastTargetUpdate = now

	local myRoot = localRoot
	if not myRoot then
		currentTarget = nil
		currentTargetRoot = nil
		currentTargetHum = nil
		table.clear(currentParts)
		activeState = false
		return
	end

	local myPos = myRoot.Position
	local bestChar: Model? = nil
	local bestRoot: BasePart? = nil
	local bestHum: Humanoid? = nil
	local bestD: number = RANGE_SQ

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local r = char:FindFirstChild("HumanoidRootPart")
				if hum and r and r:IsA("BasePart") and hum.Health > 0 then
					local dx = r.Position.X - myPos.X
					local dy = r.Position.Y - myPos.Y
					local dz = r.Position.Z - myPos.Z
					local dsq = dx * dx + dy * dy + dz * dz
					if dsq < bestD then
						bestD = dsq
						bestChar = char
						bestRoot = r
						bestHum = hum
					end
				end
			end
		end
	end

	currentTarget = bestChar
	currentTargetRoot = bestRoot
	currentTargetHum = bestHum
	currentParts = bestChar and buildParts(bestChar) or {}
	activeState = (bestChar ~= nil)
end

-- ================================================================
-- 8. ATTACK ENGINE (BURST TOUCH & REMOTES)
-- ================================================================
local function hitTarget()
	if not activeState or not Active then return end
	local hum = currentTargetHum
	if not hum or hum.Health <= 0 then return end

	if #currentParts == 0 and currentTarget then
		currentParts = buildParts(currentTarget)
	end

	-- High MS Ping Double-Tap Touch Interest Burst
	if fireTouch then
		for i = 1, #toolList do
			local touch = touchCache[toolList[i]]
			if touch and touch.Parent then
				for p = 1, #currentParts do
					local target = currentParts[p]
					if target and target.Parent then
						for _ = 1, TOUCH_BURST do
							pcall(fireTouch, touch, target, 0)
							pcall(fireTouch, touch, target, 1)
						end
					end
				end
			end
		end
	end

	-- Remote event burst
	local root = currentTargetRoot
	if root and root.Parent then
		for i = 1, #remotes do
			local r = remotes[i]
			if r and r.Parent then
				for _ = 1, REMOTE_BURST do
					pcall(r.FireServer, r, root)
				end
			end
		end
	end
end

-- ================================================================
-- 9. MAIN RUNNER
-- ================================================================
RunService.Stepped:Connect(function()
	if not Active then return end

	updateTarget()

	local interval = activeState and ACTIVE_INTERVAL or IDLE_INTERVAL
	local now = os.clock()
	if now - lastAttack < interval then return end
	lastAttack = now

	if activeState then
		hitTarget()
	end
end)

print("[Insta-Kill] CIPHER // INSTA-KILL BURST AURA V4.0 Loaded successfully.")
