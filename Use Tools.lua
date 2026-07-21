-- TFL Use Tools
-- Advanced tool activation system with 3 modes and configurable settings
-- Black/Green hacker aesthetic theme with mobile/PC scaling
-- OPTIMIZED: Instant activation, single equip, minimal latency

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
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

-- Configuration (10 - 1000 APS, 1 - 10 Tools)
local APS = 80
local MAX_TOOLS = 5
local TOUCH_ASSIST_RANGE = 14

-- Modes: "Normal" (Activate only), "Event" (FightEvent only), "Max" (Both with fixed 10 APS)
local Mode = "Normal"
local Active = false

-- State - cached references for performance
local ToolsCache = {}
local ToolWelds = {}
local CurrentCharacter = nil
local CurrentRoot = nil
local LastPulse = 0
local CharacterConnections = {}

-- Pre-allocated tables to reduce GC pressure
local TargetPartsBuffer = {}
local TempToolsBuffer = {}

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
	
	-- Clean up Motor6D welds
	for _, weld in pairs(ToolWelds) do
		if weld and weld.Parent then
			weld:Destroy()
		end
	end
	table.clear(ToolWelds)
	
	table.clear(ToolsCache)
	CurrentCharacter = nil
	CurrentRoot = nil
	Active = false
end

_G.__TFLUseToolsCleanup = cleanup

-- Helper functions - cached for performance
local function getHRP(char)
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

local function getRightHand(char)
	return char and (char:FindFirstChild("RightHand") or char:FindFirstChild("Right Arm"))
end

local function getLeftHand(char)
	return char and (char:FindFirstChild("LeftHand") or char:FindFirstChild("Left Arm"))
end

-- Get tool touch part - optimized
local function getToolTouchPart(tool)
	local handle = tool:FindFirstChild("Handle")
	if handle and handle:IsA("BasePart") then
		return handle
	end
	-- Fast path: check for TouchTransmitter in tool
	for _, obj in ipairs(tool:GetDescendants()) do
		if obj:IsA("TouchTransmitter") and obj.Parent and obj.Parent:IsA("BasePart") then
			return obj.Parent
		end
	end
	return nil
end

-- Motor6D Weld System - Prevent tools from falling locally
local function removeToolWeld(tool)
	local weld = ToolWelds[tool]
	if weld then
		if weld.Parent then
			weld:Destroy()
		end
		ToolWelds[tool] = nil
	end
end

