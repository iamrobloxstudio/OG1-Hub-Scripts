-- TFL Use Tools
-- Advanced tool activation system with 3 modes and configurable settings
-- Black/Green hacker aesthetic theme with mobile/PC scaling

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- TFL Theme (Black/Green Hacker Aesthetic)
local THEME = {
	Background = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(0, 15, 0),
	Button = Color3.fromRGB(0, 25, 0),
	Text = Color3.fromRGB(0, 255, 0),
	On = Color3.fromRGB(0, 40, 0),
	Accent = Color3.fromRGB(0, 255, 0),
}

-- Configuration
local APS = 80
local MAX_TOOLS = 5
local TOUCH_ASSIST_RANGE = 14
local TOUCH_BURST = 1

-- Modes: "Normal" (Activate only), "Event" (FightEvent only), "Max" (Both)
local Mode = "Normal"
local Active = false

-- State
local ToolsCache = {}
local CurrentCharacter = nil
local CurrentRoot = nil
local LastPulse = 0
local BurstActive = false
local ToolWelds = {}

-- Configuration globals for external modification
_G.TFL_UseTools = {
	APS = APS,
	MaxTools = MAX_TOOLS,
	Mode = Mode,
	SetAPS = function(value)
		APS = math.clamp(value, 10, 1000)
		_G.TFL_UseTools.APS = APS
	end,
	SetMaxTools = function(value)
		MAX_TOOLS = math.clamp(value, 1, 10)
		_G.TFL_UseTools.MaxTools = MAX_TOOLS
	end,
	SetMode = function(mode)
		if mode == "Normal" or mode == "Event" or mode == "Max" then
			Mode = mode
			_G.TFL_UseTools.Mode = mode
		end
	end,
}

-- Cleanup
if _G.__TFLUseToolsCleanup then
	pcall(_G.__TFLUseToolsCleanup)
end

local Connections = {}
local function track(conn)
	table.insert(Connections, conn)
	return conn
end

local function cleanup()
	for _, conn in ipairs(Connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(Connections)
	table.clear(ToolsCache)
	table.clear(ToolWelds)
	CurrentCharacter = nil
	CurrentRoot = nil
end

_G.__TFLUseToolsCleanup = cleanup

-- Mobile/PC scaling function
local function updateScale()
	if not workspace.CurrentCamera then return end
	local viewport = workspace.CurrentCamera.ViewportSize
	local minDim = math.min(viewport.X, viewport.Y)
	
	if UserInputService.TouchEnabled then
		-- Mobile scaling - smaller UI for small screens
		return math.clamp(minDim / 720, 0.7, 0.95)
	else
		-- PC scaling - standard size
		return math.clamp(minDim / 1200, 0.9, 1.1)
	end
end

-- Helper functions
local function getHRP(char)
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function getToolPart(tool)
	if tool:FindFirstChild("Handle") and tool.Handle:IsA("BasePart") then
		return tool.Handle
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

-- Create weld to keep tool attached to character
local function weldTool(tool)
	if not tool or not tool:IsA("Tool") then return end
	
	local part = getToolPart(tool)
	if not part then return end
	
	-- Remove existing weld
	if ToolWelds[tool] then
		ToolWelds[tool]:Destroy()
	end
	
	-- Create weld constraint
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = part
	weld.Part1 = tool.Parent:FindFirstChild("HumanoidRootPart") or tool.Parent:FindFirstChild("Torso")
	if weld.Part1 then
		weld.Parent = part
		ToolWelds[tool] = weld
		return weld
	end
	return nil
end

-- Character bind
local function bindCharacter(char)
	CurrentCharacter = char
	CurrentRoot = char and getHRP(char)
	
	if char then
		-- Set up tool physics and welds
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				task.wait(0.05)
				-- Set tool physics to prevent flying away
				local part = getToolPart(child)
				if part then
					part.CanCollide = false
					part.Massless = true
					part.Anchored = false
				end
				weldTool(child)
				refreshTools()
			end
		end)
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				ToolWelds[child] = nil
			end
		end)
	end
end

track(LocalPlayer.CharacterAdded:Connect(bindCharacter))
track(LocalPlayer.CharacterRemoving:Connect(function()
	CurrentCharacter = nil
	CurrentRoot = nil
	table.clear(ToolsCache)
	table.clear(ToolWelds)
end))

if LocalPlayer.Character then
	bindCharacter(LocalPlayer.Character)
end

