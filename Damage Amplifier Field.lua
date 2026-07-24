-- TFL Damage Amplifier Field
-- Offensive field that boosts damage while disrupting enemies
-- Toggle with 'K' key
-- OPTIMIZED: PreSimulation timing, connection management

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer

-- Configuration
local FIELD_RANGE = 20
local PUSH_FORCE = 60

-- State
local Active = false
local Connections = {}

-- Helper functions
local function getHRP(char)
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

-- Cleanup
if _G.__TFLDamageAmplifierCleanup then
	pcall(_G.__TFLDamageAmplifierCleanup)
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

_G.__TFLDamageAmplifierCleanup = cleanup

-- Main field loop - OPTIMIZED: PreSimulation for better timing
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
					
					if dist <= FIELD_RANGE then
						-- Push their tools away (reduces their hit registration)
						for _, tool in ipairs(targetChar:GetChildren()) do
							if tool:IsA("Tool") then
								for _, part in ipairs(tool:GetDescendants()) do
									if part:IsA("BasePart") then
										pcall(function()
											part.AssemblyLinearVelocity = (part.Position - myHRP.Position).Unit * -PUSH_FORCE
										end)
									end
								end
							end
						end
						
						-- Boost our tools
						for _, tool in ipairs(char:GetChildren()) do
							if tool:IsA("Tool") then
								-- Try FightEvent for faster activation
								local fightEvent = tool:FindFirstChild("FightEvent", true)
								if fightEvent and fightEvent:IsA("RemoteEvent") then
									pcall(function()
										fightEvent:FireServer()
									end)
								else
									pcall(tool.Activate, tool)
								end
							end
						end
					end
				end
			end
		end
	end
end))

-- Toggle keybind
table.insert(Connections, UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.K then
		print("Active")
		Active = not Active
	end
end))

print("[TFL Damage Amplifier Field] Loaded - Offensive field ready (OFF by default, optimized)")
