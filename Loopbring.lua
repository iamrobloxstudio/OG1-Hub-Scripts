-- TFL Loopbring V7
-- PERMANENT target looping - persists through respawn/rejoin
-- OPTIMIZED: Better performance, reduced allocations

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer

-- TFL Theme
local THEME = {
	Accent = Color3.fromRGB(0, 255, 0),
	Panel = Color3.fromRGB(10, 26, 10),
	Background = Color3.fromRGB(0, 0, 0),
	Button = Color3.fromRGB(0, 0, 0),
	Text = Color3.fromRGB(0, 255, 0),
	Muted = Color3.fromRGB(140, 180, 140),
	On = Color3.fromRGB(0, 40, 0)
}

local TWEEN_FAST = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Config
local RuntimeConfig = {
	Distance = 2,
	Mode = "INSTANT",
	ActiveInterval = 0.01,
	IdleInterval = 0.12,
	MaxSourceDistance = 5000,
	FormationSpacing = 0.7,
	ToggleKey = Enum.KeyCode.L
}

-- Cleanup
if _G.__TFLLoopbringCleanup then
	pcall(_G.__TFLLoopbringCleanup)
end

local alive = true
local globalConnections = {}
local playerData = {}
local selectedTargets = {}  -- Persists through respawn
local selectedOrder = {}
local gui

local function disconnectList(list)
	for _, conn in ipairs(list) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(list)
end

local function track(conn)
	table.insert(globalConnections, conn)
	return conn
end

local function cleanup()
	alive = false
	disconnectList(globalConnections)
	for _, data in pairs(playerData) do
		disconnectList(data.PlayerConnections)
		disconnectList(data.CharacterConnections)
	end
	table.clear(playerData)
	table.clear(selectedTargets)
	table.clear(selectedOrder)
	if gui then pcall(function() gui:Destroy() end) end
end

_G.__TFLLoopbringCleanup = cleanup

-- Local character
local localCharacter = nil
local localRoot = nil
local localEpoch = 0

local function bindLocalCharacter(character)
	localEpoch = localEpoch + 1
	local myEpoch = localEpoch
	localCharacter = character
	localRoot = nil
	
	if not character then return end
	
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		localRoot = root
	else
		task.defer(function()
			local waitedRoot = character:WaitForChild("HumanoidRootPart", 5)
			if alive and myEpoch == localEpoch then
				localRoot = waitedRoot
			end
		end)
	end
	
	character.ChildAdded:Connect(function(child)
		if alive and myEpoch == localEpoch and child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
			localRoot = child
		end
	end)
end

track(LocalPlayer.CharacterAdded:Connect(bindLocalCharacter))
track(LocalPlayer.CharacterRemoving:Connect(function(character)
	if character == localCharacter then
		localCharacter = nil
		localRoot = nil
	end
end))

if LocalPlayer.Character then
	bindLocalCharacter(LocalPlayer.Character)
end

-- Target data
local function createTargetData(player)
	return {
		Player = player,
		UserId = player.UserId,
		Name = player.Name,
		DisplayName = player.DisplayName,
		Character = nil,
		Root = nil,
		Humanoid = nil,
		Alive = false,
		Epoch = 0,
		PlayerConnections = {},
		CharacterConnections = {}
	}
end

local function getDataLabel(data)
	if not data then return "None" end
	if data.DisplayName and data.DisplayName ~= data.Name then
		return data.DisplayName .. " @" .. data.Name
	end
	return data.Name
end

local function refreshTargetParts(data)
	if not data or not data.Character then return end
	local character = data.Character
	data.Root = character:FindFirstChild("HumanoidRootPart")
	data.Humanoid = character:FindFirstChildOfClass("Humanoid")
	data.Alive = data.Root ~= nil and data.Humanoid ~= nil and data.Humanoid.Health > 0
end