-- Refresh tools (respect MaxTools limit)
local function refreshTools(forceEquip)
	table.clear(ToolsCache)
	
	local char = CurrentCharacter
	if not char then return end
	
	-- Equip tools if needed (with debounce)
	if forceEquip then
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		if backpack then
			for _, tool in ipairs(backpack:GetChildren()) do
				if tool:IsA("Tool") then
					tool.Parent = char
				end
			end
		end
	end
	
	-- Cache tools (limit to MAX_TOOLS)
	local count = 0
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") and count < MAX_TOOLS then
			count += 1
			table.insert(ToolsCache, tool)
			-- Ensure tool physics
			local part = getToolPart(tool)
			if part then
				part.CanCollide = false
				part.Massless = true
			end
		end
	end
end

-- Get closest target for touch assist
local function getClosestTarget()
	if not CurrentRoot then return nil end
	
	local closest = nil
	local bestDist = TOUCH_ASSIST_RANGE
	
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			if char then
				local root = getHRP(char)
				local hum = char:FindFirstChildOfClass("Humanoid")
				if root and hum and hum.Health > 0 then
					local dist = (root.Position - CurrentRoot.Position).Magnitude
					if dist < bestDist then
						bestDist = dist
						closest = char
					end
				end
			end
		end
	end
	
	return closest
end

-- Touch assist for nearby targets (only when not jumping to prevent launch)
local function touchAssist()
	local target = getClosestTarget()
	if not target then return end
	
	local targetParts = {}
	for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "Torso", "Head"}) do
		local part = target:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(targetParts, part)
		end
	end
	
	if #targetParts == 0 then return end
	
	-- Only touch if velocity is low (not jumping/launching)
	local myHRP = getHRP(CurrentCharacter)
	if myHRP and myHRP.AssemblyLinearVelocity.Magnitude > 50 then
		return -- Skip touch assist to prevent launching
	end
	
	for _, tool in ipairs(ToolsCache) do
		local touch = getToolPart(tool)
		if touch then
			for _, part in ipairs(targetParts) do
				pcall(firetouchinterest, touch, part, 0)
				pcall(firetouchinterest, touch, part, 1)
			end
		end
	end
end

-- Activate tools based on mode
local function activateTools()
	for _, tool in ipairs(ToolsCache) do
		if tool and tool.Parent then
			local fightEvent = tool:FindFirstChild("FightEvent", true)
			
			-- Mode: Normal (Activate only)
			if Mode == "Normal" then
				pcall(tool.Activate, tool)
			end
			
			-- Mode: Event or Max (FightEvent)
			if fightEvent and fightEvent:IsA("RemoteEvent") then
				pcall(function()
					fightEvent:FireServer()
				end)
			end
			
			-- Mode: Max - also activate
			if Mode == "Max" then
				pcall(tool.Activate, tool)
			end
		end
	end
end

-- Damage pulse (activate + touch)
local function damagePulse()
	activateTools()
	touchAssist()
end

-- Respawn burst
local function startBurst()
	if BurstActive or not Active then return end
	BurstActive = true
	
	task.spawn(function()
		local startTime = os.clock()
		
		refreshTools(true)
		RunService.Heartbeat:Wait()
		
		while Active and LocalPlayer.Character and os.clock() - startTime < 2.0 do
			refreshTools(false)
			if #ToolsCache > 0 then
				damagePulse()
			end
			RunService.Heartbeat:Wait()
		end
		
		BurstActive = false
	end)
end

-- UI Functions
local ScreenGui, Panel, APSMinus, APSPlus, APSValue, ToolsMinus, ToolsPlus, ToolsValue, ModeButton, ToggleButton

