-- TFL Hit Amplifier V2
-- Enhanced hit detection with overlap scanning - always active
-- OPTIMIZED: Better performance, reduced allocations, PreSimulation timing

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Configuration
local HIT_RANGE = Vector3.new(24, 24, 24)
local SCAN_RATE = 1/120
local BURST_COUNT = 3

-- State
local Accumulator = 0
local CachedTools = {}
local LastActivation = 0
local ACTIVATION_COOLDOWN = 0.015

-- Cleanup
if _G.__TFLHitAmplifierCleanup then
	pcall(_G.__TFLHitAmplifierCleanup)
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
	table.clear(CachedTools)
end

_G.__TFLHitAmplifierCleanup = cleanup

-- Helper functions
local function getHRP(char)
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

-- Refresh tools - OPTIMIZED: Single pass
local function refreshTools()
	table.clear(CachedTools)
	local char = LocalPlayer.Character
	if not char then return end
	
	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") then
			local fight = t:FindFirstChild("FightEvent", true)
			if fight and fight:IsA("RemoteEvent") then
				CachedTools[#CachedTools + 1] = {Tool = t, FightEvent = fight}
			else
				-- Has touch capability
				local touch = t:FindFirstChildWhichIsA("TouchTransmitter", true)
				if touch then
					CachedTools[#CachedTools + 1] = {Tool = t}
				end
			end
		end
	end
end

-- Pulse tools
local function pulseTools()
	for _, data in ipairs(CachedTools) do
		local tool = data.Tool
		local fight = data.FightEvent
		
		if tool and tool.Parent then
			-- FightEvent first (faster)
			if fight then
				pcall(function()
					for _ = 1, BURST_COUNT do
						fight:FireServer()
					end
				end)
			else
				pcall(tool.Activate, tool)
			end
		end
	end
end

-- Overlap params
local OverlapParams = OverlapParams.new()
OverlapParams.FilterType = Enum.RaycastFilterType.Blacklist

-- Character bind
track(LocalPlayer.CharacterAdded:Connect(refreshTools))
refreshTools()

-- Main loop - OPTIMIZED: PreSimulation for better timing
track(RunService.PreSimulation:Connect(function(dt)
	Accumulator = Accumulator + dt
	if Accumulator < SCAN_RATE then return end
	Accumulator = 0
	
	local char = LocalPlayer.Character
	if not char then return end
	
	local hrp = getHRP(char)
	if not hrp then return end
	
	-- Check cooldown
	local now = os.clock()
	if now - LastActivation < ACTIVATION_COOLDOWN then return end
	
	-- Check for targets in range
	OverlapParams.FilterDescendantsInstances = {char}
	
	local parts = workspace:GetPartBoundsInBox(CFrame.new(hrp.Position), HIT_RANGE, OverlapParams)
	
	local hasTarget = false
	for _, part in ipairs(parts) do
		local model = part:FindFirstChildOfClass("Model") or part.Parent:FindFirstChildOfClass("Model")
		if model then
			local hum = model:FindFirstChildOfClass("Humanoid")
			if hum and hum.Health > 0 and model ~= char then
				hasTarget = true
				break
			end
		end
	end
	
	-- Also check HRP directly
	if not hasTarget then
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr ~= LocalPlayer then
				local targetChar = plr.Character
				if targetChar then
					local targetHRP = getHRP(targetChar)
					local targetHum = targetChar:FindFirstChildOfClass("Humanoid")
					if targetHRP and targetHum and targetHum.Health > 0 then
						local dist = (hrp.Position - targetHRP.Position).Magnitude
						if dist <= 20 then
							hasTarget = true
							break
						end
					end
				end
			end
		end
	end
	
	-- Pulse if target exists
	if hasTarget then
		LastActivation = now
		pulseTools()
	end
end))

print("[TFL Hit Amplifier] V2 Loaded - Enhanced hit detection active (optimized)")
