--=====================================================
-- ⚡ ULTRA RESPAWN (STABLE BUILD)
-- No connection stacking • Clean lifecycle • Low overhead
--=====================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer
local GuideEvent = ReplicatedStorage:FindFirstChild("Guide")

-----------------------------------------------------
-- STATE
-----------------------------------------------------

local Enabled = true
local Character = nil
local Humanoid = nil

local deathConn = nil
local charConn = nil

local respawnDebounce = false

-----------------------------------------------------
-- CLEAN CONNECTIONS
-----------------------------------------------------

local function clearConnections()
	if deathConn then
		deathConn:Disconnect()
		deathConn = nil
	end
end

-----------------------------------------------------
-- RESPAWN CORE (SAFE + DEBOUNCED)
-----------------------------------------------------

local function doRespawn()
	if respawnDebounce then return end
	respawnDebounce = true

	task.spawn(function()
		if GuideEvent and GuideEvent:IsA("RemoteEvent") then
			pcall(function()
				GuideEvent:FireServer()
			end)
		else
			pcall(function()
				LocalPlayer:LoadCharacter()
			end)
		end

		RunService.Heartbeat:Wait()
		respawnDebounce = false
	end)
end

-----------------------------------------------------
-- CHARACTER BIND
-----------------------------------------------------

local function bindCharacter(char)
	Character = char
	Humanoid = char:WaitForChild("Humanoid")

	clearConnections()

	if not Humanoid then return end

	deathConn = Humanoid.Died:Connect(function()
		if Enabled then
			doRespawn()
		end
	end)
end

-----------------------------------------------------
-- ENABLE / DISABLE
-----------------------------------------------------

local function enable()
	if Enabled then return end
	Enabled = true

	if LocalPlayer.Character then
		bindCharacter(LocalPlayer.Character)
	end

	charConn = LocalPlayer.CharacterAdded:Connect(function(char)
		if Enabled then
			bindCharacter(char)
		end
	end)
end

local function disable()
	if not Enabled then return end
	Enabled = false

	clearConnections()

	if charConn then
		charConn:Disconnect()
		charConn = nil
	end
end

-----------------------------------------------------
-- UI
-----------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "UltraRespawnV5"
gui.ResetOnSpawn = false
gui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(200, 60)
panel.Position = UDim2.fromScale(0.5, 0.85)
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
panel.Active = true
panel.Draggable = true
panel.Parent = gui

Instance.new("UICorner", panel).CornerRadius = UDim.new(0, 16)

local stroke = Instance.new("UIStroke", panel)
stroke.Color = Color3.fromRGB(0, 255, 0)
stroke.Thickness = 1.5

local btn = Instance.new("TextButton")
btn.Size = UDim2.fromScale(1, 1)
btn.BackgroundTransparency = 1
btn.Font = Enum.Font.GothamBold
btn.TextSize = 16
btn.TextColor3 = Color3.fromRGB(0, 255, 0)
btn.Parent = panel

-----------------------------------------------------
-- UI UPDATE
-----------------------------------------------------

local function refreshUI()
	btn.Text = Enabled and "RESPAWN: ON" or "RESPAWN: OFF"

	TweenService:Create(
		stroke,
		TweenInfo.new(0.2),
		{
			Transparency = Enabled and 0.1 or 0.5
		}
	):Play()
end

-----------------------------------------------------
-- INPUT
-----------------------------------------------------

btn.MouseButton1Click:Connect(function()
	if Enabled then
		disable()
	else
		enable()
	end
	refreshUI()
end)

-----------------------------------------------------
-- KEYBIND
-----------------------------------------------------

game:GetService("UserInputService").InputBegan:Connect(function(input, gp)
	if gp then return end

	if input.KeyCode == Enum.KeyCode.R then
		if Enabled then
			disable()
		else
			enable()
		end
		refreshUI()
	end
end)

-----------------------------------------------------
-- CHARACTER INITIAL
-----------------------------------------------------

if LocalPlayer.Character then
	bindCharacter(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(char)
	if Enabled then
		bindCharacter(char)
	end
end)

refreshUI()

print("⚡ Ultra Respawn V5 Loaded (Stable Build)")