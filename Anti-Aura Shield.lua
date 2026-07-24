-- TFL Anti-Aura Shield
-- Reflects incoming hits and pushes attackers away - defensive system
-- Toggle with 'J' key
-- OPTIMIZED: Connection management, PreSimulation timing

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Configuration
local SHIELD_RANGE = 25
local PUSH_FORCE = 80
local REFLECT_BURST = 2

-- State
local Active = false
local Connections = {}

-- Helper functions
local function getHRP(char)
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

-- Cleanup
if _G.__TFLAntiAuraCleanup then
	pcall(_G.__TFLAntiAuraCleanup)
end

local function cleanup()
	Active = false
	for _, conn in ipairs(Connections) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(Connections)
end

_G.__TFLAntiAuraCleanup = cleanup

-- Reflect hit back to attacker
local function reflectHit(attackerPart, toolPart)
	if not attackerPart or not toolPart then return end
	
	local attackerChar = attackerPart.Parent
	if not attackerChar then return end
	
	local attackerHRP = getHRP(attackerChar)
	if not attackerHRP then return end
	
	-- Reflect using firetouchinterest
	pcall(function()
		for _ = 1, REFLECT_BURST do
			firetouchinterest(toolPart, attackerHRP, 0)
			firetouchinterest(toolPart, attackerHRP, 1)
		end
	end)
end

-- Push attacker away
local function pushAttacker(attackerChar)
	if not attackerChar then return end
	
	local hrp = getHRP(attackerChar)
	if not hrp then return end
	
	pcall(function()
		hrp.AssemblyLinearVelocity = (hrp.Position - getHRP(LocalPlayer.Character).Position).Unit * PUSH_FORCE
	end)
end

-- Core shield loop - OPTIMIZED: PreSimulation for better timing
table.insert(Connections, RunService.PreSimulation:Connect(function()
	if not Active then return end
	
	local char = LocalPlayer.Character
	if not char then return end
	
	local myHRP = getHRP(char)
	if not myHRP then return end
	
	-- Check all players in range
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local targetChar = plr.Character
			if targetChar then
				local targetHRP = getHRP(targetChar)
				if targetHRP then
					local dist = (myHRP.Position - targetHRP.Position).Magnitude
					
					if dist <= SHIELD_RANGE then
						-- Check for their tools touching us
						for _, tool in ipairs(targetChar:GetChildren()) do
							if tool:IsA("Tool") then
								-- Push their tools away
								for _, part in ipairs(tool:GetDescendants()) do
									if part:IsA("BasePart") then
										pcall(function()
											part.AssemblyLinearVelocity = (part.Position - myHRP.Position).Unit * -PUSH_FORCE
										end)
									end
								end
								
								-- Reflect back at their HRP
								local handle = tool:FindFirstChild("Handle") or tool.PrimaryPart
								if handle and handle:IsA("BasePart") then
									reflectHit(targetHRP, handle)
								else
									-- Try to find any part
									for _, part in ipairs(tool:GetDescendants()) do
										if part:IsA("BasePart") then
											reflectHit(targetHRP, part)
											break
										end
									end
								end
							end
						end
						
						-- Push attacker away
						pushAttacker(targetChar)
					end
				end
			end
		end
	end
end))

-- Toggle keybind
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.J then
		print("Active")
		Active = not Active
	end
end))

print("[TFL Anti-Aura Shield] Loaded - Defensive system ready (OFF by default, optimized)")
