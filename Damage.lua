-- ⚔️ Hitbox Expander V3 (Optimized)
-- OPTIMIZED: Reduced CPU usage, smart caching, no per-frame player iteration

_G.HitboxSize = 12
_G.Enabled = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Cache for modified parts to avoid redundant work
local modified = {}
local playerCache = {}
local cacheDirty = true

-- Apply hitbox to a player - OPTIMIZED
local function applyHitbox(player)
	if player == LocalPlayer then return end
	if not player.Character then return end
	
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	-- Check if already modified
	if modified[hrp] then return end
	modified[hrp] = true
	
	pcall(function()
		hrp.Size = Vector3.new(_G.HitboxSize, _G.HitboxSize, _G.HitboxSize)
		hrp.Transparency = 0.7
		hrp.BrickColor = Color3.fromRGB(0, 255, 0)
		hrp.Material = Enum.Material.ForceField
		hrp.CanCollide = false
		hrp.CanQuery = true
		hrp.CanTouch = true
		
		local box = Instance.new("SelectionBox")
		box.Name = "HitboxVisual"
		box.Adornee = hrp
		box.LineThickness = 1
		box.Color3 = Color3.fromRGB(0, 255, 0)
		box.SurfaceTransparency = 0.7
		box.Parent = hrp
	end)
end

-- Update player cache when players change
local function updatePlayerCache()
	table.clear(playerCache)
	for _, player in ipairs(Players:GetPlayers()) do
		if player ~= LocalPlayer then
			table.insert(playerCache, player)
		end
	end
	cacheDirty = false
end

-- Player events
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		-- Delay to ensure character is loaded
		task.defer(function()
			applyHitbox(player)
		end)
	end)
	cacheDirty = true
end)

Players.PlayerRemoving:Connect(function()
	cacheDirty = true
end)

-- Initialize cache
updatePlayerCache()

-- Main loop - OPTIMIZED: Only run when enabled, use cached player list
RunService.Heartbeat:Connect(function()
	if not _G.Enabled then return end
	
	-- Update cache if needed
	if cacheDirty then
		updatePlayerCache()
	end
	
	-- Apply hitboxes to cached players
	for _, player in ipairs(playerCache) do
		applyHitbox(player)
	end
end)

print("⚔️ Optimized Hitbox Expander V3 Loaded")
