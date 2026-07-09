-- TFL Use Tools
-- Advanced tool activation system with 3 modes and configurable settings
-- Black/Green hacker aesthetic theme

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
local MAX_TOOLS = 20
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

-- Configuration globals for external modification
_G.TFL_UseTools = {
	APS = APS,
	MaxTools = MAX_TOOLS,
	Mode = Mode,
	SetAPS = function(value)
		APS = math.clamp(value, 10, 200)
		_G.TFL_UseTools.APS = APS
	end,
	SetMaxTools = function(value)
		MAX_TOOLS = math.clamp(value, 1, 50)
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
	CurrentCharacter = nil
	CurrentRoot = nil
end

_G.__TFLUseToolsCleanup = cleanup

-- Helper functions
local function getHRP(char)
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function getTouchPart(tool)
	for _, obj in ipairs(tool:GetDescendants()) do
		if obj:IsA("TouchTransmitter") and obj.Parent and obj.Parent:IsA("BasePart") then
			return obj.Parent
		end
	end
	return nil
end

-- Character bind
local function bindCharacter(char)
	CurrentCharacter = char
	CurrentRoot = char and getHRP(char)
	
	if char then
		char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				task.wait(0.05)
				refreshTools()
			end
		end)
		char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				task.wait(0.05)
				refreshTools()
			end
		end)
	end
end

track(LocalPlayer.CharacterAdded:Connect(bindCharacter))
track(LocalPlayer.CharacterRemoving:Connect(function()
	CurrentCharacter = nil
	CurrentRoot = nil
	table.clear(ToolsCache)
end))

if LocalPlayer.Character then
	bindCharacter(LocalPlayer.Character)
end

-- Refresh tools (respect MaxTools limit)
local function refreshTools(forceEquip)
	table.clear(ToolsCache)
	
	local char = CurrentCharacter
	if not char then return end
	
	-- Equip tools if needed
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

-- Touch assist for nearby targets
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
	
	for _, tool in ipairs(ToolsCache) do
		local touch = getTouchPart(tool)
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
			local touch = getTouchPart(tool)
			
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
local function createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TFLUseTools"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.Parent = CoreGui
	
	-- Main panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(180, 140)
	panel.Position = UDim2.fromScale(0.98, 0.55)
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.BackgroundColor3 = THEME.Panel
	panel.BackgroundTransparency = 0.08
	panel.Parent = screenGui
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
	modeBtn.Size = UDim2.new(1, -20, 0, 24)
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
	
	-- Status label
	local statusLbl = Instance.new("TextLabel")
	statusLbl.Name = "Status"
	statusLbl.Size = UDim2.new(1, -20, 0, 20)
	statusLbl.Position = UDim2.fromOffset(10, 80)
	statusLbl.BackgroundTransparency = 1
	statusLbl.TextColor3 = THEME.Text
	statusLbl.Font = Enum.Font.Gotham
	statusLbl.TextSize = 12
	statusLbl.TextXAlignment = Enum.TextXAlignment.Left
	statusLbl.Text = "APS: 80 | Tools: 0"
	statusLbl.Parent = panel
	
	-- Tool limit label
	local limitLbl = Instance.new("TextLabel")
	limitLbl.Name = "Limit"
	limitLbl.Size = UDim2.new(1, -20, 0, 20)
	limitLbl.Position = UDim2.fromOffset(10, 105)
	limitLbl.BackgroundTransparency = 1
	limitLbl.TextColor3 = THEME.Text
	limitLbl.Font = Enum.Font.Gotham
	limitLbl.TextSize = 12
	limitLbl.TextXAlignment = Enum.TextXAlignment.Left
	limitLbl.Text = "Max Tools: 20"
	limitLbl.Parent = panel
	
	return screenGui, toggleBtn, modeBtn, statusLbl, limitLbl
end

local ScreenGui, ToggleButton, ModeButton, StatusLabel, LimitLabel = createUI()

-- Update UI
local function updateUI()
	if ToggleButton then
		ToggleButton.Text = Active and "USE TOOLS: ON" or "USE TOOLS: OFF"
	end
	if ModeButton then
		ModeButton.Text = "Mode: " .. Mode
	end
	if StatusLabel then
		StatusLabel.Text = "APS: " .. APS .. " | Tools: " .. #ToolsCache
	end
	if LimitLabel then
		LimitLabel.Text = "Max Tools: " .. MAX_TOOLS
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

print("[TFL Use Tools] Loaded - Advanced tool activation system ready")