-- TFL Get Base V2
-- Auto-claim base script for Super Power Tycoon and Mega Power Tycoon
-- OPTIMIZED: Reduced loop frequency, better connection management

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local RunService = game:GetService("RunService")
local Tycoons = workspace:WaitForChild("Tycoons", 10)

if not Tycoons then
	warn("[TFL Get Base] workspace.Tycoons was not found.")
	return
end

-- Place IDs
local SPT_PLACE_ID = 5142372758
local MPT_PLACE_ID = 10065006658

-- Game-specific base priorities
local BASE_ORDERS = {
    [SPT_PLACE_ID] = {
        "Stone", "Robotic", "Storm", "Magic", "Spike",
        "Strong", "Web", "Insanity", "Dark", "Giant"
    },
    [MPT_PLACE_ID] = {
        "Frozen", "Hyper", "Kong", "Magma", "Mecha",
        "Nuclear", "Shadow", "Thunder", "Toxic", "Void"
    }
}

-- Determine current game type
local currentPlaceId = game.PlaceId
local BASE_ORDER = BASE_ORDERS[currentPlaceId]
if not BASE_ORDER then
    warn("⚠ Unsupported PlaceId: No base list defined.")
    return
end

local claimed = false
local Connections = {}

-- Utilities
local function fireTouch(part, target)
    pcall(firetouchinterest, part, target, 0)
    pcall(firetouchinterest, part, target, 1)
end

local function getRoot()
    return LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
end

local function claimBase(name)
    local tycoon = Tycoons:FindFirstChild(name)
    local door = tycoon and tycoon:FindFirstChild("Door")
    local root = getRoot()
    if not (door and root) then return end

    for _, part in ipairs(door:GetChildren()) do
        if part:IsA("BasePart") then
            fireTouch(root, part)
        end
    end
end

local function isUnclaimed(name)
    local tycoon = Tycoons:FindFirstChild(name)
    local owner = tycoon and tycoon:FindFirstChild("isim")
    return owner and not Players:FindFirstChild(owner.Value)
end

local function tryClaimAll()
    for _, base in ipairs(BASE_ORDER) do
        if claimed then return end
        if isUnclaimed(base) then
            claimBase(base)

            local tycoon = Tycoons:FindFirstChild(base)
            local owner = tycoon and tycoon:FindFirstChild("isim")

            if owner then
                for _ = 1, 10 do
                    if Players:FindFirstChild(owner.Value) == LocalPlayer then
                        claimed = true
                        print("✅ TFL Claimed base:", base)
                        break
                    end
                    task.wait(0.1)
                end
            end
        end
    end
end

-- Resilience Logic
local function onCharacterAdded()
    claimed = false
    if LocalPlayer.Character then
        LocalPlayer.Character:WaitForChild("HumanoidRootPart", 5)
    end
end

Connections[#Connections + 1] = LocalPlayer.CharacterAdded:Connect(onCharacterAdded)

-- OPTIMIZED: Use PreSimulation with rate limiting instead of every frame
local lastClaimAttempt = 0
local CLAIM_INTERVAL = 0.5

RunService.PreSimulation:Connect(function()
    if not claimed and getRoot() then
        local now = os.clock()
        if now - lastClaimAttempt >= CLAIM_INTERVAL then
            lastClaimAttempt = now
            tryClaimAll()
        end
    end
end)

print("TFL Get Base V2 Loaded (optimized)")
