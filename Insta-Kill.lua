-- TFL Insta-Kill
-- Micro-burst FightEvent activation on target detection - instant damage
-- No UI, pure logic

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Configuration
local AURA_RANGE = 20
local TOUCH_BURST = 2
local FIGHT_BURST = 2
local RESPAWN_BURST_TIME = .5
local SPAWN_MULTI_BURST = 1

-- State
local ToolsCache = {}
local LastActivation = 0
local BurstActive = false

-- Helper functions
local function getHRP(char)
	return char and (char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso"))
end

-- Refresh tools cache
local function refreshTools()
	ToolsCache = {}
	local char = LocalPlayer.Character
	if not char then return end
	
	for _, tool in ipairs(char:GetChildren()) do
		if tool:IsA("Tool") then
			local fightEvent = tool:FindFirstChild("FightEvent", true)
			local touchPart = tool:FindFirstChildWhichIsA("TouchTransmitter", true)
			
			if fightEvent and fightEvent:IsA("RemoteEvent") then
				table.insert(ToolsCache, {
					Tool = tool,
					FightEvent = fightEvent,
					TouchPart = touchPart and touchPart.Parent or nil
				})
			elseif touchPart then
				table.insert(ToolsCache, {
					Tool = tool,
					FightEvent = nil,
					TouchPart = touchPart.Parent
				})
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

-- Micro-burst activation
local function microBurst(targetChar, burstCount)
	if not targetChar or not LocalPlayer.Character then return end
	
	local targetRoot = getHRP(targetChar)
	if not targetRoot then return end
	
	-- Build target parts list
	local targetParts = {}
	for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "Torso", "Head"}) do
		local part = targetChar:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			table.insert(targetParts, part)
		end
	end
	
	if #targetParts == 0 then return end
	
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
				for _, part in ipairs(targetParts) do
					if part and part.Parent then
						pcall(firetouchinterest, touch, part, 0)
						pcall(firetouchinterest, touch, part, 1)
					end
				end
			end
		end
	end
end

-- Spawn burst handler
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
		
		-- Rapid burst for 2 seconds
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
	
	task.wait(0.05)
	refreshTools()
	
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

-- Main loop
RunService.Heartbeat:Connect(function()
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

print("[TFL Insta-Kill] Loaded - Micro-burst damage active")
