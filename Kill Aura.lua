-- TFL Kill Aura
-- Proximity-based tool activation for maximum damage - always active in range
-- No UI, pure logic

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

-- Configuration
local AURA_RANGE = 30
local TOUCH_BURST = 3
local AURA_RATE = 1/60

-- Caches
local ToolsCache = {}
local LastAura = 0

-- Get HRP safely
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
			-- Get touch part
			local touchPart = tool:FindFirstChildWhichIsA("TouchTransmitter", true)
			local part = touchPart and touchPart.Parent
			
			-- Get fight event if available
			local fightEvent = tool:FindFirstChild("FightEvent", true)
			if fightEvent and not fightEvent:IsA("RemoteEvent") then
				fightEvent = nil
			end
			
			if part or fightEvent then
				table.insert(ToolsCache, {
					Tool = tool,
					TouchPart = part,
					FightEvent = fightEvent
				})
			end
		end
	end
end

-- Get all targets in range
local function getTargets()
	local targets = {}
	local myChar = LocalPlayer.Character
	local myRoot = myChar and getHRP(myChar)
	if not myRoot then return targets end
	
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local root = getHRP(char)
				if hum and root and hum.Health > 0 then
					local dist = (root.Position - myRoot.Position).Magnitude
					if dist <= AURA_RANGE then
						-- Build list of all hittable parts
						local parts = {}
						for _, name in ipairs({"HumanoidRootPart", "UpperTorso", "Torso", "Head"}) do
							local part = char:FindFirstChild(name)
							if part and part:IsA("BasePart") then
								table.insert(parts, part)
							end
						end
						if #parts > 0 then
							table.insert(targets, {
								Root = root,
								Parts = parts
							})
						end
					end
				end
			end
		end
	end
	
	return targets
end

-- Attack targets with tool
local function attackTool(toolData, target)
	local tool = toolData.Tool
	local touch = toolData.TouchPart
	local fight = toolData.FightEvent
	
	if not tool or not tool.Parent then return end
	
	-- FightEvent first (instant damage)
	if fight then
		pcall(function()
			for _ = 1, TOUCH_BURST do
				fight:FireServer()
			end
		end)
	else
		-- Fallback to Activate
		pcall(tool.Activate, tool)
	end
	
	-- Touch assist
	if touch then
		for _, part in ipairs(target.Parts) do
			if part and part.Parent then
				pcall(firetouchinterest, touch, part, 0)
				pcall(firetouchinterest, touch, part, 1)
			end
		end
	end
end

-- Character bind
LocalPlayer.CharacterAdded:Connect(function()
	task.wait(0.1)
	refreshTools()
end)

LocalPlayer.CharacterRemoving:Connect(function()
	table.clear(ToolsCache)
end)

-- Use shared target from Loopbring if available
local function getCurrentTarget()
	if _G.TFLLoopbring and _G.TFLLoopbring.GetCurrentTarget then
		return _G.TFLLoopbring.GetCurrentTarget()
	end
	return nil
end

-- Main loop
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - LastAura < AURA_RATE then return end
	LastAura = now
	
	-- Refresh tools if character changed
	refreshTools()
	if #ToolsCache == 0 then return end
	
	-- Get targets
	local targets = getTargets()
	if #targets == 0 then return end
	
	-- Attack all targets with all tools
	for _, toolData in ipairs(ToolsCache) do
		for _, target in ipairs(targets) do
			attackTool(toolData, target)
		end
	end
end)

print("[TFL Kill Aura] Loaded - Proximity damage active")