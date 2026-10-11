local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

-- Executor API Resolver
local fireTouch: ((BasePart, BasePart, number) -> ())? = firetouchinterest 
	or (getgenv and (getgenv().firetouchinterest or getgenv().fire_touch_interest))
	or (syn and syn.firetouchinterest)

if not fireTouch then
	warn("[Insta-Kill] firetouchinterest executor closure not found. Touch damage disabled.")
end

-- Configuration
local RANGE: number           = 50
local RANGE_SQ: number        = RANGE * RANGE
local TOUCH_BURST: number     = 6      -- touch pairs per target part per pulse
local REMOTE_BURST: number    = 4      -- remote fires per remote per pulse
local TARGET_REFRESH: number  = 1 / 60 -- 60 Hz target scan
local ACTIVE_INTERVAL: number = 1 / 120 -- 120 Hz attack while target exists
local IDLE_INTERVAL: number   = 1 / 30
local Active: boolean         = true

-- State & Tool Caches
local toolList: { Tool }                   = {}
local touchCache: { [Tool]: BasePart }     = {}
local remoteCache: { [Tool]: RemoteEvent } = {}
local remotes: { RemoteEvent }             = {}

local currentTarget: Model?
local currentTargetRoot: BasePart?
local currentTargetHum: Humanoid?
local currentParts: { BasePart }           = {}

local lastTargetUpdate: number = 0
local lastAttack: number       = 0
local activeState: boolean     = false

local localCharacter: Model?
local localRoot: BasePart?
local charEpoch: number        = 0

-- ================================================================
-- CLEANUP EXISTING GUI INSTANCES IF PRESENT
-- ================================================================
pcall(function()
	local core = CoreGui
	if core then
		local old = core:FindFirstChild("CipherInstaKillUI")
		if old then old:Destroy() end
	end
	local pgui = LocalPlayer:FindFirstChild("PlayerGui")
	if pgui then
		local old = pgui:FindFirstChild("CipherInstaKillUI")
		if old then old:Destroy() end
	end
end)

-- ================================================================
-- 1. REMOTE DISCOVERY
-- ================================================================
local function findFightRemote(tool: Tool): RemoteEvent?
	local r = tool:FindFirstChild("FightEvent")
	if r and r:IsA("RemoteEvent") then return r end
	for _, o in ipairs(tool:GetDescendants()) do
		if o:IsA("RemoteEvent") then
			local n = string.lower(o.Name)
			if string.find(n, "fight", 1, true) or string.find(n, "slap", 1, true) or string.find(n, "event", 1, true) then
				return o
			end
		end
	end
	return nil
end

-- ================================================================
-- 2. CHARACTER BIND & TOOL MONITOR
-- ================================================================
local function bindCharacter(char: Model)
	charEpoch += 1
	local myEpoch = charEpoch
	localCharacter = char
	localRoot = nil
	if not char then return end

	local r = char:FindFirstChild("HumanoidRootPart")
	if not r then r = char:WaitForChild("HumanoidRootPart", 5) end
	if charEpoch == myEpoch and r and r:IsA("BasePart") then
		localRoot = r
	end
end

local function rebuildCache()
	table.clear(toolList)
	table.clear(touchCache)
	table.clear(remoteCache)
	table.clear(remotes)

	local char = localCharacter
	if not char then return end

	for _, o in ipairs(char:GetChildren()) do
		if o:IsA("Tool") then
			table.insert(toolList, o)

			local tx = o:FindFirstChildWhichIsA("TouchTransmitter", true)
			local touch = tx and tx.Parent
			if not (touch and touch:IsA("BasePart")) then
				touch = o:FindFirstChild("Handle")
			end
			if touch and touch:IsA("BasePart") then
				touchCache[o] = touch
				touch.CanCollide = false
				touch.Massless = true
				touch.CanTouch = true
			end

			local rem = findFightRemote(o)
			if rem then
				remoteCache[o] = rem
				table.insert(remotes, rem)
			end
		end
	end
end

local function hookTools(char: Model)
	if not char then return end
	local function refresh()
		task.defer(rebuildCache)
	end
	char.ChildAdded:Connect(function(o: Instance)
		if o:IsA("Tool") then refresh() end
	end)
	char.ChildRemoved:Connect(function(o: Instance)
		if o:IsA("Tool") then refresh() end
	end)
	rebuildCache()
