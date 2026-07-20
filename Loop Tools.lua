-- TFL Loop Tools
-- Bring tools to a single selected player for maximum hit registration
-- Black/Green hacker theme UI with mobile/PC scaling
-- OPTIMIZED: Removed delays, improved responsiveness

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

-- Configuration
local FollowOffset = Vector3.new(0, 0.6, 0)
local AvoidCollisionOffset = Vector3.new(0, 0, 0.5)

-- State
local TargetPlayerName = nil
local ToolPartsCache = {}

-- Cleanup
if _G.__TFLLoopToolsCleanup then
	pcall(_G.__TFLLoopToolsCleanup)
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
	table.clear(ToolPartsCache)
	TargetPlayerName = nil
end

_G.__TFLLoopToolsCleanup = cleanup

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

-- Get tool part
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

-- Update tool cache - OPTIMIZED: No delays, immediate update
local function updateToolCache()
	table.clear(ToolPartsCache)
	if not LocalPlayer.Character then return end
	for _, tool in ipairs(LocalPlayer.Character:GetChildren()) do
		if tool:IsA("Tool") then
			local part = getToolPart(tool)
			if part then
				table.insert(ToolPartsCache, part)
				-- Set physics for better hit registration
				part.CanCollide = false
				part.Massless = true
			end
		end
	end
end

-- UI Functions
local SelectedPlayerLabel

local function createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TFLLoopTools"
	screenGui.ResetOnSpawn = false
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
	
	-- Main panel
	local panel = Instance.new("Frame")
	panel.Name = "Main"
	panel.Size = UDim2.new(0, 180, 0, 80)
	panel.Position = UDim2.new(1, -50, 0, 100)
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.BackgroundColor3 = THEME.Panel
	panel.BackgroundTransparency = 0.08
	panel.Parent = screenGui
	Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 12)
	Instance.new("UIStroke", panel).Color = THEME.Accent
	
	-- Toggle button
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "Toggle"
	toggleBtn.Size = UDim2.new(1, -20, 0, 30)
	toggleBtn.Position = UDim2.fromOffset(10, 10)
	toggleBtn.BackgroundColor3 = THEME.Button
	toggleBtn.TextColor3 = THEME.Text
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextSize = 14
	toggleBtn.Text = "Loop Tools: OFF"
	toggleBtn.AutoButtonColor = false
	toggleBtn.Parent = panel
	Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 8)
	Instance.new("UIStroke", toggleBtn).Color = THEME.Accent
	
	-- Selected player label
	local label = Instance.new("TextLabel")
	label.Name = "SelectedLabel"
	label.Size = UDim2.new(1, -20, 0, 20)
	label.Position = UDim2.fromOffset(10, 45)
	label.BackgroundTransparency = 1
	label.TextColor3 = THEME.Text
	label.Font = Enum.Font.Gotham
	label.TextSize = 12
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = "Target: None"
	label.Parent = panel
	SelectedPlayerLabel = label
	
	return screenGui, toggleBtn
end

-- Create UI
local ScreenGui, ToggleButton = createUI()

-- Set target and update label
local function setTarget(plr)
	TargetPlayerName = plr and plr.Name or nil
	if SelectedPlayerLabel then
		SelectedPlayerLabel.Text = TargetPlayerName and "Target: " .. TargetPlayerName or "Target: None"
	end
end

-- Move tools to target
local function moveTools()
	if not TargetPlayerName then return end
	if not LocalPlayer.Character then return end
	
	local targetPlr = Players:FindFirstChild(TargetPlayerName)
	if not targetPlr or not targetPlr.Character then return end
	
	local torso = targetPlr.Character:FindFirstChild("UpperTorso") or 
				  targetPlr.Character:FindFirstChild("Torso")
	if not torso then return end
	
	for _, part in ipairs(ToolPartsCache) do
		if part and part.Parent then
			part.Position = torso.Position + FollowOffset + AvoidCollisionOffset
			-- Continuous firetouch for hit registration
			pcall(firetouchinterest, part, torso, 0)
			pcall(firetouchinterest, part, torso, 1)
		end
	end
end

-- UI Events
ToggleButton.MouseButton1Click:Connect(function()
	-- Cycle through players
	if not TargetPlayerName then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				setTarget(plr)
				break
			end
		end
	else
		-- Cycle to next player
		local foundCurrent = false
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				if foundCurrent then
					setTarget(plr)
					return
				elseif plr.Name == TargetPlayerName then
					foundCurrent = true
				end
			end
		end
		-- Wrap around
		setTarget(nil)
	end
end)

-- Character bind - OPTIMIZED: No delays
track(LocalPlayer.CharacterAdded:Connect(function()
	updateToolCache()
end))

track(LocalPlayer.CharacterRemoving:Connect(function()
	table.clear(ToolPartsCache)
end))

-- Character tools bind - OPTIMIZED: Use task.defer instead of task.wait
LocalPlayer.CharacterAdded:Connect(function(char)
	if not char then return end
	track(char.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(updateToolCache)
		end
	end))
	track(char.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			task.defer(updateToolCache)
		end
	end))
end)

-- Main loop - OPTIMIZED: PreSimulation for better timing
track(RunService.PreSimulation:Connect(function()
	if TargetPlayerName then
		moveTools()
	end
end))

-- Initial cache
updateToolCache()

print("[TFL Loop Tools] Loaded - Tool bringer system ready (optimized)")
