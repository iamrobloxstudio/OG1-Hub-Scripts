local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local LocalPlayer = Players.LocalPlayer or Players:GetPropertyChangedSignal("LocalPlayer"):Wait()

-- Modern Fire Touch Interest Resolver
local fireTouch: ((BasePart, BasePart, number) -> ())? = firetouchinterest 
	or (getgenv and (getgenv().firetouchinterest or getgenv().fire_touch_interest))
	or (syn and syn.firetouchinterest)

if not fireTouch then
	warn("[Tool Grabber] FireTouchInterest executor closure not found. Aborting execution.")
	return
end

-- ================================================================
-- CLEANUP EXISTING GUI INSTANCES IF PRESENT
-- ================================================================
pcall(function()
	local core = CoreGui
	if core then
		local old = core:FindFirstChild("CipherToolGrabberUI")
		if old then old:Destroy() end
	end
	local pgui = LocalPlayer:FindFirstChild("PlayerGui")
	if pgui then
		local old = pgui:FindFirstChild("CipherToolGrabberUI")
		if old then old:Destroy() end
	end
end)

-- Filter Sets (Lookup maps)
local EXCLUDED_BASES: { [string]: boolean } = {
	["Insanity"] = true,
	["Giant"]    = true,
	["Dark"]     = true,
	["Spike"]    = true,
	["Web"]      = true,
	["Strong"]   = true,
}

local ALLOWED_BASES: { [string]: boolean } = {
	["Stone"]   = true,
	["Magic"]   = true,
	["Storm"]   = true,
	["Robotic"] = true,
}

-- Workspace Targets
local tycoons: Instance = Workspace:FindFirstChild("Tycoons") or Workspace

-- Cache Arrays
local touchableParts: { BasePart } = {}
local partCount: number = 0

-- Fast Part Verification & Register
local function evaluateAndAdd(descendant: Instance)
	if not descendant:IsA("TouchTransmitter") then return end

	local parent = descendant.Parent
	if not (parent and parent:IsA("BasePart")) then return end

	local gearGiver = parent.Parent
	if not (gearGiver and string.find(gearGiver.Name, "GearGiver1", 1, true)) then return end

	local baseFolder = gearGiver.Parent
	local baseName = baseFolder and baseFolder.Name

	if baseName and (ALLOWED_BASES[baseName] or not EXCLUDED_BASES[baseName]) then
		partCount += 1
		touchableParts[partCount] = parent

		parent.AncestryChanged:Connect(function(_, newParent)
			if not newParent then
				local idx = table.find(touchableParts, parent)
				if idx then
					table.remove(touchableParts, idx)
					partCount -= 1
				end
			end
		end)
	end
end

for _, inst in ipairs(tycoons:GetDescendants()) do
	evaluateAndAdd(inst)
end

tycoons.DescendantAdded:Connect(evaluateAndAdd)

-- Cache Character Root
local currentRoot: BasePart? = nil

local function updateCharacterRoot(character: Model)
	currentRoot = (character:WaitForChild("HumanoidRootPart", 5) 
		or character:FindFirstChildWhichIsA("BasePart")) :: BasePart?
end

if LocalPlayer.Character then
	updateCharacterRoot(LocalPlayer.Character)
end

-- ================================================================
-- HYPER-SPEED TOUCH ENGINE (NATIVE FRAME RATE)
-- ================================================================
local function fireAllTouches()
	local root = currentRoot
	if not (root and root.Parent) then return end

	for i = 1, partCount do
		local targetPart = touchableParts[i]
		if targetPart and targetPart.Parent and fireTouch then
			-- Double-tap 0 and 1 states for instant server registration
			pcall(fireTouch, root, targetPart, 0)
			pcall(fireTouch, root, targetPart, 1)
			pcall(fireTouch, root, targetPart, 0)
			pcall(fireTouch, root, targetPart, 1)
		end
	end
end

-- Runs on every single simulation frame for immediate gear grabbing
RunService.PostSimulation:Connect(fireAllTouches)

LocalPlayer.CharacterAdded:Connect(function(char: Model)
	updateCharacterRoot(char)
	task.defer(function()
		for _ = 1, 5 do
			fireAllTouches()
			RunService.Heartbeat:Wait()
		end
	end)
end)

LocalPlayer.CharacterRemoving:Connect(function()
	currentRoot = nil
end)

-- Initial burst
task.defer(function()
	for _ = 1, 5 do
		fireAllTouches()
	end
end)

print("[Tool Grabber] CIPHER // TOOL GRABBER V5.0 Loaded (Hyper-Speed SSS Edition).")