local function bindTargetCharacter(data, character)
	data.Epoch = data.Epoch + 1
	local myEpoch = data.Epoch
	
	disconnectList(data.CharacterConnections)
	
	data.Character = character
	data.Root = nil
	data.Humanoid = nil
	data.Alive = false
	
	if not character then return end
	
	task.spawn(function()
		local root = character:FindFirstChild("HumanoidRootPart") or character:WaitForChild("HumanoidRootPart", 5)
		local humanoid = character:FindFirstChildOfClass("Humanoid") or character:WaitForChild("Humanoid", 5)
		
		if not alive or data.Epoch ~= myEpoch then return end
		if not root or not humanoid then return end
		
		data.Root = root
		data.Humanoid = humanoid
		data.Alive = humanoid.Health > 0
		
		data.CharacterConnections[#data.CharacterConnections + 1] = humanoid.HealthChanged:Connect(function(health)
			data.Alive = health > 0
			if health <= 0 then
				data.Root = nil
			end
		end)
		
		data.CharacterConnections[#data.CharacterConnections + 1] = humanoid.Died:Connect(function()
			data.Alive = false
			data.Root = nil
		end)
	end)
	
	character.ChildAdded:Connect(function(child)
		if child.Name == "HumanoidRootPart" and child:IsA("BasePart") then
			data.Root = child
			refreshTargetParts(data)
		elseif child:IsA("Humanoid") then
			data.Humanoid = child
			data.Alive = child.Health > 0
		end
	end)
	
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			data.Alive = false
			data.Root = nil
			data.Humanoid = nil
		end
	end)
end

local function bindPlayer(player)
	if player == LocalPlayer then return end
	
	local old = playerData[player.UserId]
	if old then
		disconnectList(old.PlayerConnections)
		disconnectList(old.CharacterConnections)
	end
	
	local data = createTargetData(player)
	playerData[player.UserId] = data
	
	-- Always rebind character when it changes (respawn)
	data.PlayerConnections = {}
	
	data.PlayerConnections[#data.PlayerConnections + 1] = player.CharacterAdded:Connect(function(character)
		bindTargetCharacter(data, character)
	end)
	
	data.PlayerConnections[#data.PlayerConnections + 1] = player.CharacterRemoving:Connect(function(character)
		if data.Character == character then
			data.Character = nil
			data.Root = nil
			data.Humanoid = nil
			data.Alive = false
		end
	end)
	
	-- If already selected, bind immediately
	if selectedTargets[player.UserId] then
		if player.Character then
			bindTargetCharacter(data, player.Character)
		end
	end
	
	return data
end

-- Selection - PERSISTENT
local function isSelected(userId)
	return selectedTargets[userId] == true
end

local function startBring(player)
	if not player or player == LocalPlayer then return end
	
	local data = playerData[player.UserId] or bindPlayer(player)
	if not data then return end
	
	if not selectedTargets[player.UserId] then
		selectedOrder[#selectedOrder + 1] = player.UserId
	end
	
	selectedTargets[player.UserId] = true
	
	-- Bind character immediately if exists
	if player.Character then
		bindTargetCharacter(data, player.Character)
	end
end

local function stopBring(playerOrUserId)
	local userId = typeof(playerOrUserId) == "Instance" and playerOrUserId.UserId or playerOrUserId
	selectedTargets[userId] = nil
	
	for i = #selectedOrder, 1, -1 do
		if selectedOrder[i] == userId then
			table.remove(selectedOrder, i)
		end
	end
end

local function toggleBring(player)
	if isSelected(player.UserId) then
		stopBring(player.UserId)
	else
		startBring(player)
	end
end

-- Get all selected targets (including dead/respawning)
local function getSelectedData()
	local list = {}
	
	for i = #selectedOrder, 1, -1 do
		local userId = selectedOrder[i]
		if selectedTargets[userId] then
			local data = playerData[userId]
			-- Keep in list even if dead - will loop when they respawn
			if data and data.Player and data.Player.Parent == Players then
				list[#list + 1] = data
			else
				selectedTargets[userId] = nil
				table.remove(selectedOrder, i)
			end
		else
			table.remove(selectedOrder, i)
		end
	end
	
	return list
end

-- Engine
local currentTargetData = nil

local function getLocalRoot()
	if localRoot and localRoot.Parent then
		return localRoot
	end
	
	local character = localCharacter or LocalPlayer.Character
	localRoot = character and character:FindFirstChild("HumanoidRootPart")
	return localRoot
end

local function moveTarget(data, index, total, myRoot)
	refreshTargetParts(data)
	
	local root = data.Root
	local humanoid = data.Humanoid
	
	-- Only move if alive and has root
	if not root or not humanoid or humanoid.Health <= 0 or not root.Parent then
		return false
	end
	
	if (root.Position - myRoot.Position).Magnitude > RuntimeConfig.MaxSourceDistance then
		return false
	end
	
	local forward = myRoot.CFrame.LookVector
	local right = myRoot.CFrame.RightVector
	local basePosition = myRoot.Position + (forward * RuntimeConfig.Distance)
	local offset = Vector3.zero
	
	if index > 1 then
		local side = index % 2 == 0 and 1 or -1
		local ring = math.ceil((index - 1) / 2)
		offset = right * side * RuntimeConfig.FormationSpacing * ring
	end
	
	pcall(function()
		root.AssemblyLinearVelocity = Vector3.zero
		root.AssemblyAngularVelocity = Vector3.zero
		root.CFrame = CFrame.new(basePosition + offset, myRoot.Position) * CFrame.Angles(0, math.rad(180), 0)
	end)
	
	return true
end

-- UI Helpers
local function tw(instance, props, info)
	return TweenService:Create(instance, info or TWEEN_FAST, props)
end

local function addRound(parent, radius)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius or 10)
	corner.Parent = parent
	return corner
end

local function addStroke(parent, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = THEME.Accent
	stroke.Thickness = thickness or 1
	stroke.Transparency = transparency or 0
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = parent
	return stroke
end

local function makeLabel(parent, text, size, pos, textSize, color)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = textSize or 12
	label.TextColor3 = color or THEME.Text
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = text
	label.ZIndex = 9999
	label.Parent = parent
	return label
end

local function makeButton(parent, text, width)
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, width, 1, 0)
	button.BackgroundColor3 = THEME.Button
	button.BorderSizePixel = 0
	button.AutoButtonColor = false
	button.Font = Enum.Font.Code
	button.TextSize = 13
	button.TextColor3 = THEME.Text
	button.Text = text
	button.ZIndex = 9999
	button.Parent = parent
	addRound(button, 8)
	addStroke(button, 1, 0.35)
	return button
end

-- UI
local oldGui = CoreGui:FindFirstChild("TFLLoopbring")
if oldGui then oldGui:Destroy() end

gui = Instance.new("ScreenGui")
gui.Name = "TFLLoopbring"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Global
gui.Parent = CoreGui

-- UIScale for mobile/PC scaling
local uiScale = Instance.new("UIScale")
uiScale.Parent = gui

-- Calculate scale based on screen size
local function updateScale()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local minDim = math.min(viewport.X, viewport.Y)
	
	if UserInputService.TouchEnabled then
		-- Mobile scaling - smaller UI for small screens
		local base = minDim / 720
		uiScale.Scale = math.clamp(base, 0.7, 0.95)
	else
		-- PC scaling - standard size
		local base = minDim / 1200
		uiScale.Scale = math.clamp(base, 0.9, 1.1)
	end
end

updateScale()
workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)
if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

