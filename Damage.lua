-- TFL Damage
-- Permanent HRP hitbox expansion for maximum hit detection - always active
-- No UI, pure logic

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Configuration
_G.TFL_HitboxSize = Vector3.new(12, 12, 12)
_G.TFL_HitboxParts = {"HumanoidRootPart", "UpperTorso", "Torso", "Head"}
_G.TFL_Disabled = false
_G.TFL_ToggleKey = Enum.KeyCode.H

-- Cache for hitboxes
local HitboxCache = {}

-- Create hitbox for a specific part
local function createHitbox(character, partName)
	if not character or not character.Parent then return nil end
	
	local targetPart = character:FindFirstChild(partName)
	if not targetPart or not targetPart:IsA("BasePart") then return nil end
	
	-- Create unique key using player name and part name
	local hitboxKey = character:GetDebugId() .. "_" .. partName
	
	-- Check if hitbox already exists
	local existing = HitboxCache[hitboxKey]
	if existing and existing.Parent then
		return existing
	end
	
	local hitbox = Instance.new("Part")
	hitbox.Name = "TFL_Hitbox_" .. partName
	hitbox.Size = _G.TFL_HitboxSize
	hitbox.Transparency = 0.6
	hitbox.BrickColor = BrickColor.new("Bright green")
	hitbox.Material = Enum.Material.Neon
	hitbox.CanCollide = false
	hitbox.Massless = true
	hitbox.Anchored = false
	hitbox.CanTouch = true
	hitbox.CanQuery = true
	hitbox.Parent = character
	
	-- Weld to target part for smooth following
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hitbox
	weld.Part1 = targetPart
	weld.Parent = hitbox
	
	-- Store in cache
	HitboxCache[hitboxKey] = hitbox
	
	return hitbox
end

-- Remove hitbox for a character+part
local function removeHitbox(character, partName)
	if not character then return end
	local hitboxKey = character:GetDebugId() .. "_" .. partName
	local hitbox = HitboxCache[hitboxKey]
	if hitbox and hitbox.Parent then
		hitbox:Destroy()
	end
	HitboxCache[hitboxKey] = nil
end

-- Clean up all hitboxes for a player
local function cleanupPlayer(player)
	if not player or not player.Character then return end
	
	for _, partName in ipairs(_G.TFL_HitboxParts) do
		removeHitbox(player.Character, partName)
	end
end

-- Apply hitboxes to all enemy players
local function applyHitboxes()
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer and player.Character and player.Character.Parent then
			local humanoid = player.Character:FindFirstChildOfClass("Humanoid")
			local rootPart = player.Character:FindFirstChild("HumanoidRootPart") or player.Character:FindFirstChild("Torso")
			
			if humanoid and humanoid.Health > 0 and rootPart then
				for _, partName in ipairs(_G.TFL_HitboxParts) do
					createHitbox(player.Character, partName)
				end
			else
				cleanupPlayer(player)
			end
		else
			cleanupPlayer(player)
		end
	end
end

-- Cleanup all when disabled
local function fullCleanup()
	for hitboxKey, hitbox in pairs(HitboxCache) do
		if hitbox and hitbox.Parent then
			hitbox:Destroy()
		end
	end
	table.clear(HitboxCache)
end

-- Character added handler
local function onCharacterAdded(player, character)
	if player == LocalPlayer then return end
	
	task.spawn(function()
		local success, result = pcall(function()
			return character:WaitForChild("HumanoidRootPart", 10) or character:WaitForChild("Torso", 10)
		end)
		
		if success and result then
			for _, partName in ipairs(_G.TFL_HitboxParts) do
				createHitbox(character, partName)
			end
		end
	end)
end

-- Character removing handler
local function onCharacterRemoving(player, character)
	cleanupPlayer(player)
end

-- Bind to all existing players
for _, player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		if player.Character then
			onCharacterAdded(player, player.Character)
		end
		player.CharacterAdded:Connect(function(char)
			onCharacterAdded(player, char)
		end)
		player.CharacterRemoving:Connect(function(char)
			onCharacterRemoving(player, char)
		end)
	end
end

-- Listen for new players
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(char)
		onCharacterAdded(player, char)
	end)
	player.CharacterRemoving:Connect(function(char)
		onCharacterRemoving(player, char)
	end)
end)

-- Main loop - pre-rendered for minimal lag
RunService.PreRender:Connect(function()
	if _G.TFL_Disabled then return end
	if not LocalPlayer.Character or not LocalPlayer.Character.Parent then return end
	applyHitboxes()
end)

-- Toggle keybind
UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == _G.TFL_ToggleKey then
		_G.TFL_Disabled = not _G.TFL_Disabled
		if _G.TFL_Disabled then
			fullCleanup()
		end
	end
end)

print("[TFL Damage] Loaded - Permanent hitboxes active (Welded)")