-- TFL Tool Grabber V8
-- Instant tool acquisition with parallel pad touching

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local Tycoons = workspace:WaitForChild("Tycoons", 10)

if not Tycoons then
	warn("[TFLToolGrabber] workspace.Tycoons was not found.")
	return
end

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

-- Config
local TOUCH_BURST = 2
local SPAWN_TOUCH_BURST = 5
local PAD_RANGE = 10000
local IDLE_CHECK_INTERVAL = 0.1
local SPAWN_FORCE_TIME = 0.55

local ALLOWED_BASE_ORDER = {
	"Stone", "Magic", "Storm", "Robotic", "Mecha",
	"Shadow", "Hyper", "Thunder", "Void", "Frozen",
	"Magma", "Nuclear", "Toxic", "Kong",
}

local BASE_ALIASES = {
	Stone = { "Stone" },
	Magic = { "Magic" },
	Storm = { "Storm" },
	Robotic = { "Robotic" },
	Mecha = { "Mecha" },
	Shadow = { "Shadow" },
	Hyper = { "Hyper" },
	Thunder = { "Thunder" },
	Void = { "Void" },
	Frozen = { "Frozen" },
	Magma = { "Magma" },
	Nuclear = { "Nuclear" },
	Toxic = { "Toxic" },
	Kong = { "Kong" },
}

local TOOL_RULES = {
	{ Pattern = "Energy Sword", Base = "Stone" },
	{ Pattern = "Staff", Base = "Magic" },
	{ Pattern = "Axe", Base = "Storm" },
	{ Pattern = "Fists", Base = "Robotic", ForceBase = true },
	{ Pattern = "Frozen Claws", Base = "Frozen" },
	{ Pattern = "Nuclear Claws", Base = "Nuclear" },
	{ Pattern = "Hyper Claws", Base = "Hyper" },
	{ Pattern = "Thunder Claws", Base = "Thunder" },
	{ Pattern = "Toxic Claws", Base = "Toxic" },
	{ Pattern = "Shadow Claws", Base = "Shadow" },
	{ Pattern = "Void Claws", Base = "Void" },
	{ Pattern = "Magma Claws", Base = "Magma" },
	{ Pattern = "Punch", Base = "Kong" },
	{ Pattern = "Blade Arms", Base = "Mecha" },
}

local FORCED_BASE_TOUCHES = {
	Robotic = 4
}

-- Cleanup
if _G.__TFLToolGrabberCleanup then
	pcall(_G.__TFLToolGrabberCleanup)
end

local alive = true
local connections = {}
local characterConnections = {}

local function disconnectList(list)
	for _, conn in ipairs(list) do
		if conn and conn.Connected then
			conn:Disconnect()
		end
	end
	table.clear(list)
end

local function track(conn)
	table.insert(connections, conn)
	return conn
end

local function trackCharacter(conn)
	table.insert(characterConnections, conn)
	return conn
end

local function cleanup()
	alive = false
	disconnectList(connections)
	disconnectList(characterConnections)
	_G.TFLToolGrabber = nil
end

_G.__TFLToolGrabberCleanup = cleanup

-- State
local padsByBase = {}
local registeredPads = {}
local currentCharacter = nil
local currentRoot = nil
local acquireRunning = false
local scheduleSerial = 0
local lifeSerial = 0
local baseTouchCounts = {}

for _, baseName in ipairs(ALLOWED_BASE_ORDER) do
	padsByBase[baseName] = {}
end

-- Base / Pad discovery
local function normalizeName(value)
	return tostring(value or ""):lower():gsub("[^%w]", "")
end

local function allowedBaseFromName(name)
	local normalized = normalizeName(name)
	
	for baseName, aliases in pairs(BASE_ALIASES) do
		for _, alias in ipairs(aliases) do
			local normalizedAlias = normalizeName(alias)
			if normalized == normalizedAlias or normalized:find(normalizedAlias, 1, true) then
				return baseName
			end
		end
	end
	
	return nil
end

local function findGearGiver1Ancestor(instance)
	local node = instance
	
	while node and node ~= Tycoons do
		if node.Name == "GearGiver1" then
			return node
		end
		node = node.Parent
	end
	
	return nil
