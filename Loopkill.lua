-- TFL Loopkill
-- Targeted aura system for killing selected players from anywhere
-- UI with player selection panel with mobile/PC scaling
-- OPTIMIZED: PreSimulation timing, connection management

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- TFL Theme (Black/Green Hacker Aesthetic)
local THEME = {
	Background = Color3.fromRGB(0, 0, 0),
	Panel = Color3.fromRGB(0, 10, 0),
	Button = Color3.fromRGB(0, 20, 0),
	Text = Color3.fromRGB(0, 255, 0),
	On = Color3.fromRGB(0, 40, 0),
	Accent = Color3.fromRGB(0, 255, 0),
}

-- Configuration
local FIRE_BURST = 2
local FIRE_RATE = 1/30

-- State
local SelectedTargets = {}
local TargetOrder = {}
local Active = false

-- Cleanup
if _G.__TFLLoopkillCleanup then
	pcall(_G.__TFLLoopkillCleanup)
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
	table.clear(SelectedTargets)
	table.clear(TargetOrder)
end

_G.__TFLLoopkillCleanup = cleanup

-- Mobile/PC scaling function
local function updateScale()
	if not workspace.CurrentCamera then return end
	local viewport = workspace.CurrentCamera.ViewportSize
	local minDim = math.min(viewport.X, viewport.Y)
	
	if game:GetService("UserInputService").TouchEnabled then
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

local function getTouchPart(tool)
	for _, obj in ipairs(tool:GetDescendants()) do
		if obj:IsA("TouchTransmitter") and obj.Parent and obj.Parent:IsA("BasePart") then
			return obj.Parent
		end
	end
	return nil
end

-- Attack function
local function Attack(tool, targetChar)
	if not tool or not tool:IsDescendantOf(workspace) then return end
	
	local touchPart = getTouchPart(tool)
	
	-- Activate tool
	pcall(tool.Activate, tool)
	
	-- Try FightEvent first
	local fightEvent = tool:FindFirstChild("FightEvent", true)
	if fightEvent and fightEvent:IsA("RemoteEvent") then
		pcall(function()
			for _ = 1, FIRE_BURST do
				fightEvent:FireServer()
			end
		end)
	end
	
	-- Touch all hittable parts
	if touchPart then
		for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "Torso", "Head"}) do
			local part = targetChar:FindFirstChild(name)
			if part and part:IsA("BasePart") then
				pcall(firetouchinterest, touchPart, part, 0)
				pcall(firetouchinterest, touchPart, part, 1)
			end
		end
	end
end

-- UI Functions
local ScreenGui, PlayerFrame

local function createUI()
	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "TFLLoopkill"
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
	
	-- Toggle button
	local toggleBtn = Instance.new("TextButton")
	toggleBtn.Name = "ToggleButton"
	toggleBtn.Size = UDim2.fromOffset(96, 34)
	toggleBtn.Position = UDim2.fromScale(1, 0)
	toggleBtn.AnchorPoint = Vector2.new(1, 0)
	toggleBtn.BackgroundColor3 = THEME.Button
	toggleBtn.TextColor3 = THEME.Text
	toggleBtn.Font = Enum.Font.GothamBold
	toggleBtn.TextSize = 13
	toggleBtn.Text = "TARGET AURA"
	toggleBtn.AutoButtonColor = false
	toggleBtn.Parent = screenGui
	Instance.new("UICorner", toggleBtn).CornerRadius = UDim.new(0, 12)
	Instance.new("UIStroke", toggleBtn).Color = THEME.Accent
	
	-- Player list panel
	local playerFrame = Instance.new("Frame")
	playerFrame.Name = "PlayerList"
	playerFrame.Size = UDim2.fromOffset(180, 300)
	playerFrame.AnchorPoint = Vector2.new(1, 0)
	playerFrame.Position = UDim2.fromScale(1, 0) + UDim2.fromOffset(0, 40)
	playerFrame.Visible = false
	playerFrame.BackgroundColor3 = THEME.Panel
	playerFrame.BackgroundTransparency = 0.05
	playerFrame.Parent = screenGui
	Instance.new("UICorner", playerFrame).CornerRadius = UDim.new(0, 16)
	Instance.new("UIStroke", playerFrame).Color = THEME.Accent
	
	local layout = Instance.new("UIListLayout", playerFrame)
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	
	return screenGui, playerFrame
end

-- Create player button
local function createPlayerButton(plr, parent)
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(1, -12, 0, 26)
	btn.Text = plr.Name
	btn.Font = Enum.Font.Gotham
	btn.TextSize = 13
	btn.TextXAlignment = Enum.TextXAlignment.Left
	btn.BackgroundColor3 = THEME.Button
	btn.TextColor3 = THEME.Text
	btn.AutoButtonColor = false
	btn.Parent = parent
	
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 10)
	
	local stroke = Instance.new("UIStroke", btn)
	stroke.Thickness = 1
	stroke.Color = THEME.Accent
	stroke.Transparency = 0.45
	
	-- Selection state
	if SelectedTargets[plr.UserId] then
		btn.BackgroundColor3 = THEME.On
		stroke.Color = Color3.fromRGB(90, 255, 90)
	end
	
	btn.MouseButton1Click:Connect(function()
		if SelectedTargets[plr.UserId] then
			SelectedTargets[plr.UserId] = nil
			for i = #TargetOrder, 1, -1 do
				if TargetOrder[i] == plr.UserId then
					table.remove(TargetOrder, i)
				end
			end
			btn.BackgroundColor3 = THEME.Button
			stroke.Color = THEME.Accent
		else
			SelectedTargets[plr.UserId] = true
			table.insert(TargetOrder, plr.UserId)
			btn.BackgroundColor3 = THEME.On
			stroke.Color = Color3.fromRGB(90, 255, 90)
		end
	end)
end

-- Update player list
local function updatePlayerList()
	for _, child in ipairs(PlayerFrame:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		elseif not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			createPlayerButton(plr, PlayerFrame)
		end
	end
end

-- Get valid targets
local function getTargets()
	local targets = {}
	for _, userId in ipairs(TargetOrder) do
		if SelectedTargets[userId] then
			local plr = Players:GetPlayerByUserId(userId)
			if plr and plr.Character then
				local hum = plr.Character:FindFirstChildOfClass("Humanoid")
				local root = getHRP(plr.Character)
				if hum and hum.Health > 0 and root then
					table.insert(targets, plr.Character)
				end
			end
		end
	end
	return targets
end

-- Create UI
ScreenGui, PlayerFrame = createUI()

-- UI Events - toggle Active state
local ToggleButton = ScreenGui:WaitForChild("ToggleButton", 5)
if ToggleButton then
	ToggleButton.MouseButton1Click:Connect(function()
		Active = not Active
		PlayerFrame.Visible = Active
		if Active then
			updatePlayerList()
		end
	end)
end

-- Main loop - OPTIMIZED: PreSimulation for better timing
local LastFire = 0

track(RunService.PreSimulation:Connect(function()
	if not Active then return end
	if #TargetOrder == 0 then return end
	
	local now = os.clock()
	if now - LastFire < FIRE_RATE then return end
	LastFire = now
	
	local char = LocalPlayer.Character
	if not char then return end
	
	local targets = getTargets()
	if #targets == 0 then return end
	
	-- Attack with all tools
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			for _, targetChar in ipairs(targets) do
				Attack(tool, targetChar)
			end
		end
	end
end))

print("[TFL Loopkill] Loaded - Target aura system ready (optimized)")
