--!strict
-- ================================================================
-- ⚡ CIPHER // HIT AMPLIFIER V4.0 (STANDALONE SSS EDITION)
-- High-Performance Proximity Tool Trigger & FightEvent Burst Engine
-- Low CPU Overhead | Draggable SSS Red Cyber Hacker UI
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

local RANGE_STUDS: number    = 32
local HIT_RANGE: Vector3     = Vector3.new(RANGE_STUDS, RANGE_STUDS, RANGE_STUDS)
local SCAN_RATE: number      = 1 / 60
local BURST_COUNT: number    = 3
local TOGGLE_KEY: Enum.KeyCode = Enum.KeyCode.H
local Active: boolean        = true

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
local existingUI = guiContainer:FindFirstChild("CipherHitAmpUI")
if existingUI then existingUI:Destroy() end

-- ================================================================
-- 3. SSS RED CYBER HACKER DRAGGABLE GUI
-- ================================================================
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "CipherHitAmpUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
ScreenGui.Parent = guiContainer

local MainCard = Instance.new("Frame")
MainCard.Name = "MainCard"
MainCard.Size = UDim2.fromOffset(240, 68)
MainCard.Position = UDim2.new(0.5, -120, 0.19, 0)
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
HeaderTitle.Text = "⚔️ CIPHER // HIT AMPLIFIER [H]"
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
ToggleButton.Text = "⚔️ HIT AMPLIFIER: ACTIVE // 60Hz"
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
		ToggleButton.Text = "⚔️ HIT AMPLIFIER: ACTIVE // 60Hz"
		ToggleButton.TextColor3 = THEME.ActiveGreen
		StatusDot.BackgroundColor3 = THEME.ActiveGreen
		CardStroke.Color = THEME.BorderRed
	else
		ToggleButton.Text = "⚔️ HIT AMPLIFIER: STANDBY [H]"
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
-- 4. TOOL CACHING ENGINE
-- ================================================================
local cachedTools: { Tool } = {}

local function rebuildTools()
	table.clear(cachedTools)
	local char = LocalPlayer.Character
	if not char then return end

	for _, obj in ipairs(char:GetChildren()) do
		if obj:IsA("Tool") then
			table.insert(cachedTools, obj)
			local h = obj:FindFirstChild("Handle")
			if h and h:IsA("BasePart") then
				h.CanCollide = false
				h.Massless = true
				h.CanTouch = true
			end
		end
	end
end

local function onChildChanged(obj: Instance)
	if obj:IsA("Tool") then
		task.defer(rebuildTools)
	end
end

local function hookCharacter(char: Model)
	rebuildTools()
	char.ChildAdded:Connect(onChildChanged)
	char.ChildRemoved:Connect(onChildChanged)
end

if LocalPlayer.Character then
	hookCharacter(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(hookCharacter)

-- ================================================================
-- 5. COMBAT DISPATCH
-- ================================================================
local function pulse()
	for i = 1, #cachedTools do
		local tool = cachedTools[i]
		if tool and tool.Parent then
			for _ = 1, BURST_COUNT do
				pcall(tool.Activate, tool)
			end

			local rem = tool:FindFirstChild("FightEvent")
			if not rem then
				for _, d in ipairs(tool:GetDescendants()) do
					if d:IsA("RemoteEvent") then
						local name = string.lower(d.Name)
						if string.find(name, "fight", 1, true) or string.find(name, "slap", 1, true) then
							rem = d
							break
						end
					end
				end
			end

			if rem and rem:IsA("RemoteEvent") then
				pcall(rem.FireServer, rem)
			end
		end
	end
end

-- ================================================================
-- 6. SPATIAL SCAN ENGINE (BOX QUERY)
-- ================================================================
local overlapParams = OverlapParams.new()
overlapParams.FilterType = Enum.RaycastFilterType.Exclude

local accumulator: number = 0

RunService.Stepped:Connect(function(dt: number)
	if not Active then return end

	accumulator += dt
	if accumulator < SCAN_RATE then return end
	accumulator = 0

	local char = LocalPlayer.Character
	if not char then return end

	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not (hrp and hrp:IsA("BasePart")) then return end

	overlapParams.FilterDescendantsInstances = { char }

	local parts = workspace:GetPartBoundsInBox(CFrame.new(hrp.Position), HIT_RANGE, overlapParams)

	for _, part in ipairs(parts) do
		local model = part:FindFirstAncestorOfClass("Model")
		if model and model ~= char then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 then
				pulse()
				break
			end
		end
	end
end)

print("[Hit Amplifier] CIPHER // HIT AMPLIFIER V4.0 Loaded successfully.")