local toggleButton = Instance.new("TextButton")
toggleButton.Name = "Toggle"
toggleButton.Size = UDim2.fromOffset(54, 54)
toggleButton.Position = UDim2.new(1, -74, 0, 128)
toggleButton.BackgroundColor3 = THEME.Panel
toggleButton.BorderSizePixel = 0
toggleButton.AutoButtonColor = false
toggleButton.Active = true
toggleButton.Draggable = true
toggleButton.Font = Enum.Font.Code
toggleButton.TextSize = 18
toggleButton.TextColor3 = THEME.Text
toggleButton.Text = "LB"
toggleButton.ZIndex = 9999
toggleButton.Parent = gui
addRound(toggleButton, 14)
addStroke(toggleButton, 1.5, 0)

local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.Size = UDim2.fromOffset(286, 386)
panel.Position = UDim2.new(1, -380, 0, 128)
panel.BackgroundColor3 = THEME.Panel
panel.BackgroundTransparency = 0.02
panel.BorderSizePixel = 0
panel.Active = true
panel.Draggable = true
panel.Visible = false
panel.ZIndex = 9998
panel.Parent = gui
addRound(panel, 12)
addStroke(panel, 1.5, 0)

local panelGlow = Instance.new("UIStroke")
panelGlow.Color = THEME.Accent
panelGlow.Thickness = 5
panelGlow.Transparency = 0.62
panelGlow.LineJoinMode = Enum.LineJoinMode.Round
panelGlow.Parent = panel

makeLabel(panel, "TFL LOOPBRING", UDim2.new(1, -20, 0, 24), UDim2.fromOffset(10, 8), 17, THEME.Text)

local statusLabel = makeLabel(panel, "Current: None", UDim2.new(1, -20, 0, 18), UDim2.fromOffset(10, 32), 12, THEME.Muted)

local statsFrame = Instance.new("Frame")
statsFrame.Name = "Stats"
statsFrame.Size = UDim2.new(1, -20, 0, 28)
statsFrame.Position = UDim2.fromOffset(10, 56)
statsFrame.BackgroundTransparency = 1
statsFrame.ZIndex = 9999
statsFrame.Parent = panel

