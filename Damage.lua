-- ⚔️ Hitbox Expander V2 (Optimized)

_G.HitboxSize = 12
_G.Enabled = true

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local modified = {}

local function applyHitbox(player)
	if player == LocalPlayer then return end
	if not player.Character then return end
	
	local hrp = player.Character:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	if modified[hrp] then return end
	modified[hrp] = true
	
	pcall(function()
		hrp.Size = Vector3.new(_G.HitboxSize, _G.HitboxSize, _G.HitboxSize)
		hrp.Transparency = 0.7
		hrp.BrickColor = Color3.fromRGB(0,255,0)
		hrp.Material = Enum.Material.ForceField
		hrp.CanCollide = false
		hrp.CanQuery = true
		hrp.canTouch = true
		
		local box = Instance.new("SelectionBox")
		box.Name = "HitboxVisual"
		box.Adornee = hrp
		box.LineThickness = 1
		box.Color3 = Color3.fromRGB(0,255,0)
		box.SurfaceTransparency = 0.7
		box.Parent = hrp
		box.CanColide = false
		box.CanQuery = true
		box.CanTouch = true
	end)
end

local function updatePlayers()
	for _,player in ipairs(Players:GetPlayers()) do
		applyHitbox(player)
	end
end

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.wait(0.5)
		applyHitbox(player)
	end)
end)

for _,player in ipairs(Players:GetPlayers()) do
	if player ~= LocalPlayer then
		player.CharacterAdded:Connect(function()
			task.wait(0.5)
			applyHitbox(player)
		end)
	end
end

RunService.Heartbeat:Connect(function()
	if not _G.Enabled then return end
	updatePlayers()
end)

print("⚔️ Optimized Hitbox Expander Loaded")