end

local function findAllowedBaseAncestor(instance)
	local node = instance
	
	while node and node ~= Tycoons do
		local baseName = allowedBaseFromName(node.Name)
		if baseName then
			return baseName, node
		end
		node = node.Parent
	end
	
	return nil, nil
end

local function hasTouchTransmitter(part)
	return part and part:IsA("BasePart") and part:FindFirstChildOfClass("TouchTransmitter") ~= nil
end

local function registerPad(part)
	if not alive then return end
	if not hasTouchTransmitter(part) then return end
	
	local giver = findGearGiver1Ancestor(part)
	if not giver then return end
	
	local baseName = findAllowedBaseAncestor(giver.Parent)
	if not baseName then return end
	
	if registeredPads[part] == baseName then
		return
	end
	
	if registeredPads[part] and registeredPads[part] ~= baseName then
		local oldPads = padsByBase[registeredPads[part]]
		if oldPads then
			for i = #oldPads, 1, -1 do
				if oldPads[i] == part then
					table.remove(oldPads, i)
				end
			end
		end
	end
	
	registeredPads[part] = baseName
	table.insert(padsByBase[baseName], part)
end

local function scanTycoons()
	for _, obj in ipairs(Tycoons:GetDescendants()) do
		if obj:IsA("BasePart") then
			registerPad(obj)
		end
	end
end

scanTycoons()

track(Tycoons.DescendantAdded:Connect(function(obj)
	if obj:IsA("BasePart") then
		task.defer(registerPad, obj)
	elseif obj:IsA("TouchTransmitter") and obj.Parent and obj.Parent:IsA("BasePart") then
		registerPad(obj.Parent)
	end
end))

-- Tool checks
local function toolMatches(tool, pattern)
	if not tool or not tool:IsA("Tool") then return false end
	return normalizeName(tool.Name):find(normalizeName(pattern), 1, true) ~= nil
end

local function hasTool(pattern)
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack")
	
	if backpack then
		for _, item in ipairs(backpack:GetChildren()) do
			if toolMatches(item, pattern) then
				return true
			end
		end
	end
	
	local character = currentCharacter
	if character then
		for _, item in ipairs(character:GetChildren()) do
			if toolMatches(item, pattern) then
				return true
			end
		end
	end
	
	return false
end

-- Pad picking
local function prunePadList(baseName)
	local pads = padsByBase[baseName]
	if not pads then return nil end
	
	for i = #pads, 1, -1 do
		local pad = pads[i]
		if not pad or not pad.Parent or registeredPads[pad] ~= baseName then
			if pad then
				registeredPads[pad] = nil
			end
			table.remove(pads, i)
		end
	end
	
	return pads
end

local function getClosestPad(baseName)
	local root = currentRoot
	if not root then return nil end
	
	local pads = prunePadList(baseName)
	if not pads or #pads == 0 then return nil end
	
	local closest = nil
	local bestDistance = PAD_RANGE
	
	for _, pad in ipairs(pads) do
		local distance = (pad.Position - root.Position).Magnitude
		if distance < bestDistance then
			bestDistance = distance
			closest = pad
		end
	end
	
	return closest
end

-- Touch engine
local function tapPad(root, pad, baseName, burstCount)
	if type(firetouchinterest) ~= "function" then return end
	if not root or not root.Parent or not pad or not pad.Parent then return end
	
	burstCount = burstCount or TOUCH_BURST
	
	pcall(function()
		for _ = 1, burstCount do
			firetouchinterest(root, pad, 0)
			firetouchinterest(root, pad, 1)
		end
	end)
	
	baseTouchCounts[baseName] = (baseTouchCounts[baseName] or 0) + 1
end