local function createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TFLUseTools"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.Parent = CoreGui
	
	-- Add UI Scale for mobile/PC
	local uiScale = Instance.new("UIScale", screenGui)
	uiScale.Scale = updateScale()
	
	-- Update scale on resize
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			uiScale.Scale = updateScale()
		end)
	end
	
	-- Main panel (larger for controls)
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(220, 200)
	panel.Position = UDim2.fromScale(0.98, 0.55)
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.BackgroundColor3 = THEME.Panel
	panel.BackgroundTransparency = 0.08
	panel.Parent = screenGui
	panel.Active = true
	panel.Draggable = true
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	Instance.new("UIStroke", panel).Color = THEME.Accent
	
	-- Toggle button
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "Toggle"
	toggleBtn.Size = UDim2.new(1, -20, 0, 34)
	toggleBtn.Position = UDim2.fromOffset(10, 10)
	toggleBtn.BackgroundColor3 = THEME.Button
	toggleBtn.TextColor3 = THEME.Text
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextSize = 14
	toggleBtn.Text = "USE TOOLS: OFF"
	toggleBtn.AutoButtonColor = false
	toggleBtn.Parent = panel
	Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
	Instance.new("UIStroke", toggleBtn).Color = THEME.Accent
	
	-- Mode button
	local modeBtn = Instance.new("TextButton")
	modeBtn.Name = "Mode"
	modeBtn.Size = UDim2.new(1, -20, 0, 26)
	modeBtn.Position = UDim2.fromOffset(10, 50)
	modeBtn.BackgroundColor3 = THEME.Button
	modeBtn.TextColor3 = THEME.Text
	modeBtn.Font = Enum.Font.Gotham
	modeBtn.TextSize = 12
	modeBtn.Text = "Mode: Normal"
	modeBtn.AutoButtonColor = false
	modeBtn.Parent = panel
	Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0, 6)
	Instance.new("UIStroke", modeBtn).Color = THEME.Accent
	
	-- APS controls
	local apsLabel = Instance.new("TextLabel")
	apsLabel.Name = "APSLabel"
	apsLabel.Size = UDim2.new(0, 40, 0, 24)
	apsLabel.Position = UDim2.fromOffset(10, 85)
	apsLabel.BackgroundTransparency = 1
	apsLabel.Text = "APS"
	apsLabel.TextColor3 = THEME.Text
	apsLabel.Font = Enum.Font.Gotham
	apsLabel.TextSize = 12
	apsLabel.TextXAlignment = Enum.TextXAlignment.Left
	apsLabel.Parent = panel
	
	local apsMinus = Instance.new("TextButton")
	apsMinus.Name = "APSMinus"
	apsMinus.Size = UDim2.new(0, 30, 0, 24)
	apsMinus.Position = UDim2.fromOffset(55, 85)
	apsMinus.BackgroundColor3 = THEME.Button
	apsMinus.TextColor3 = THEME.Text
	apsMinus.Font = Enum.Font.GothamBold
	apsMinus.TextSize = 14
	apsMinus.Text = "-"
	apsMinus.AutoButtonColor = false
	apsMinus.Parent = panel
	Instance.new("UICorner", apsMinus).CornerRadius = UDim.new(0, 6)
	Instance.new("UIStroke", apsMinus).Color = THEME.Accent
	
	local apsPlus = Instance.new("TextButton")
	apsPlus.Name = "APSPlus"
	apsPlus.Size = UDim2.new(0, 30, 0, 24)
	apsPlus.Position = UDim2.fromOffset(90, 85)
	apsPlus.BackgroundColor3 = THEME.Button
	apsPlus.TextColor3 = THEME.Text
	apsPlus.Font = Enum.Font.GothamBold
	apsPlus.TextSize = 14
	apsPlus.Text = "+"
	apsPlus.AutoButtonColor = false
	apsPlus.Parent = panel
	Instance.new("UICorner", apsPlus).CornerRadius = UDim.new(0, 6)
	Instance.new("UIStroke", apsPlus).Color = THEME.Accent
	
	local apsVal = Instance.new("TextLabel")
	apsVal.Name = "APSValue"
	apsVal.Size = UDim2.new(0, 60, 0, 24)
	apsVal.Position = UDim2.fromOffset(125, 85)
	apsVal.BackgroundColor3 = THEME.On
	apsVal.TextColor3 = THEME.Text
	apsVal.Font = Enum.Font.Gotham
	apsVal.TextSize = 12
	apsVal.Text = "80"
	apsVal.Parent = panel
	Instance.new("UICorner", apsVal).CornerRadius = UDim.new(0, 6)
	
	-- Tools controls
	local toolsLabel = Instance.new("TextLabel")
	toolsLabel.Name = "ToolsLabel"
	toolsLabel.Size = UDim2.new(0, 40, 0, 24)
	toolsLabel.Position = UDim2.fromOffset(10, 115)
	toolsLabel.BackgroundTransparency = 1
	toolsLabel.Text = "Tools"
	toolsLabel.TextColor3 = THEME.Text
	toolsLabel.Font = Enum.Font.Gotham
	toolsLabel.TextSize = 12
	toolsLabel.TextXAlignment = Enum.TextXAlignment.Left
	toolsLabel.Parent = panel
	
	local toolsMinus = Instance.new("TextButton")
	toolsMinus.Name = "ToolsMinus"
	toolsMinus.Size = UDim2.new(0, 30, 0, 24)
	toolsMinus.Position = UDim2.fromOffset(55, 115)
	toolsMinus.BackgroundColor3 = THEME.Button
	toolsMinus.TextColor3 = THEME.Text
	toolsMinus.Font = Enum.Font.GothamBold
	toolsMinus.TextSize = 14
	toolsMinus.Text = "-"
	toolsMinus.AutoButtonColor = false
	toolsMinus.Parent = panel
	Instance.new("UICorner", toolsMinus).CornerRadius = UDim.new(0, 6)
	Instance.new("UIStroke", toolsMinus).Color = THEME.Accent
	
	local toolsPlus = Instance.new("TextButton")
	toolsPlus.Name = "ToolsPlus"
	toolsPlus.Size = UDim2.new(0, 30, 0, 24)
	toolsPlus.Position = UDim2.fromOffset(90, 115)
	toolsPlus.BackgroundColor3 = THEME.Button
	toolsPlus.TextColor3 = THEME.Text
	toolsPlus.Font = Enum.Font.GothamBold
	toolsPlus.TextSize = 14
	toolsPlus.Text = "+"
	toolsPlus.AutoButtonColor = false
	toolsPlus.Parent = panel
	Instance.new("UICorner", toolsPlus).CornerRadius = UDim.new(0, 6)
	Instance.new("UIStroke", toolsPlus).Color = THEME.Accent
	
	local toolsVal = Instance.new("TextLabel")
	toolsVal.Name = "ToolsValue"
	toolsVal.Size = UDim2.new(0, 60, 0, 24)
	toolsVal.Position = UDim2.fromOffset(125, 115)
	toolsVal.BackgroundColor3 = THEME.On
	toolsVal.TextColor3 = THEME.Text
	toolsVal.Font = Enum.Font.Gotham
	toolsVal.TextSize = 12
	toolsVal.Text = "5"
	toolsVal.Parent = panel
	Instance.new("UICorner", toolsVal).CornerRadius = UDim.new(0, 6)
	
	return screenGui, panel, toggleBtn, modeBtn, apsMinus, apsPlus, apsVal, toolsMinus, toolsPlus, toolsVal