-- Apply visual welds to keep all tools attached to hands
-- OPTIMIZED: Natural grip positioning - tools appear as if being held normally
-- Uses the tool's original Grip and GripPos for proper positioning
local function applyToolWelds()
	if not CurrentCharacter or not Active then return end
	
	local char = CurrentCharacter
	local rightHand = getRightHand(char)
	local leftHand = getLeftHand(char)
	
	if not rightHand or not leftHand then return end
	
	-- Separate tools into RightHand and LeftHand groups
	local rightHandTools = {}
	local leftHandTools = {}
	
	for _, tool in ipairs(ToolsCache) do
		local handle = tool and tool:FindFirstChild("Handle")
		if handle and handle:IsA("BasePart") then
			-- Axe goes to LeftHand for better separation, others to RightHand
			if tool.Name and tool.Name:lower():find("axe") then
				table.insert(leftHandTools, tool)
			else
				table.insert(rightHandTools, tool)
			end
		end
	end
	
	-- Weld RightHand tools with natural grip positioning
	-- Use the tool's original Grip and GripPos for proper positioning
	for i, tool in ipairs(rightHandTools) do
		local handle = tool:FindFirstChild("Handle")
		if handle then
			removeToolWeld(tool)
			
			local weld = Instance.new("Motor6D")
			weld.Name = "TFL_ToolWeld"
			weld.Part0 = handle
			weld.Part1 = rightHand
			
			-- C0: Position relative to handle (inverse of GripPos)
			weld.C0 = CFrame.new(-tool.GripPos.X, -tool.GripPos.Y, -tool.GripPos.Z)
			
			-- C1: Position relative to hand
			-- Use the tool's original Grip for natural positioning
			-- Apply small angular offset to make multiple tools visible
			local angleOffset = (i - 1) * 0.3
			weld.C1 = tool.Grip * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), angleOffset)
			
			weld.Parent = handle
			ToolWelds[tool] = weld
			
			-- Prevent handle from colliding with world and interfering with character movement
			if not handle:GetAttribute("TFL_WasCanCollide") then
				handle:SetAttribute("TFL_WasCanCollide", handle.CanCollide)
			end
			handle.CanCollide = false
			handle.Massless = true
			-- IMPORTANT: Keep CanTouch enabled for touch events to work!
		end
	end
	
	-- Weld LeftHand tools (typically just Axe)
	for i, tool in ipairs(leftHandTools) do
		local handle = tool:FindFirstChild("Handle")
		if handle then
			removeToolWeld(tool)
			
			local weld = Instance.new("Motor6D")
			weld.Name = "TFL_ToolWeld"
			weld.Part0 = handle
			weld.Part1 = leftHand
			
			weld.C0 = CFrame.new(-tool.GripPos.X, -tool.GripPos.Y, -tool.GripPos.Z)
			weld.C1 = tool.Grip
			
			weld.Parent = handle
			ToolWelds[tool] = weld
			
			if not handle:GetAttribute("TFL_WasCanCollide") then
				handle:SetAttribute("TFL_WasCanCollide", handle.CanCollide)
			end
			handle.CanCollide = false
			handle.Massless = true
			-- IMPORTANT: Keep CanTouch enabled for touch events to work!
		end
	end
end

-- Remove all tool welds (called on deactivation)
local function removeAllToolWelds()
	for _, tool in ipairs(ToolsCache) do
		if tool then
			local handle = tool:FindFirstChild("Handle")
			if handle then
				local wasCanCollide = handle:GetAttribute("TFL_WasCanCollide")
				if wasCanCollide ~= nil then
					handle.CanCollide = wasCanCollide
				end
				handle.Massless = false
			end
			removeToolWeld(tool)
		end
	end
	table.clear(ToolWelds)
end

-- Character bind
local function bindCharacter(char)
	CurrentCharacter = char
	CurrentRoot = char and getHRP(char)
	
	-- Clean up old character connections
	for _, conn in ipairs(CharacterConnections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(CharacterConnections)
	
	-- Set up new character connections
	if char then
		table.insert(CharacterConnections, char.ChildAdded:Connect(function(child)
			if child:IsA("Tool") and Active then
				-- Cache tools immediately when added
				table.clear(TempToolsBuffer)
				for _, tool in ipairs(char:GetChildren()) do
					if tool:IsA("Tool") then
						table.insert(TempToolsBuffer, tool)
					end
				end
				-- Apply welds to new tool
				if #TempToolsBuffer > 0 then
					applyToolWelds()
				end
			end
		end))
		
		table.insert(CharacterConnections, char.ChildRemoved:Connect(function(child)
			if child:IsA("Tool") then
				removeToolWeld(child)
			end
		end))
	end
end

track(LocalPlayer.CharacterAdded:Connect(bindCharacter))
track(LocalPlayer.CharacterRemoving:Connect(function()
	CurrentCharacter = nil
	CurrentRoot = nil
	removeAllToolWelds()
	table.clear(ToolsCache)
end))

if LocalPlayer.Character then
	bindCharacter(LocalPlayer.Character)
end

-- Equip up to MAX_TOOLS from backpack - OPTIMIZED: single pass
local function equipAllTools()
	local char = CurrentCharacter
	if not char then return end
	
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	if not backpack then return end
	
	local equippedCount = 0
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") and equippedCount < MAX_TOOLS then
			tool.Parent = char
			equippedCount = equippedCount + 1
		end
	end
end

-- Cache currently equipped tools (respects MAX_TOOLS limit) - OPTIMIZED: single pass
local function cacheTools()
	table.clear(ToolsCache)
	local char = CurrentCharacter
	if not char then return end
	
	local count = 0
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			count = count + 1
			if count <= MAX_TOOLS then
				table.insert(ToolsCache, tool)
			end
		end
	end
end

-- Get closest target for touch assist (exclude self) - OPTIMIZED: pre-allocated buffer
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

-- Touch assist for nearby targets - OPTIMIZED: pre-allocated buffer
local function touchAssist()
	local target = getClosestTarget()
	if not target then return end
	
	-- Build target parts using pre-allocated buffer
	table.clear(TargetPartsBuffer)
	for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "Torso", "Head"}) do
		local part = target:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(TargetPartsBuffer, part)
		end
	end
	
	if #TargetPartsBuffer == 0 then return end
	
	for _, tool in ipairs(ToolsCache) do
		if tool and tool.Parent and tool:IsDescendantOf(workspace) then
			local touch = getToolTouchPart(tool)
			if touch then
				for _, part in ipairs(TargetPartsBuffer) do
					pcall(firetouchinterest, touch, part, 0)
					pcall(firetouchinterest, touch, part, 1)
				end
			end
		end
	end