-- Wave builder
local function buildWave(forceAll)
	local wave = {}
	local seenPads = {}
	
	if forceAll then
		for _, baseName in ipairs(ALLOWED_BASE_ORDER) do
			local pad = getClosestPad(baseName)
			if pad and not seenPads[pad] then
				seenPads[pad] = true
				table.insert(wave, { Pad = pad, Base = baseName })
			end
		end
		return wave
	end
	
	for _, rule in ipairs(TOOL_RULES) do
		if not hasTool(rule.Pattern) then
			local pad = getClosestPad(rule.Base)
			if pad and not seenPads[pad] then
				seenPads[pad] = true
				table.insert(wave, { Pad = pad, Base = rule.Base })
			end
		end
	end
	
	return wave
end

-- Acquisition engine
local function acquirePass(root, wave, burstCount)
	if not root or not root.Parent then return end
	
	for _, entry in ipairs(wave) do
		tapPad(root, entry.Pad, entry.Base, burstCount)
	end
end

local function runInstantRespawnBurst(character)
	local myChar = character or currentCharacter or LocalPlayer.Character
	if not myChar then return end
	
	local root = myChar:FindFirstChild("HumanoidRootPart")
	if not root then return end
	
	currentRoot = root
	
	local wave = buildWave(true)
	acquirePass(root, wave, SPAWN_TOUCH_BURST)
	
	-- Parallel touch for speed
	for _, entry in ipairs(wave) do
		task.spawn(function()
			tapPad(root, entry.Pad, entry.Base, SPAWN_TOUCH_BURST)
		end)
	end
end

-- Character / Backpack tracking
local function bindCharacter(character)
	disconnectList(characterConnections)
	
	currentCharacter = character
	currentRoot = nil
	lifeSerial = lifeSerial + 1
	
	if not character then return end
	
	runInstantRespawnBurst(character)
	
	character.ChildAdded:Connect(function(child)
		if child:IsA("BasePart") then
			currentRoot = child
			runInstantRespawnBurst(character)
		elseif child:IsA("Tool") then
			task.spawn(function()
				local root = currentRoot or character:FindFirstChild("HumanoidRootPart")
				if root then
					local wave = buildWave()
					acquirePass(root, wave, SPAWN_TOUCH_BURST)
				end
			end)
		end
	end)
	
	character.ChildRemoved:Connect(function(child)
		if child == currentRoot then
			currentRoot = nil
		end
	end)
	
	local root = character:FindFirstChild("HumanoidRootPart")
	if root then
		currentRoot = root
		runInstantRespawnBurst(character)
	else
		local myLife = lifeSerial
		task.defer(function()
			if not alive or myLife ~= lifeSerial then return end
			local waitedRoot = character:WaitForChild("HumanoidRootPart", 5)
			if waitedRoot then
				currentRoot = waitedRoot
				runInstantRespawnBurst(character)
			end
		end)
	end
end

local function bindBackpack()
	local backpack = LocalPlayer:FindFirstChildOfClass("Backpack") or LocalPlayer:WaitForChild("Backpack", 5)
	if not backpack then return end
	
	backpack.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.spawn(function()
				local root = currentRoot or LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
				if root then
					local wave = buildWave()
					acquirePass(root, wave, SPAWN_TOUCH_BURST)
				end
			end)
		end
	end)
end

track(LocalPlayer.CharacterAdded:Connect(bindCharacter))
track(LocalPlayer.CharacterRemoving:Connect(function(character)
	if character == currentCharacter then
		currentCharacter = nil
		currentRoot = nil
	end
end))

bindBackpack()

if LocalPlayer.Character then
	bindCharacter(LocalPlayer.Character)
else
	runInstantRespawnBurst()
end

-- Low-cost idle safety loop
task.spawn(function()
	while alive do
		task.wait(IDLE_CHECK_INTERVAL)
		local root = currentRoot or LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local wave = buildWave()
			acquirePass(root, wave, TOUCH_BURST)
		end
	end
end)

-- API
_G.TFLToolGrabber = {
	Acquire = function()
		local root = currentRoot or LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local wave = buildWave()
			acquirePass(root, wave, SPAWN_TOUCH_BURST)
		end
	end,
	Burst = function()
		runInstantRespawnBurst()
	end,
	Config = {
		TouchBurst = TOUCH_BURST,
		SpawnTouchBurst = SPAWN_TOUCH_BURST,
	}
}

print("[TFLToolGrabber] V8 Loaded - Instant tool acquisition")