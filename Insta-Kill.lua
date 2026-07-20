-- TFL Insta-Kill V2
-- Micro-burst FightEvent activation on target detection - instant damage
-- OPTIMIZED: Better burst control, PreSimulation timing, no excessive burst firing

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Configuration
local AURA_RANGE = 28
local TOUCH_BURST = 2
local FIGHT_BURST = 5
local RESPAWN_BURST_TIME = 0.5
local SPAWN_MULTI_BURST = 5

-- State
local ToolsCache = {}
local LastActivation = 0
local BurstActive = false

-- Pre-allocated buffers
local TargetPartsBuffer = {}

-- Helper functions
local function getHRP(char)
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

-- Refresh tools cache - OPTIMIZED: Single pass
local function refreshTools()
	table.clear(ToolsCache)
	local char = LocalPlayer.Character
	if not char then return end
	
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local fightEvent = tool:FindFirstChild("FightEvent", true)
			local touchPart = tool:FindFirstChildWhichIsA("TouchTransmitter", true)
			
			if fightEvent and fightEvent:IsA("RemoteEvent") then
				ToolsCache[#ToolsCache + 1] = {
					Tool = tool,
					FightEvent = fightEvent,
					TouchPart = touchPart and touchPart.Parent or nil
				}
			elseif touchPart then
				ToolsCache[#ToolsCache + 1] = {
					Tool = tool,
					FightEvent = nil,
					TouchPart = touchPart.Parent
				}
			end
		end
	end
end

-- Get target in range
local function getTarget()
	local myChar = LocalPlayer.Character
	local myRoot = myChar and getHRP(myChar)
	if not myRoot then return nil end
	
	local bestChar
	local bestDist = AURA_RANGE
	
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			if char then
				local root = getHRP(char)
				if root then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum and hum.Health > 0 then
						local dist = (root.Position - myRoot.Position).Magnitude
						if dist < bestDist then
							bestDist = dist
							bestChar = char
						end
					end
				end
			end
		end
	end
	
	return bestChar
end

-- Micro-burst activation - OPTIMIZED: Reduced burst count
local function microBurst(targetChar, burstCount)
	if not targetChar or not LocalPlayer.Character then return end
	
	local targetRoot = getHRP(targetChar)
	if not targetRoot then return end
	
	-- Build target parts list using pre-allocated buffer
	table.clear(TargetPartsBuffer)
	for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "Torso", "Head"}) do
		local part = targetChar:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			TargetPartsBuffer[#TargetPartsBuffer + 1] = part
		end
	end
	
	if #TargetPartsBuffer == 0 then return end
	
	for _, toolData in ipairs(ToolsCache) do
		local tool = toolData.Tool
		local fight = toolData.FightEvent
		local touch = toolData.TouchPart
		
		if tool and tool.Parent then
			-- FightEvent burst - instant
			if fight then
				pcall(function()
					for _ = 1, burstCount do
						fight:FireServer()
					end
				end)
			else
				pcall(tool.Activate, tool)
			end
			
			-- Touch assist
			if touch then
				for _, part in ipairs(TargetPartsBuffer) do
					if part and part.Parent then
						pcall(firetouchinterest, touch, part, 0)
						pcall(firetouchinterest, touch, part, 1)
					end
				end
			end
		end
	end
end

-- Spawn burst handler - OPTIMIZED: Reduced time, no excessive burst
local function startSpawnBurst()
	if BurstActive then return end
	BurstActive = true
	
	task.spawn(function()
		local startTime = os.clock()
		local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
		
		-- Initial equip all tools
		if backpack and LocalPlayer.Character then
			for _, tool in ipairs(backpack:GetChildren()) do
				if tool:IsA("Tool") then
					tool.Parent = LocalPlayer.Character
				end
			end
		end
		
		RunService.Heartbeat:Wait()
		refreshTools()
		
		-- Quick burst for respawn
		while LocalPlayer.Character and os.clock() - startTime < RESPAWN_BURST_TIME do
			local target = getTarget()
			if target then
				microBurst(target, SPAWN_MULTI_BURST)
			end
			RunService.Heartbeat:Wait()
		end
		
		BurstActive = false
	end)
end

-- Character bind
LocalPlayer.CharacterAdded:Connect(function()
	BurstActive = false
	table.clear(ToolsCache)
	
	task.defer(refreshTools)
	
	-- Immediate burst on spawn if target in range
	local target = getTarget()
	if target then
		startSpawnBurst()
	end
end)

LocalPlayer.CharacterRemoving:Connect(function()
	BurstActive = false
	table.clear(ToolsCache)
end)

-- Initial setup
refreshTools()

-- Main loop - OPTIMIZED: PreSimulation for better timing
RunService.PreSimulation:Connect(function()
	if BurstActive then return end
	
	local now = os.clock()
	if now - LastActivation < 1/60 then return end
	LastActivation = now
	
	refreshTools()
	if #ToolsCache == 0 then return end
	
	local target = getTarget()
	if target then
		microBurst(target, FIGHT_BURST)
	end
end)

print("[TFL Insta-Kill] V2 Loaded - Micro-burst damage active (optimized)")