end

-- Activate tools based on mode - OPTIMIZED: direct calls
local function activateTools()
	for _, tool in ipairs(ToolsCache) do
		if tool and tool.Parent and tool:IsDescendantOf(workspace) then
			local fightEvent = tool:FindFirstChild("FightEvent", true)
			
			-- Mode: Normal (Activate only) - no event fired
			if Mode == "Normal" then
				pcall(tool.Activate, tool)
			end
			
			-- Mode: Event (FightEvent only) - no Activate called
			if Mode == "Event" and fightEvent and fightEvent:IsA("RemoteEvent") then
				pcall(fightEvent.FireServer, fightEvent)
			end
			
			-- Mode: Max (Both Activate and FightEvent)
			if Mode == "Max" then
				pcall(tool.Activate, tool)
				if fightEvent and fightEvent:IsA("RemoteEvent") then
					pcall(fightEvent.FireServer, fightEvent)
				end
			end
		end
	end
end

-- Damage pulse (activate + touch)
local function damagePulse()
	activateTools()
	touchAssist()
end

-- UI Functions with mobile/PC scaling
local UIScale

local function createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TFLUseTools"
	screenGui.ResetOnSpawn = false
	screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Global
	screenGui.Parent = CoreGui
	
	UIScale = Instance.new("UIScale", screenGui)
	
	local function updateScale()
		local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
		local minDim = math.min(viewport.X, viewport.Y)
		
		if UserInputService.TouchEnabled then
			UIScale.Scale = math.clamp(minDim / 720, 0.7, 0.85)
		else
			UIScale.Scale = math.clamp(minDim / 1200, 0.9, 1.1)
		end
	end
	
	updateScale()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
	end
	
	-- Main panel
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.Size = UDim2.fromOffset(200, 180)
	panel.Position = UDim2.fromScale(0.98, 0.55)
	panel.AnchorPoint = Vector2.new(1, 0.5)
	panel.BackgroundColor3 = THEME.Panel
	panel.BackgroundTransparency = 0.08
	panel.Parent = screenGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	Instance.new("UIStroke", panel).Color = THEME.Accent
	
	local mainLayout = Instance.new("UIListLayout", panel)
	mainLayout.Padding = UDim.new(0, 6)
	mainLayout.SortOrder = Enum.SortOrder.LayoutOrder
	mainLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	
	local uiPadding = Instance.new("UIPadding", panel)
	uiPadding.PaddingLeft = UDim.new(0, 10)
	uiPadding.PaddingRight = UDim.new(0, 10)
	uiPadding.PaddingTop = UDim.new(0, 8)
	
	-- Toggle button
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "Toggle"
	toggleBtn.Size = UDim2.new(1, 0, 0, 30)
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
	modeBtn.Size = UDim2.new(1, 0, 0, 24)
	modeBtn.BackgroundColor3 = THEME.Button
	modeBtn.TextColor3 = THEME.Text
	modeBtn.Font = Enum.Font.Gotham
	modeBtn.TextSize = 12
	modeBtn.Text = "Mode: Normal"
	modeBtn.AutoButtonColor = false
	modeBtn.Parent = panel
	Instance.new("UICorner", modeBtn).CornerRadius = UDim.new(0, 6)
	Instance.new("UIStroke", modeBtn).Color = THEME.Accent
	
	-- APS control row
	local apsRow = Instance.new("Frame")
	apsRow.Name = "APSRow"
	apsRow.Size = UDim2.new(1, 0, 0, 24)
	apsRow.BackgroundTransparency = 1
	apsRow.Parent = panel
	
	local apsLayout = Instance.new("UIListLayout", apsRow)
	apsLayout.FillDirection = Enum.FillDirection.Horizontal
	apsLayout.Padding = UDim.new(0, 4)
	
	local apsLbl = Instance.new("TextLabel")
	apsLbl.Name = "Label"
	apsLbl.Size = UDim2.new(0, 40, 1, 0)
	apsLbl.BackgroundTransparency = 1
	apsLbl.TextColor3 = THEME.Text
	apsLbl.Font = Enum.Font.Gotham
	apsLbl.TextSize = 12
	apsLbl.Text = "APS:"
	apsLbl.Parent = apsRow
	
	local apsMinus = Instance.new("TextButton")
	apsMinus.Size = UDim2.new(0, 30, 1, 0)
	apsMinus.BackgroundColor3 = THEME.Button
	apsMinus.TextColor3 = THEME.Text
	apsMinus.Font = Enum.Font.GothamBold
	apsMinus.TextSize = 14
	apsMinus.Text = "-"
	apsMinus.AutoButtonColor = false
	apsMinus.Parent = apsRow
	Instance.new("UICorner", apsMinus).CornerRadius = UDim.new(0, 4)
	Instance.new("UIStroke", apsMinus).Color = THEME.Accent
	
	local apsValue = Instance.new("TextLabel")
	apsValue.Name = "Value"
	apsValue.Size = UDim2.new(0, 40, 1, 0)
	apsValue.BackgroundTransparency = 1
	apsValue.TextColor3 = THEME.Text
	apsValue.Font = Enum.Font.Gotham
	apsValue.TextSize = 12
	apsValue.Text = tostring(APS)
	apsValue.Parent = apsRow
	
	local apsPlus = Instance.new("TextButton")
	apsPlus.Size = UDim2.new(0, 30, 1, 0)
	apsPlus.BackgroundColor3 = THEME.Button
	apsPlus.TextColor3 = THEME.Text
	apsPlus.Font = Enum.Font.GothamBold
	apsPlus.TextSize = 14
	apsPlus.Text = "+"
	apsPlus.AutoButtonColor = false
	apsPlus.Parent = apsRow
	Instance.new("UICorner", apsPlus).CornerRadius = UDim.new(0, 4)
	Instance.new("UIStroke", apsPlus).Color = THEME.Accent
	
	-- Tools control row
	local toolsRow = Instance.new("Frame")
	toolsRow.Name = "ToolsRow"
	toolsRow.Size = UDim2.new(1, 0, 0, 24)
	toolsRow.BackgroundTransparency = 1
	toolsRow.Parent = panel
	
	local toolsLayout = Instance.new("UIListLayout", toolsRow)
	toolsLayout.FillDirection = Enum.FillDirection.Horizontal
	toolsLayout.Padding = UDim.new(0, 4)
	
	local toolsLbl = Instance.new("TextLabel")
	toolsLbl.Name = "Label"
	toolsLbl.Size = UDim2.new(0, 40, 1, 0)
	toolsLbl.BackgroundTransparency = 1
	toolsLbl.TextColor3 = THEME.Text
	toolsLbl.Font = Enum.Font.Gotham
	toolsLbl.TextSize = 12
	toolsLbl.Text = "Tools:"
	toolsLbl.Parent = toolsRow
	
	local toolsMinus = Instance.new("TextButton")
	toolsMinus.Size = UDim2.new(0, 30, 1, 0)
	toolsMinus.BackgroundColor3 = THEME.Button
	toolsMinus.TextColor3 = THEME.Text
	toolsMinus.Font = Enum.Font.GothamBold
	toolsMinus.TextSize = 14
	toolsMinus.Text = "-"
	toolsMinus.AutoButtonColor = false
	toolsMinus.Parent = toolsRow
	Instance.new("UICorner", toolsMinus).CornerRadius = UDim.new(0, 4)
	Instance.new("UIStroke", toolsMinus).Color = THEME.Accent
	
	local toolsValue = Instance.new("TextLabel")
	toolsValue.Name = "Value"
	toolsValue.Size = UDim2.new(0, 40, 1, 0)
	toolsValue.BackgroundTransparency = 1
	toolsValue.TextColor3 = THEME.Text
	toolsValue.Font = Enum.Font.Gotham
	toolsValue.TextSize = 12
	toolsValue.Text = tostring(MAX_TOOLS)
	toolsValue.Parent = toolsRow
	
	local toolsPlus = Instance.new("TextButton")
	toolsPlus.Size = UDim2.new(0, 30, 1, 0)
	toolsPlus.BackgroundColor3 = THEME.Button
	toolsPlus.TextColor3 = THEME.Text
	toolsPlus.Font = Enum.Font.GothamBold
	toolsPlus.TextSize = 14
	toolsPlus.Text = "+"
	toolsPlus.AutoButtonColor = false
	toolsPlus.Parent = toolsRow
	Instance.new("UICorner", toolsPlus).CornerRadius = UDim.new(0, 4)
	Instance.new("UIStroke", toolsPlus).Color = THEME.Accent
	
	return screenGui, toggleBtn, modeBtn, apsValue, toolsValue, apsMinus, apsPlus, toolsMinus, toolsPlus