local statsLayout = Instance.new("UIListLayout")
statsLayout.FillDirection = Enum.FillDirection.Horizontal
statsLayout.Padding = UDim.new(0, 6)
statsLayout.SortOrder = Enum.SortOrder.LayoutOrder
statsLayout.Parent = statsFrame

local function makeStat(name, width)
	local stat = Instance.new("TextLabel")
	stat.Name = name
	stat.Size = UDim2.new(0, width, 1, 0)
	stat.BackgroundColor3 = THEME.Background
	stat.BackgroundTransparency = 0.12
	stat.BorderSizePixel = 0
	stat.Font = Enum.Font.Code
	stat.TextSize = 11
	stat.TextColor3 = THEME.Muted
	stat.TextXAlignment = Enum.TextXAlignment.Center
	stat.ZIndex = 9999
	stat.Parent = statsFrame
	addRound(stat, 7)
	addStroke(stat, 1, 0.45)
	return stat
end

local targetCountLabel = makeStat("Targets", 78)
local distanceStatLabel = makeStat("Distance", 84)
local modeStatLabel = makeStat("Mode", 90)

local controlsFrame = Instance.new("Frame")
controlsFrame.Name = "Controls"
controlsFrame.Size = UDim2.new(1, -20, 0, 30)
controlsFrame.Position = UDim2.fromOffset(10, 92)
controlsFrame.BackgroundTransparency = 1
controlsFrame.ZIndex = 9999
controlsFrame.Parent = panel

local controlsLayout = Instance.new("UIListLayout")
controlsLayout.FillDirection = Enum.FillDirection.Horizontal
controlsLayout.Padding = UDim.new(0, 6)
controlsLayout.SortOrder = Enum.SortOrder.LayoutOrder
controlsLayout.Parent = controlsFrame

local minusButton = makeButton(controlsFrame, "- DIST", 76)
local plusButton = makeButton(controlsFrame, "+ DIST", 76)
local modeButton = makeButton(controlsFrame, "MODE INSTANT", 112)

local searchBox = Instance.new("TextBox")
searchBox.Name = "Search"
searchBox.Size = UDim2.new(1, -20, 0, 30)
searchBox.Position = UDim2.fromOffset(10, 132)
searchBox.BackgroundColor3 = THEME.Background
searchBox.BackgroundTransparency = 0.08
searchBox.BorderSizePixel = 0
searchBox.ClearTextOnFocus = false
searchBox.PlaceholderText = "Search players..."
searchBox.Text = ""
searchBox.Font = Enum.Font.Code
searchBox.TextSize = 13
searchBox.TextColor3 = THEME.Text
searchBox.PlaceholderColor3 = THEME.Muted
searchBox.ZIndex = 9999
searchBox.Parent = panel
addRound(searchBox, 8)
addStroke(searchBox, 1, 0.45)

local scroll = Instance.new("ScrollingFrame")
scroll.Name = "Players"
scroll.Size = UDim2.new(1, -20, 1, -176)
scroll.Position = UDim2.fromOffset(10, 170)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 5
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ZIndex = 9999
scroll.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 6)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = scroll

