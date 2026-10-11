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

-- Configuration (Maximized Reach & Burst Pacing)
local RANGE: number       = 45
local RANGE_SQ: number    = RANGE * RANGE
local TOUCH_BURST: number = 5
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
-- 1. TOOL CACHING ENGINE & ACTIVATION HOOK
-- ================================================================
local toolParts: { BasePart } = {}
local hookedTools: { [Tool]: boolean } = {}

-- Forward declaration of hit burst
local fireAuraBurst: () -> ()

local function rebuildToolParts()
	table.clear(toolParts)
	local char = LocalPlayer.Character
	if not char then return end

	for _, t in ipairs(char:GetChildren()) do
		if t:IsA("Tool") then
			-- Gather all touchable parts inside the tool
			for _, obj in ipairs(t:GetDescendants()) do
				if obj:IsA("TouchTransmitter") and obj.Parent and obj.Parent:IsA("BasePart") then
					local p = obj.Parent
					p.CanCollide = false
					p.Massless = true
					p.CanTouch = true
					if not table.find(toolParts, p) then
						table.insert(toolParts, p)
					end
				end
			end

			local handle = t:FindFirstChild("Handle")
			if handle and handle:IsA("BasePart") then
				handle.CanCollide = false
				handle.Massless = true
				handle.CanTouch = true
				if not table.find(toolParts, handle) then
					table.insert(toolParts, handle)
				end
			end

			-- Hook tool activation for microsecond touch triggering
			if not hookedTools[t] then
				hookedTools[t] = true
				t.Activated:Connect(function()
					if Active then
						fireAuraBurst()
					end
				end)
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
	table.clear(hookedTools)
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

-- ================================================================
-- 3. ALL IN-RANGE ENEMIES RESOLVER
-- ================================================================
local targetsBuffer: { Model } = {}

local function updateTargets()
	table.clear(targetsBuffer)
	local char = LocalPlayer.Character
	if not char then return end

	local myRoot = char:FindFirstChild("HumanoidRootPart") or char:FindFirstChild("Torso")
	if not (myRoot and myRoot:IsA("BasePart")) then return end

	local myPos = myRoot.Position

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local pChar = p.Character
			if pChar then
				local hum = pChar:FindFirstChildOfClass("Humanoid")
				local r = pChar:FindFirstChild("HumanoidRootPart") or pChar:FindFirstChild("Torso")
				if hum and r and r:IsA("BasePart") and hum.Health > 0 then
					local dx = r.Position.X - myPos.X
					local dy = r.Position.Y - myPos.Y
					local dz = r.Position.Z - myPos.Z
					if (dx * dx + dy * dy + dz * dz) <= RANGE_SQ then
						table.insert(targetsBuffer, pChar)
					end
				end
			end
		end
	end
end

-- ================================================================
-- 4. RELENTLESS AURA BURST ENGINE
-- ================================================================
fireAuraBurst = function()
	if not Active or not fireTouch then return end
	if #toolParts == 0 then
		rebuildToolParts()
		if #toolParts == 0 then return end
	end

	updateTargets()
	if #targetsBuffer == 0 then return end

	for tIndex = 1, #targetsBuffer do
		local target = targetsBuffer[tIndex]
		for pIndex = 1, #EXPANDED_PARTS do
			local enemyPart = target:FindFirstChild(EXPANDED_PARTS[pIndex])
			if enemyPart and enemyPart:IsA("BasePart") and enemyPart.Parent then
				for i = 1, #toolParts do
					local part = toolParts[i]
					if part and part.Parent then
						for _ = 1, TOUCH_BURST do
							pcall(fireTouch, part, enemyPart, 0)
							pcall(fireTouch, part, enemyPart, 1)
						end
					end
				end
			end
		end
	end
end

-- Dual-phase continuous execution on Stepped AND Heartbeat for unrelenting touch contact
RunService.Stepped:Connect(function()
	if Active then
		fireAuraBurst()
	end
end)

RunService.Heartbeat:Connect(function()
	if Active then
		fireAuraBurst()
	end
end)

print("[Kill Aura] CIPHER // KILL AURA V5.0 Loaded (Relentless Multi-Target SSS Edition).")