end

local ScreenGui, ToggleButton, ModeButton, APSValue, ToolsValue, APSMinus, APSPlus, ToolsMinus, ToolsPlus = createUI()

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
	
	-- Disable APS controls in Max mode (fixed at 10)
	local apsDisabled = Mode == "Max"
	if apsMinus then apsMinus.Active = not apsDisabled end
	if apsPlus then apsPlus.Active = not apsDisabled end
end

-- Set state - OPTIMIZED: Equip tools on activation, unequip ALL on deactivation
local function setState(state)
	Active = state and true or false
	updateUI()
	
	if Active then
		equipAllTools()
		cacheTools()
		applyToolWelds()
	else
		-- Unequip ALL tools when deactivating
		local char = CurrentCharacter
		if char then
			for _, tool in ipairs(char:GetChildren()) do
				if tool:IsA("Tool") then
					local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
					if backpack then
						tool.Parent = backpack
					end
				end
			end
		end
		table.clear(ToolsCache)
		removeAllToolWelds()
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

APSMinus.MouseButton1Click:Connect(function()
	-- Only allow APS change if not in Max mode
	if Mode ~= "Max" then
		APS = math.max(10, APS - 10)
		_G.TFL_UseTools.APS = APS
		updateUI()
	end
end)

APSPlus.MouseButton1Click:Connect(function()
	-- Only allow APS change if not in Max mode
	if Mode ~= "Max" then
		APS = math.min(1000, APS + 10)
		_G.TFL_UseTools.APS = APS
		updateUI()
	end
end)

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