end

if LocalPlayer.Character then
	bindCharacter(LocalPlayer.Character)
	hookTools(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char: Model)
	bindCharacter(char)
	hookTools(char)
end)

-- ================================================================
-- 3. TARGET PARTS EXPANDER (R6 & R15)
-- ================================================================
local PRIORITY_PARTS = {
	"HumanoidRootPart",
	"Head",
	"UpperTorso",
	"LowerTorso",
	"Torso",
}

local function buildParts(char: Model): { BasePart }
	local t: { BasePart } = {}
	for i = 1, #PRIORITY_PARTS do
		local p = char:FindFirstChild(PRIORITY_PARTS[i])
		if p and p:IsA("BasePart") then
			table.insert(t, p)
		end
	end
	if #t == 0 then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			table.insert(t, hrp)
		end
	end
	return t
end

-- ================================================================
-- 4. TARGET ACQUISITION (SQUARED DISTANCE)
-- ================================================================
local function updateTarget()
	local now = os.clock()
	if now - lastTargetUpdate < TARGET_REFRESH then return end
	lastTargetUpdate = now

	local myRoot = localRoot
	if not myRoot then
		currentTarget = nil
		currentTargetRoot = nil
		currentTargetHum = nil
		table.clear(currentParts)
		activeState = false
		return
	end

	local myPos = myRoot.Position
	local bestChar: Model? = nil
	local bestRoot: BasePart? = nil
	local bestHum: Humanoid? = nil
	local bestD: number = RANGE_SQ

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr ~= LocalPlayer then
			local char = plr.Character
			if char then
				local hum = char:FindFirstChildOfClass("Humanoid")
				local r = char:FindFirstChild("HumanoidRootPart")
				if hum and r and r:IsA("BasePart") and hum.Health > 0 then
					local dx = r.Position.X - myPos.X
					local dy = r.Position.Y - myPos.Y
					local dz = r.Position.Z - myPos.Z
					local dsq = dx * dx + dy * dy + dz * dz
					if dsq < bestD then
						bestD = dsq
						bestChar = char
						bestRoot = r
						bestHum = hum
					end
				end
			end
		end
	end

	currentTarget = bestChar
	currentTargetRoot = bestRoot
	currentTargetHum = bestHum
	currentParts = bestChar and buildParts(bestChar) or {}
	activeState = (bestChar ~= nil)
end

-- ================================================================
-- 5. ATTACK ENGINE (BURST TOUCH & REMOTES)
-- ================================================================
local function hitTarget()
	if not activeState or not Active then return end
	local hum = currentTargetHum
	if not hum or hum.Health <= 0 then return end

	if #currentParts == 0 and currentTarget then
		currentParts = buildParts(currentTarget)
	end

	-- High MS Ping Double-Tap Touch Interest Burst
	if fireTouch then
		for i = 1, #toolList do
			local touch = touchCache[toolList[i]]
			if touch and touch.Parent then
				for p = 1, #currentParts do
					local target = currentParts[p]
					if target and target.Parent then
						for _ = 1, TOUCH_BURST do
							pcall(fireTouch, touch, target, 0)
							pcall(fireTouch, touch, target, 1)
						end
					end
				end
			end
		end
	end

	-- Remote event burst
	local root = currentTargetRoot
	if root and root.Parent then
		for i = 1, #remotes do
			local r = remotes[i]
			if r and r.Parent then
				for _ = 1, REMOTE_BURST do
					pcall(r.FireServer, r, root)
				end
			end
		end
	end
end

-- ================================================================
-- 6. MAIN RUNNER (HEADLESS // ALWAYS ACTIVE)
-- ================================================================
RunService.Stepped:Connect(function()
	if not Active then return end

	updateTarget()

	local interval = activeState and ACTIVE_INTERVAL or IDLE_INTERVAL
	local now = os.clock()
	if now - lastAttack < interval then return end
	lastAttack = now

	if activeState then
		hitTarget()
	end
end)

print("[Insta-Kill] CIPHER // INSTA-KILL BURST AURA V4.1 Loaded (Always Active // Headless).")
