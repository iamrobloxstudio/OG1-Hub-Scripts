--!strict
-- ================================================================
-- ⚡ CIPHER // KILL AURA V4.1 (HEADLESS ALWAYS-ON)
-- High-Precision 45Hz Full-Body Multi-Touch Aura Engine
-- High MS Ping Double-Tap Replication | Anti-Snag 1v1 Escape Synergy
-- Headless // Always Active // Zero UI Overhead
-- ================================================================

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

-- Executor API Resolver
local fireTouch: ((BasePart, BasePart, number) -> ())? = firetouchinterest 
	or (getgenv and (getgenv().firetouchinterest or getgenv().fire_touch_interest))
	or (syn and syn.firetouchinterest)

if not fireTouch then
	warn("[Kill Aura] firetouchinterest executor closure not found. Touch damage disabled.")
end

-- Configuration
local RANGE: number       = 32
local RANGE_SQ: number    = RANGE * RANGE
local TOUCH_BURST: number = 4
local AURA_RATE: number   = 1 / 45
local Active: boolean     = true

-- ================================================================
-- CLEANUP EXISTING GUI INSTANCES IF PRESENT
-- ================================================================
pcall(function()
	local core = CoreGui
	if core then
		local old = core:FindFirstChild("CipherKillAuraUI")
		if old then old:Destroy() end
	end
	local pgui = LocalPlayer:FindFirstChild("PlayerGui")
	if pgui then
		local old = pgui:FindFirstChild("CipherKillAuraUI")
		if old then old:Destroy() end
	end
end)

-- ================================================================
-- 1. TOOL CACHING ENGINE (ANTI-SNAG 1V1 ESCAPE SYNERGY)
-- ================================================================
local toolParts: { BasePart } = {}

local function rebuildToolParts()
	table.clear(toolParts)
	local char = LocalPlayer.Character
	if not char then return end

	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") then
			local tx = t:FindFirstChildWhichIsA("TouchTransmitter", true)
			local part = tx and tx.Parent
			if not (part and part:IsA("BasePart")) then
				part = t:FindFirstChild("Handle")
			end
			if part and part:IsA("BasePart") then
				-- Anti-snag physics configuration for seamless 1v1 escape
				part.CanCollide = false
				part.Massless = true
				part.CanTouch = true
				table.insert(toolParts, part)
			end
		end
	end
end

local function onToolChange(c: Instance)
	if c:IsA("Tool") then
		task.defer(rebuildToolParts)
	end
end

local function hookChar(char: Model)
	rebuildToolParts()
	char.ChildAdded:Connect(onToolChange)
	char.ChildRemoved:Connect(onToolChange)
end

if LocalPlayer.Character then
	hookChar(LocalPlayer.Character)
end
LocalPlayer.CharacterAdded:Connect(hookChar)

-- ================================================================
-- 2. EXPANDED BODY PART RESOLVER (R6 & R15)
-- ================================================================
local EXPANDED_PARTS = {
	"HumanoidRootPart", "Head", "UpperTorso", "LowerTorso", "Torso",
	"Right Arm", "Left Arm", "Right Leg", "Left Leg",
	"RightHand", "LeftHand", "RightUpperArm", "RightLowerArm",
	"LeftUpperArm", "LeftLowerArm", "RightUpperLeg", "RightLowerLeg",
	"LeftUpperLeg", "LeftLowerLeg", "RightFoot", "LeftFoot"
}

local enemyPartsBuffer: { BasePart } = {}

local function getExpandedParts(char: Model): { BasePart }
	table.clear(enemyPartsBuffer)
	for i = 1, #EXPANDED_PARTS do
		local p = char:FindFirstChild(EXPANDED_PARTS[i])
		if p and p:IsA("BasePart") then
			table.insert(enemyPartsBuffer, p)
		end
	end
	if #enemyPartsBuffer == 0 then
		local hrp = char:FindFirstChild("HumanoidRootPart")
		if hrp and hrp:IsA("BasePart") then
			table.insert(enemyPartsBuffer, hrp)
		end
	end
	return enemyPartsBuffer
end

-- ================================================================
-- 3. FAST TARGET ACQUISITION (EUCLIDEAN DISTANCE SQUARED)
-- ================================================================
local function getTarget(): Model?
	local char = LocalPlayer.Character
	if not char then return nil end

	local myRoot = char:FindFirstChild("HumanoidRootPart")
	if not (myRoot and myRoot:IsA("BasePart")) then return nil end

	local myPos = myRoot.Position
	local bestChar: Model? = nil
	local bestSq: number = RANGE_SQ

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local pChar = p.Character
			if pChar then
				local hum = pChar:FindFirstChildOfClass("Humanoid")
				local r = pChar:FindFirstChild("HumanoidRootPart")
				if hum and r and r:IsA("BasePart") and hum.Health > 0 then
					local dx = r.Position.X - myPos.X
					local dy = r.Position.Y - myPos.Y
					local dz = r.Position.Z - myPos.Z
					local dsq = dx * dx + dy * dy + dz * dz
					if dsq < bestSq then
						bestSq = dsq
						bestChar = pChar
					end
				end
			end
		end
	end
	return bestChar
end

-- ================================================================
-- 4. ATTACK & RUNNER (HIGH MS PING DOUBLE-TAP REPLICATION)
-- ================================================================
local lastAura: number = 0

RunService.Stepped:Connect(function()
	if not Active then return end

	local now = os.clock()
	if now - lastAura < AURA_RATE then return end
	lastAura = now

	local target = getTarget()
	if not target then return end

	local partsToHit = getExpandedParts(target)
	if #partsToHit == 0 or #toolParts == 0 or not fireTouch then return end

	for i = 1, #toolParts do
		local part = toolParts[i]
		if part and part.Parent then
			for j = 1, #partsToHit do
				local enemyPart = partsToHit[j]
				if enemyPart and enemyPart.Parent then
					for _ = 1, TOUCH_BURST do
						pcall(fireTouch, part, enemyPart, 0)
						pcall(fireTouch, part, enemyPart, 1)
					end
				end
			end
		end
	end
end)

print("[Kill Aura] CIPHER // KILL AURA V4.1 Loaded (Always Active // Headless).")