-- ============================================================================
-- GUIDE() - Call this function to run a re-equip loop
-- OPTIMIZED: Instant re-equip with minimal delay, no burst firing
-- ============================================================================

-- Death backup: listen to Humanoid.Died on current character
local function listenForDeath(char)
	if not char then return end
	local hum = char:FindFirstChildWhichIsA("Humanoid")
	if not hum then return end
	
	-- Track the death connection so we can disconnect on cleanup
	if _G.__TFL_DeathConn and _G.__TFL_DeathConn.Connected then
		_G.__TFL_DeathConn:Disconnect()
	end
	
	_G.__TFL_DeathConn = hum.Died:Connect(function()
		if not Active then return end
		-- Run Guide() after death - minimal delay for respawn
		task.spawn(function()
			-- Use Heartbeat wait instead of fixed delay for better ping handling
			RunService.Heartbeat:Wait()
			Guide()
		end)
	end)
	
	-- Also track in Connections for cleanup
	table.insert(Connections, _G.__TFL_DeathConn)
end

-- Guide() - Re-equip loop: equips tools, runs until tools are cached, then stops
-- OPTIMIZED: No burst firing, instant re-equip
local function Guide()
	if not Active then return end
	
	local char = LocalPlayer.Character
	if not char then
		-- Wait for character if it doesn't exist yet
		char = LocalPlayer.CharacterAdded:Wait()
	end
	
	-- Wait for character parts - use Heartbeat for better responsiveness
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then
		hrp = char:WaitForChild("HumanoidRootPart", 5)
	end
	
	if hrp then
		bindCharacter(char)
		CurrentRoot = hrp
		
		-- Re-equip tools
		equipAllTools()
		cacheTools()
		
		-- Apply welds if we have tools
		if #ToolsCache > 0 then
			applyToolWelds()
		end
	end
