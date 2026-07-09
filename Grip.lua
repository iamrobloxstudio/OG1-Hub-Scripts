-- TFL Grip
-- Tool grip adjustment and floating tool logic with green/black theme

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

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

-- Follow / aura range settings
local auraRange = 15

-- Check if the player is dead
local function IsPlayerDead()
	local char = player.Character
	if not char then return false end
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	return humanoid and humanoid.Health <= 0
end

-- Remove gravity from the tools so they float
local function SetToolGravityToZero()
	if not player.Character then return end
	for _, tool in ipairs(player.Character:GetChildren()) do
		if tool:IsA("Tool") then
			local handle = tool:FindFirstChild("Handle")
			if handle then
				local bodyVelocity = handle:FindFirstChildOfClass("BodyVelocity")
				if not bodyVelocity then
					bodyVelocity = Instance.new("BodyVelocity")
					bodyVelocity.MaxForce = Vector3.new(400000, 400000, 400000)
					bodyVelocity.Velocity = Vector3.new(0, 0, 0)
					bodyVelocity.Parent = handle
				end
			end
		end
	end
end

-- Restore normal gravity
local function RestoreToolGravity()
	if not player.Character then return end
	for _, tool in ipairs(player.Character:GetChildren()) do
		if tool:IsA("Tool") then
			local handle = tool:FindFirstChild("Handle")
			if handle then
				local bodyVelocity = handle:FindFirstChildOfClass("BodyVelocity")
				if bodyVelocity then
					bodyVelocity:Destroy()
				end
			end
		end
	end
end

-- Find the closest player within range
local function GetClosestPlayer()
	local closestPlayer = nil
	local closestDistance = auraRange
	local myChar = player.Character
	
	for _, otherPlayer in ipairs(Players:GetPlayers()) do
		local char = otherPlayer.Character
		if char and char ~= myChar then
			local humanoid = char:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				local distance = (char.HumanoidRootPart.Position - myChar.HumanoidRootPart.Position).Magnitude
				if distance < closestDistance then
					closestDistance = distance
					closestPlayer = char
				end
			end
		end
	end
	
	return closestPlayer
end

-- Make tools follow the nearest player
local function FollowPlayerWithTool(tool, char)
	local handle = tool:FindFirstChild("Handle")
	if handle and char then
		local targetPos = char:WaitForChild("HumanoidRootPart").Position
		local bodyPosition = handle:FindFirstChild("BodyPosition")
		if not bodyPosition then
			bodyPosition = Instance.new("BodyPosition")
			bodyPosition.MaxForce = Vector3.new(400000, 400000, 400000)
			bodyPosition.D = 10
			bodyPosition.Parent = handle
		end
		bodyPosition.Position = targetPos
	elseif handle then
		local bodyPosition = handle:FindFirstChild("BodyPosition")
		if not bodyPosition then
			bodyPosition = Instance.new("BodyPosition")
			bodyPosition.MaxForce = Vector3.new(400000, 400000, 400000)
			bodyPosition.D = 10
			bodyPosition.Parent = handle
		end
		bodyPosition.Position = handle.Position
	end
end

-- Adjust a tool's grip position
local function adjustToolGrip(tool)
	if tool:IsA("Tool") then
		tool.GripPos = Vector3.new(0, 0, 0)
	end
end

-- Adjust grip for all tools
local function adjustAllToolGrips()
	local character = player.Character or player.CharacterAdded:Wait()
	
	for _, tool in pairs(character:GetChildren()) do
		adjustToolGrip(tool)
	end
	
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			adjustToolGrip(child)
		end
	end)
end

-- Apply grip adjustments when the character spawns
player.CharacterAdded:Connect(function(character)
	character:WaitForChild("HumanoidRootPart")
	wait(1)
	adjustAllToolGrips()
end)

-- Adjust grip if character already exists
if player.Character then
	adjustAllToolGrips()
end

-- Adjust grip when tools move from backpack -> character
player.Backpack.ChildAdded:Connect(function(tool)
	if tool:IsA("Tool") then
		tool.AncestryChanged:Connect(function()
			if tool.Parent == player.Character then
				adjustToolGrip(tool)
			end
		end)
	end
end)

-- Main loop
RunService.Heartbeat:Connect(function()
	if IsPlayerDead() then
		SetToolGravityToZero()
		
		for _, tool in ipairs(player.Character:GetChildren()) do
			if tool:IsA("Tool") then
				local closestPlayer = GetClosestPlayer()
				FollowPlayerWithTool(tool, closestPlayer)
			end
		end
	else
		RestoreToolGravity()
	end
end)

print("TFL Grip Loaded")