end

ScreenGui, Panel, ToggleButton, ModeButton, APSMinus, APSPlus, APSValue, ToolsMinus, ToolsPlus, ToolsValue = createUI()

-- Update UI
local function updateUI()
	if ToggleButton then
		ToggleButton.Text = Active and "USE TOOLS: ON" or "USE TOOLS: OFF"
	end
	if ModeButton then
		ModeButton.Text = "Mode: " .. Mode
	end
	if APSValue then
		APSValue.Text = tostring(APS)
	end
	if ToolsValue then
		ToolsValue.Text = tostring(MAX_TOOLS)
	end
end

-- Set state
local function setState(state)
	Active = state and true or false
	updateUI()
	
	if Active then
		refreshTools(true)
		task.defer(function()
			RunService.Heartbeat:Wait()
			refreshTools(false)
			if #ToolsCache > 0 then
				damagePulse()
			end
		end)
	else
		-- Unequip tools when disabled
		if CurrentCharacter then
			for _, tool in ipairs(CurrentCharacter:GetChildren()) do
				if tool:IsA("Tool") then
					local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
					if backpack then
						tool.Parent = backpack
					end
				end
			end
		end
	end
end

-- Cycle modes
local function cycleMode()
	if Mode == "Normal" then
		Mode = "Event"
	elseif Mode == "Event" then
		Mode = "Max"
	else
		Mode = "Normal"
	end
	_G.TFL_UseTools.Mode = Mode
	updateUI()
end

-- UI Events
ToggleButton.MouseButton1Click:Connect(function()
	setState(not Active)
end)

ModeButton.MouseButton1Click:Connect(function()
	cycleMode()
end)

-- APS control buttons
APSMinus.MouseButton1Click:Connect(function()
	APS = math.max(10, APS - 10)
	_G.TFL_UseTools.APS = APS
	updateUI()
end)

APSPlus.MouseButton1Click:Connect(function()
	APS = math.min(1000, APS + 10)
	_G.TFL_UseTools.APS = APS
	updateUI()
end)

-- Tools control buttons
ToolsMinus.MouseButton1Click:Connect(function()
	MAX_TOOLS = math.max(1, MAX_TOOLS - 1)
	_G.TFL_UseTools.MaxTools = MAX_TOOLS
	updateUI()
end)

ToolsPlus.MouseButton1Click:Connect(function()
	MAX_TOOLS = math.min(10, MAX_TOOLS + 1)
	_G.TFL_UseTools.MaxTools = MAX_TOOLS
	updateUI()
end)

-- Keybind
track(UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.E then
		setState(not Active)
	elseif input.KeyCode == Enum.KeyCode.F then
		cycleMode()
	end
end))

-- Respawn handler
track(LocalPlayer.CharacterAdded:Connect(function()
	if Active then
		startBurst()
	end
end))

-- Main loop
track(RunService.PreSimulation:Connect(function()
	if not Active then return end
	
	local now = os.clock()
	local pulseInterval = 1 / APS
	
	if now - LastPulse < pulseInterval then return end
	LastPulse = now
	
	refreshTools(false)
	if #ToolsCache > 0 then
		damagePulse()
	end
	
	updateUI()
end))

-- Initial update
updateUI()

print("[TFL Use Tools] Loaded - Advanced tool activation system ready (APS: 10-1000, Tools: 1-10)")