end

-- Respawn handler - uses Guide() for re-equip on character add
track(LocalPlayer.CharacterAdded:Connect(function(char)
	-- Re-attach death listener to new character
	listenForDeath(char)
	
	-- Instantly re-equip tools on respawn if Use Tools is active
	if Active then
		-- Use task.defer for immediate but non-blocking execution
		task.defer(function()
			-- Small burst: equip tools and apply welds
			equipAllTools()
			cacheTools()
			if #ToolsCache > 0 then
				applyToolWelds()
			end
		end)
	end
end))

-- Main loop - OPTIMIZED: PreSimulation for maximum responsiveness
track(RunService.PreSimulation:Connect(function()
	if not Active then return end
	
	local now = os.clock()
	
	-- Max mode uses fixed 10 APS
	local effectiveAPS = Mode == "Max" and 10 or APS
	local pulseInterval = 1 / effectiveAPS
	
	if now - LastPulse < pulseInterval then return end
	LastPulse = now
	
	local char = CurrentCharacter
	if not char then return end
	
	-- Cache tools and check if new tools need welds
	cacheTools()
	
	-- Only apply welds if we have tools that aren't welded yet
	local needsWelds = false
	for _, tool in ipairs(ToolsCache) do
		if tool and tool.Parent and ToolWelds[tool] == nil then
			local handle = tool:FindFirstChild("Handle")
			if handle then
				needsWelds = true
				break
			end
		end
	end
	
	if needsWelds then
		applyToolWelds()
	end
	
	if #ToolsCache > 0 then
		damagePulse()
	end
end))

-- Character tool tracking for weld management
LocalPlayer.CharacterAdded:Connect(function(char)
	track(char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") and Active then
			cacheTools()
			task.defer(applyToolWelds)
		end
	end))
	
	track(char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			removeToolWeld(child)
		end
	end))
end)

-- Initial update
updateUI()

print("[TFL Use Tools] Loaded - Advanced tool activation system ready (APS: 10-1000, Tools: 1-10)")
print("[TFL Use Tools] Mode: Normal=Activate, Event=FightEvent, Max=Both (fixed 10APS)")

-- Expose Guide() globally so other scripts can call it
_G.TFL_Guide = Guide