-- Update stats
local function updateStats()
	local selected = getSelectedData()
	local currentLabel = currentTargetData and getDataLabel(currentTargetData) or "None"
	
	if #currentLabel > 28 then
		currentLabel = currentLabel:sub(1, 27) .. "."
	end
	
	statusLabel.Text = "Current: " .. currentLabel
	targetCountLabel.Text = "Targets " .. tostring(#selected)
	distanceStatLabel.Text = "Dist " .. tostring(RuntimeConfig.Distance)
	modeStatLabel.Text = RuntimeConfig.Mode
	modeButton.Text = "MODE " .. RuntimeConfig.Mode
end

-- Refresh list
local refreshList
local listRefreshQueued = false

local function queueRefreshList()
	if listRefreshQueued then return end
	listRefreshQueued = true
	
	task.defer(function()
		listRefreshQueued = false
		if refreshList then
			refreshList()
		end
	end)
end

refreshList = function()
	if not scroll or not scroll.Parent then return end
	
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		elseif not child:IsA("UIListLayout") then
			child:Destroy()
		end
	end
	
	local query = searchBox.Text:lower()
	
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			local data = playerData[player.UserId] or bindPlayer(player)
			local label = getDataLabel(data)
			local searchable = (player.Name .. " " .. player.DisplayName):lower()
			
			if query == "" or searchable:find(query, 1, true) then
				local active = isSelected(player.UserId)
				local row = Instance.new("TextButton")
				row.Name = player.Name
				row.Size = UDim2.new(1, -2, 0, 38)
				row.BackgroundColor3 = active and THEME.On or THEME.Background
				row.BackgroundTransparency = active and 0 or 0.1
				row.BorderSizePixel = 0
				row.AutoButtonColor = false
				row.Font = Enum.Font.Code
				row.TextSize = 13
				row.TextColor3 = active and THEME.Text or THEME.Muted
				row.TextXAlignment = Enum.TextXAlignment.Left
				row.Text = "  " .. label
				row.ZIndex = 9999
				row.Parent = scroll
				addRound(row, 8)
				addStroke(row, 1, active and 0.18 or 0.55)
				
				row.MouseButton1Click:Connect(function()
					toggleBring(player)
					refreshList()
					updateStats()
				end)
			end
		end
	end
	
	updateStats()
end

-- Main loop - OPTIMIZED: PreSimulation for better timing
RunService.PreSimulation:Connect(function()
	if not alive then return end
	
	local myRoot = getLocalRoot()
	if not myRoot then return end
	
	local selected = getSelectedData()
	if #selected == 0 then return end
	
	for index, data in ipairs(selected) do
		if moveTarget(data, index, #selected, myRoot) then
			if not currentTargetData then
				currentTargetData = data
			end
		end
	end
end)

-- UI Events
track(toggleButton.MouseButton1Click:Connect(function()
	panel.Visible = not panel.Visible
	panelGlow.Transparency = panel.Visible and 0.45 or 0.62
	refreshList()
end))

track(minusButton.MouseButton1Click:Connect(function()
	RuntimeConfig.Distance = math.max(1, RuntimeConfig.Distance - 1)
	updateStats()
end))

track(plusButton.MouseButton1Click:Connect(function()
	RuntimeConfig.Distance = math.min(25, RuntimeConfig.Distance + 1)
	updateStats()
end))

track(modeButton.MouseButton1Click:Connect(function()
	RuntimeConfig.Mode = "INSTANT"
	RuntimeConfig.ActiveInterval = 0.01
	RuntimeConfig.FormationSpacing = 0.7
	updateStats()
end))

track(searchBox:GetPropertyChangedSignal("Text"):Connect(queueRefreshList))

track(UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == RuntimeConfig.ToggleKey then
		panel.Visible = not panel.Visible
		refreshList()
	end
end))

-- Player events - bind all players on start
for _, player in ipairs(Players:GetPlayers()) do
	bindPlayer(player)
end

track(Players.PlayerAdded:Connect(function(player)
	bindPlayer(player)
	-- If already selected, they will be looped automatically
	queueRefreshList()
end))

track(Players.PlayerRemoving:Connect(function(player)
	-- Remove from selected if they leave
	if selectedTargets[player.UserId] then
		selectedTargets[player.UserId] = nil
		for i = #selectedOrder, 1, -1 do
			if selectedOrder[i] == player.UserId then
				table.remove(selectedOrder, i)
			end
		end
	end
	
	local data = playerData[player.UserId]
	if data then
		disconnectList(data.PlayerConnections)
		disconnectList(data.CharacterConnections)
	end
	
	playerData[player.UserId] = nil
	queueRefreshList()
end))

-- API
_G.TFLLoopbring = {
	Config = RuntimeConfig,
	Start = function(playerOrName)
		local player = typeof(playerOrName) == "Instance" and playerOrName or Players:FindFirstChild(tostring(playerOrName))
		if player then
			startBring(player)
			queueRefreshList()
		end
	end,
	Stop = function(playerOrName)
		local player = typeof(playerOrName) == "Instance" and playerOrName or Players:FindFirstChild(tostring(playerOrName))
		if player then
			stopBring(player.UserId)
		else
			for userId, data in pairs(playerData) do
				if data.Name == tostring(playerOrName) then
					stopBring(userId)
				end
			end
		end
		queueRefreshList()
	end,
	Clear = function()
		table.clear(selectedTargets)
		table.clear(selectedOrder)
		queueRefreshList()
	end,
	GetCurrentTarget = function()
		return currentTargetData and currentTargetData.Player or nil
	end,
	GetTargets = function()
		local targets = {}
		for _, data in ipairs(getSelectedData()) do
			targets[#targets + 1] = data.Player
		end
		return targets
	end
}

track(gui.Destroying:Connect(function()
	if alive then
		cleanup()
	end
end))

refreshList()
updateStats()

print("[TFLLoopbring] V7 Loaded - PERMANENT target looping (optimized)")
