-- TFL Hub 

-- SERVICES
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local HttpService = game:GetService("HttpService")
local TextChatService = game:GetService("TextChatService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local Lighting = game:GetService("Lighting")

-- ======= User ID Verification System =======

local AUTHORIZED_USER_IDS = {
	[3816480506] = "Owner"
	[9407037318] = "Messi's main acc",
	[10282034542] = "Messi's alt acc",
	[1989950303] = "Lucky",
	[3687384835] = "Scar",
	[10520590654] = "Star",
	[4431183945] = "Jack",
	[3660679191] = "Sarah",
}

local function notify(title, text, duration)
	pcall(function()
		game:GetService("StarterGui"):SetCore("SendNotification", {
			Title = title,
			Text = text,
			Duration = duration or 5
		})
	end)
end

local function isUserAuthorized()
	local userId = LocalPlayer.UserId
	
	if AUTHORIZED_USER_IDS[userId] then
		return true, AUTHORIZED_USER_IDS[userId]
	end
	
	return false, nil
end

-- Perform verification
local authorized, authName = isUserAuthorized()

if not authorized then
	notify(
		"TFL Hub",
		"Verification Failed\nUnauthorized User",5)
	return
else
	notify(
		"Verification Passed",
		"Name - " .. tostring(authName) .. "\nEnjoy the hub",6)
end

local DEFAULT_THEME = {
	Accent = Color3.fromRGB(0, 255, 0),
	Background = Color3.fromRGB(0, 26, 10),
	Panel = Color3.fromRGB(10, 26, 10),
	Text = Color3.fromRGB(0, 255, 0),
	Muted = Color3.fromRGB(140, 180, 140),
	Radius = UDim.new(0, 12, 0),
	Shadows = true
}

local ANIM = { Time = 0.18, Style = Enum.EasingStyle.Quad, Direction = Enum.EasingDirection.Out }
local SETTINGS_FILE = "tflhub_settings.json"
local HUB_VERSION = "v2.0.0"
local WEBHOOK_URL = "https://discordapp.com/api/webhooks/1526381104481701971/9HwhYi3PVw0f0_k6jBwpCFCUJayYSK5Xx1tMZ8kpUDpiZyZqMt_YU_vwnW6Y2hzZDCsS"
local FEEDBACK_LOG_WEBHOOK = "https://discordapp.com/api/webhooks/1526437295782232096/jUl83emM_1G99xUu2hYxfMaMlpwI4HcUPPRdBxLK1eHhnjXOiwTBzIEhX2MSDBlpsrwX"

-- ======= Helpers (preserved & reused) =======
local function safe_pcall(fn, ...) 
	local ok, res = pcall(fn, ...) 
	return ok, res
end

local function tw(instance, props, t) 
	t = t or ANIM.Time 
	return TweenService:Create(instance, TweenInfo.new(t, ANIM.Style, ANIM.Direction), props) 
end

local function addRound(parent, radius) 
	local rc = Instance.new("UICorner") 
	rc.CornerRadius = radius or DEFAULT_THEME.Radius 
	rc.Parent = parent return rc 
end

local function addStroke(parent, color, thickness, transparency)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Color = color or Color3.fromRGB(0, 255, 0)
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = transparency or 0
	stroke.LineJoinMode = Enum.LineJoinMode.Round
	stroke.Parent = parent

	return stroke
end

-- ======= Settings (unchanged behavior) =======
local Settings = {
	AutoExecute = false,
	Theme = {
		Accent = DEFAULT_THEME.Accent,
		Background = DEFAULT_THEME.Background,
		Panel = DEFAULT_THEME.Panel,
		Text = DEFAULT_THEME.Text,
		Muted = DEFAULT_THEME.Muted
	},
	WalkSpeed = 16,
	JumpPower = 50
}

local function loadSettings()
	if typeof(writefile) == "function" and typeof(readfile) == "function" then
		local ok, content = pcall(function() return readfile(SETTINGS_FILE) end)
		if ok and content and #content > 0 then
			local ok2, parsed = pcall(function() return HttpService:JSONDecode(content) end)
			if ok2 and type(parsed) == "table" then
				for k,v in pairs(parsed) do Settings[k] = v end
				if Settings.Theme and type(Settings.Theme) == "table" then
					for tk, tv in pairs(Settings.Theme) do
						if type(tv) == "table" and tv.r then
							Settings.Theme[tk] = Color3.new(tv.r, tv.g, tv.b)
						end
					end
				end
			end
		end
	else
		if _G.TflHubSettings then
			for k,v in pairs(_G.TflHubSettings) do Settings[k] = v end
		end
	end
end

local function saveSettings()
	local copy = {
		AutoExecute = Settings.AutoExecute,
		WalkSpeed = Settings.WalkSpeed,
		JumpPower = Settings.JumpPower,
		Theme = {}
	}
	for k,v in pairs(Settings.Theme) do
		local c = v
		copy.Theme[k] = { r = c.R, g = c.G, b = c.B }
	end
	if typeof(writefile) == "function" and typeof(readfile) == "function" then
		local ok, err = pcall(function()
			writefile(SETTINGS_FILE, HttpService:JSONEncode(copy))
		end)
		if not ok then warn("TFL: failed to write settings:", err) end
	else
		_G.TflHubSettings = copy
	end
end

loadSettings()

-- ======= Remove old hub if present =======
if PlayerGui:FindFirstChild("TFLHubGui") then
	PlayerGui.TFLHubGui:Destroy()
end

-- ======= UI: ScreenGui & BALANCED MOBILE SCALING =======
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "TFLHubGui"
screenGui.DisplayOrder = 999
screenGui.IgnoreGuiInset = true
screenGui.ResetOnSpawn = false
screenGui.Parent = PlayerGui

local uiScale = Instance.new("UIScale")
uiScale.Parent = screenGui

---------------------------------------------------------------------
-- 🌋 BACKGROUND FX SYSTEM
---------------------------------------------------------------------

local blur = Instance.new("BlurEffect")
blur.Enabled = false
blur.Size = 0
blur.Parent = Lighting

local fxHolder = Instance.new("Frame")
fxHolder.Name = "BackgroundFX"
fxHolder.Size = UDim2.new(1,0,1,0)
fxHolder.BackgroundTransparency = 1
fxHolder.Visible = false
fxHolder.ZIndex = 0
fxHolder.Parent = screenGui

local fxGradient = Instance.new("Frame")
fxGradient.Size = UDim2.new(1,0,1,0)
fxGradient.BackgroundColor3 = Color3.fromRGB(0,0,0)
fxGradient.BackgroundTransparency = 0.35
fxGradient.BorderSizePixel = 0
fxGradient.Parent = fxHolder

local bgGrad = Instance.new("UIGradient")
bgGrad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0,20,0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0,0,0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0,40,0))
}
bgGrad.Rotation = 35
bgGrad.Parent = fxGradient

RunService.RenderStepped:Connect(function(dt)
	bgGrad.Offset = bgGrad.Offset + Vector2.new(0.01 * dt, 0)
end)

local particles = {}

local function createParticle()
	local p = Instance.new("Frame")

	local size = math.random(2,6)

	p.Size = UDim2.new(0,size,0,size)
	p.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	p.BorderSizePixel = 0
	p.AnchorPoint = Vector2.new(0.5,0.5)

	addRound(p, UDim.new(1,0))

	p.Position = UDim2.new(
		math.random(),
		0,
		1.1,
		0
	)

	p.BackgroundTransparency = math.random(20,70)/100

	p.ZIndex = 1
	p.Parent = fxHolder

	table.insert(particles, p)

	task.spawn(function()

		local speed = math.random(20,60)/100
		local drift = math.random(-20,20)/100

		while p.Parent and fxHolder.Visible do

			local pos = p.Position

			p.Position = UDim2.new(
				pos.X.Scale + (drift * 0.0005),
				0,
				pos.Y.Scale - (speed * 0.0025),
				0
			)

			p.Rotation = p.Rotation + 0.4

			if pos.Y.Scale <= -0.1 then
				p.Position = UDim2.new(math.random(),0,1.1,0)
			end

			RunService.RenderStepped:Wait()
		end

	end)
end

for i = 1,120 do
	createParticle()
end

local function computeScale()
	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280,720)
	local minDim = math.min(viewport.X, viewport.Y)

	if UserInputService.TouchEnabled then
		-- 📱 Mobile — tuned so the hub is BIG but NOT fullscreen
		local base = minDim / 720

		-- This range gives breathing room while still being readable
		return math.clamp(base, 0.85, 1.15)

	else
		-- 🖥 Desktop unchanged
		local base = minDim / 1200
		return math.clamp(base, 0.9, 1.1)
	end
end

local function updateScale()
	uiScale.Scale = computeScale()
end

updateScale()

workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(updateScale)

if workspace.CurrentCamera then
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(updateScale)
end

-- ======= Toast system (small animated popup) =======
local function showToast(msg, duration, animateDots)
	duration = duration or 2.2
	local toast = Instance.new("Frame")
	toast.Size = UDim2.new(0, 600, 0, 48)
	toast.Position = UDim2.new(0, 0, 0, 0)
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.BackgroundColor3 = Color3.fromRGB(10, 26, 10)
	toast.BorderSizePixel = 0
	toast.Parent = screenGui
	addRound(toast, UDim.new(0, 10))

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.Position = UDim2.new(0, 12, 0, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.Code
	label.TextSize = 18
	label.TextColor3 = Color3.fromRGB(0, 255, 0)
	label.TextXAlignment = Enum.TextXAlignment.Center
	label.TextYAlignment = Enum.TextYAlignment.Center
	label.Text = msg
	label.Parent = toast

	-- animate in
	tw(toast, {Position = UDim2.new(0.5, 0, 0.02, 0), Size = UDim2.new(0, 620, 0, 56)}, 0.22):Play()
	-- animate dots if requested
	local running = true
	local dotCo
	if animateDots then
		dotCo = coroutine.create(function()
			local base = msg
			local d = 0
			while running do
				local sdot = string.rep(".", (d%4))
				pcall(function() label.Text = base .. sdot end)
				d = d + 1
				task.wait(0.5)
			end
		end)
		coroutine.resume(dotCo)
	end

	task.delay(duration, function()
		running = false
		tw(toast, {Position = UDim2.new(0.5, -150, -0.2, 0), Size = UDim2.new(0, 280, 0, 44)}, 0.22):Play()
		task.delay(0.24, function() pcall(function() toast:Destroy() end) end)
	end)
end

-- ======= Main window (with animated open/close via chat) =======
local main = Instance.new("Frame")
main.Name = "Main"
main.Size = UDim2.new(0, 920, 0, 580)
main.Position = UDim2.new(0.5, 0, -1.2, 0) -- start hidden above screen
main.AnchorPoint = Vector2.new(0.5, 0.5)
main.BackgroundColor3 = Settings.Theme and Settings.Theme.Background or DEFAULT_THEME.Background
main.Parent = screenGui
addRound(main, DEFAULT_THEME.Radius)

-- border stroke
local stroke = addStroke(main, Color3.fromRGB(0, 255, 0), 1)

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 255, 0)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(0, 180, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 100, 0))
}
grad.Parent = stroke

-- animate rotation
RunService.RenderStepped:Connect(function(dt)
	grad.Rotation = grad.Rotation + dt * 60
end)

for i = 1,3 do
	local glow = Instance.new("UIStroke")
	glow.Thickness = 2 + (i * 2)
	glow.Transparency = 0.8
	glow.Color = Color3.fromRGB(0, 255, 0)
	glow.Parent = main
end

-- background
local bg = Instance.new("Frame")
bg.Size = UDim2.new(1,0,1,0)
bg.BackgroundColor3 = Color3.fromRGB(0, 10, 0)
bg.ZIndex = -1
bg.Parent = main

local grad = Instance.new("UIGradient")
grad.Color = ColorSequence.new{
	ColorSequenceKeypoint.new(0, Color3.fromRGB(0, 100, 0)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(0, 255, 0))
}
grad.Rotation = 45
grad.Parent = bg

RunService.RenderStepped:Connect(function(dt)
	grad.Offset = grad.Offset + Vector2.new(0.02 * dt, 0)
end)

for i = 1, 20 do
	local dot = Instance.new("Frame")
	dot.Size = UDim2.new(0, 2, 0, 2)
	dot.Position = UDim2.new(math.random(), 0, math.random(), 0)
	dot.BackgroundColor3 = Color3.fromRGB(0, 255, 0)
	dot.BackgroundTransparency = 0.6
	dot.Parent = main

	task.spawn(function()
		while dot.Parent do
			tw(dot, {
				Position = dot.Position + UDim2.new(0,0,-0.1,0)
			}, 3):Play()
			task.wait(3)
			dot.Position = UDim2.new(math.random(),0,1,0)
		end
	end)
end

-- header (keeps drag)
local header = Instance.new("Frame")
header.Name = "Header"
header.Size = UDim2.new(1, 0, 0, 68)
header.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
header.Parent = main
addRound(header, UDim.new(0, 12))
addStroke(header, DEFAULT_THEME.Accent, 1)

-- title and subtitle layout: move subtitle to the right of title for better visibility
local title = Instance.new("TextLabel")
title.Name = "Title"
title.Size = UDim2.new(0, 340, 1, 0)
title.Position = UDim2.new(0, 18, 0, 0)
title.BackgroundTransparency = 1
title.Text = "TFL HUB"
title.Font = Enum.Font.Code
title.TextSize = 20
title.TextColor3 = DEFAULT_THEME.Text
title.TextXAlignment = Enum.TextXAlignment.Left
title.Parent = header

local subtitle = Instance.new("TextLabel")
subtitle.Name = "Subtitle"
subtitle.Size = UDim2.new(0, 420, 1, 0)
subtitle.Position = UDim2.new(0, 175, 0, 8) -- to the right and slightly higher for visibility
subtitle.BackgroundTransparency = 1
subtitle.Text = "APOCALYPSE PROTOCOL"
subtitle.Font = Enum.Font.Code
subtitle.TextSize = 18
subtitle.TextColor3 = DEFAULT_THEME.Text
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.Parent = header

-- ======= Left sidebar =======
local sidebar = Instance.new("Frame")
sidebar.Name = "Sidebar"
sidebar.Size = UDim2.new(0, 220, 1, -92)
sidebar.Position = UDim2.new(0, 5, 0, 75)
sidebar.BackgroundColor3 = Settings.Theme and Settings.Theme.Panel or DEFAULT_THEME.Panel
sidebar.Parent = main
addRound(sidebar, UDim.new(0, 12))
addStroke(sidebar, DEFAULT_THEME.Accent, 1)

local sideLayout = Instance.new("UIListLayout")
sideLayout.Padding = UDim.new(0, 8)
sideLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
sideLayout.VerticalAlignment = Enum.VerticalAlignment.Top
sideLayout.SortOrder = Enum.SortOrder.LayoutOrder
sideLayout.Parent = sidebar

local sidePadding = Instance.new("UIPadding")
sidePadding.PaddingTop = UDim.new(0, 18)
sidePadding.PaddingLeft = UDim.new(0, 12)
sidePadding.PaddingRight = UDim.new(0, 12)
sidePadding.Parent = sidebar

-- Search box
local searchBox = Instance.new("TextBox")
searchBox.Name = "Search"
searchBox.Size = UDim2.new(1, -24, 0, 36)
searchBox.BackgroundColor3 = Color3.fromRGB(0, 20, 0)
searchBox.PlaceholderText = "Search..."
searchBox.Text = ""
searchBox.ClearTextOnFocus = false
searchBox.Font = Enum.Font.Code
searchBox.TextSize = 18
searchBox.TextColor3 = DEFAULT_THEME.Text
searchBox.PlaceholderColor3 = DEFAULT_THEME.Muted
searchBox.Parent = sidebar
addRound(searchBox, UDim.new(0, 8))
addStroke(searchBox, DEFAULT_THEME.Accent, 1)


-- Buttons holder (scrollable)
local buttonsHolder = Instance.new("ScrollingFrame")
buttonsHolder.Name = "Buttons"
buttonsHolder.Size = UDim2.new(1, 0, 1, -86)
buttonsHolder.BackgroundTransparency = 1
buttonsHolder.ScrollBarThickness = 6
buttonsHolder.CanvasSize = UDim2.new(0,0,0,0)
buttonsHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
buttonsHolder.VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar
buttonsHolder.Parent = sidebar

local buttonsLayout = Instance.new("UIListLayout")
buttonsLayout.Padding = UDim.new(0, 10)
buttonsLayout.SortOrder = Enum.SortOrder.LayoutOrder
buttonsLayout.Parent = buttonsHolder

-- ======= Content area =======
local content = Instance.new("Frame")
content.Name = "Content"
content.Size = UDim2.new(1, -240, 1, -92)
content.Position = UDim2.new(0, 232, 0, 75)
content.BackgroundColor3 = Settings.Theme and Settings.Theme.Panel or DEFAULT_THEME.Panel
content.Parent = main
addRound(content, UDim.new(0, 12))
addStroke(content, DEFAULT_THEME.Accent, 1)

local contentPadding = Instance.new("UIPadding")
contentPadding.PaddingTop = UDim.new(0, 18)
contentPadding.PaddingLeft = UDim.new(0, 18)
contentPadding.PaddingRight = UDim.new(0, 18)
contentPadding.Parent = content

local pageTitle = Instance.new("TextLabel")
pageTitle.Name = "PageTitle"
pageTitle.Size = UDim2.new(1, 0, 0, 36)
pageTitle.BackgroundTransparency = 1
pageTitle.Font = Enum.Font.Code
pageTitle.TextSize = 18
pageTitle.TextColor3 = DEFAULT_THEME.Text
pageTitle.Text = "Welcome"
pageTitle.TextXAlignment = Enum.TextXAlignment.Left
pageTitle.Parent = content

local pageArea = Instance.new("Frame")
pageArea.Name = "PageArea"
pageArea.Size = UDim2.new(1, 0, 1, -56)
pageArea.Position = UDim2.new(0, 0, 0, 40)
pageArea.BackgroundTransparency = 1
pageArea.ClipsDescendants = true
pageArea.Parent = content

-- ======= Pages system (keeps original behaviour) =======
local Pages, currentPageName = {}, nil
local function createPage(name)
	local p = Instance.new("ScrollingFrame")
	p.Name = name
	p.Size = UDim2.new(1, 0, 1, 0)
	p.Position = UDim2.new(1, 0, 0, 0)
	p.BackgroundTransparency = 1
	p.ScrollBarThickness = 8
	p.CanvasSize = UDim2.new(0,0,0,0)
	p.AutomaticCanvasSize = Enum.AutomaticSize.Y
	p.Parent = pageArea

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 10)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = p

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 6)
	padding.PaddingLeft = UDim.new(0, 6)
	padding.PaddingRight = UDim.new(0, 6)
	padding.Parent = p

	Pages[name] = p
	return p
end

local function showPage(name)
	if currentPageName == name then return end
	local old = currentPageName and Pages[currentPageName] or nil
	local new = Pages[name]
	if not new then return end
	pageTitle.Text = name
	currentPageName = name

	if old then tw(old, {Position = UDim2.new(-1,0,0,0)}):Play() end
	new.Position = UDim2.new(1,0,0,0)
	tw(new, {Position = UDim2.new(0,0,0,0)}):Play()
	if old then
		task.delay(ANIM.Time + 0.02, function()
			if old and old.Parent then old.Position = UDim2.new(1,0,0,0) end
		end)
	end
end

-- ======= Sidebar button creator (preserved) =======
local function createSidebarButton(titleText, order)
	local btnHolder = Instance.new("Frame")
	btnHolder.Name = titleText .. "Btn"
	btnHolder.Size = UDim2.new(1, 0, 0, 55)
	btnHolder.BackgroundTransparency = 1
	btnHolder.LayoutOrder = order or 1
	btnHolder.Parent = buttonsHolder

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 155, 0, 55)
	btn.Position = UDim2.new(0, 10, 0, 5)
	btn.BackgroundColor3 = Color3.fromRGB(0, 10, 0)
	btn.AutoButtonColor = false
	btn.Text = ""
	btn.Parent = btnHolder
	addRound(btn, UDim.new(0, 10))
	addStroke(btn, DEFAULT_THEME.Accent, 1)

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -70, 1, 0)
	label.Position = UDim2.new(0, 12, 0, -8)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.Code
	label.TextSize = 15
	label.TextColor3 = DEFAULT_THEME.Text
	label.Text = titleText
	label.Parent = btn

	local sub = Instance.new("TextLabel")
	sub.Size = UDim2.new(1, -70, 1, 0)
	sub.Position = UDim2.new(0, 12, 0, 12)
	sub.BackgroundTransparency = 1
	sub.TextXAlignment = Enum.TextXAlignment.Left
	sub.Font = Enum.Font.Code
	sub.TextSize = 11
	label.TextColor3 = DEFAULT_THEME.Text
	sub.Text = "Open " .. titleText
	sub.Parent = btn

	local accent = Instance.new("Frame")
	accent.Size = UDim2.new(0, 6, 1, -8)
	accent.Position = UDim2.new(1, -14, 0, 4)
	accent.AnchorPoint = Vector2.new(1, 0)
	accent.BackgroundColor3 = Settings.Theme and Settings.Theme.Accent or DEFAULT_THEME.Accent
	accent.Parent = btn
	addRound(accent, UDim.new(0, 6))
	accent.Visible = false

	btn.MouseEnter:Connect(function()

		tw(btn, {
			BackgroundColor3 = Color3.fromRGB(0, 40, 0)
		}, 0.12):Play()

	end)

	btn.MouseLeave:Connect(function()

		tw(btn, {
			BackgroundColor3 = Color3.fromRGB(0, 10, 0)
		}, 0.12):Play()

	end)

	btn.MouseButton1Click:Connect(function()
		showPage(titleText)
		for _, child in ipairs(buttonsHolder:GetChildren()) do
			if child:IsA("Frame") then
				local b = child:FindFirstChildWhichIsA("TextButton")
				if b then
					local f = b:FindFirstChildWhichIsA("Frame")
					if f then f.Visible = false end
				end
			end
		end
		accent.Visible = true
		tw(accent, {Size = UDim2.new(0, 6, 1, -8)}):Play()
	end)

	return { Holder = btnHolder, Button = btn, SetSubText = function(txt) sub.Text = txt end, SetAccent = function(on) accent.Visible = on end }
end

-- ======= Toggle helper =======
local function createToggle(labelText, initial)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 46)
	row.BackgroundTransparency = 1

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.6, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.Font = Enum.Font.Code
	lbl.TextSize = 15
	lbl.TextColor3 = DEFAULT_THEME.Text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local togg = Instance.new("Frame")
	togg.Size = UDim2.new(0, 58, 0, 28)
	togg.AnchorPoint = Vector2.new(1, 0)
	togg.Position = UDim2.new(1, -6, 0, 8)
	togg.BackgroundColor3 = Color3.fromRGB(0, 40, 46)
	addRound(togg, UDim.new(0, 14))
	togg.Parent = row

	local circle = Instance.new("Frame")
	circle.Size = UDim2.new(0, 24, 0, 24)
	circle.Position = UDim2.new(0, 4, 0, 2)
	circle.BackgroundColor3 = Color3.fromRGB(230,230,230)
	addRound(circle, UDim.new(0, 12))
	circle.Parent = togg

	local state = initial and true or false
	local function setState(v)
		state = not not v
		if state then
			tw(togg, {BackgroundColor3 = Settings.Theme and Settings.Theme.Accent or DEFAULT_THEME.Accent}):Play()
			tw(circle, {Position = UDim2.new(1, -28, 0, 2)}):Play()
			circle.BackgroundColor3 = Color3.fromRGB(255,255,255)
		else
			tw(togg, {BackgroundColor3 = Color3.fromRGB(0, 40, 46)}):Play()
			tw(circle, {Position = UDim2.new(0, 4, 0, 2)}):Play()
			circle.BackgroundColor3 = Color3.fromRGB(230,230,230)
		end
	end

	togg.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			setState(not state)
		end
	end)

	setState(state)
	return row, function() return state end, setState
end

-- ======= Action button helper =======
local function createActionButton(textLabel, url)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 48)
	row.BackgroundTransparency = 1

	local actBtn = Instance.new("TextButton")
	actBtn.Size = UDim2.new(0, 160, 1, 0)
	actBtn.Position = UDim2.new(0, 0, 0, 0)
	actBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	actBtn.TextColor3 = Color3.new(0, 255, 0)
	actBtn.Text = textLabel
	actBtn.Font = Enum.Font.Code
	actBtn.TextSize = 18
	actBtn.TextColor3 = DEFAULT_THEME.Text
	actBtn.Parent = row
	addRound(actBtn, UDim.new(0, 10))
	addStroke(actBtn, DEFAULT_THEME.Accent, 1)

	local running = false
	actBtn.MouseButton1Click:Connect(function()
		if running then return end
		running = true
		local oldText = actBtn.Text
		actBtn.Text = "Running..."
		actBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
		task.spawn(function()
			local ok, res = pcall(function()
				if type(url) ~= "string" then error("Invalid URL") end
				local content
				local ok2, err2 = pcall(function()
					content = game:HttpGet(url, true)
				end)
				if not ok2 then error("HttpGet failed: "..tostring(err2)) end
				local f, err = loadstring(content)
				if not f then error("loadstring failed: "..tostring(err)) end
				local ran, rerr = pcall(function() f() end)
				if not ran then error("remote script error: "..tostring(rerr)) end
				return true
			end)
			if ok then
				actBtn.Text = "Done"
				tw(actBtn, {Size = UDim2.new(0, 160, 1, 0)}, 0.12):Play()
				wait(0.8)
				actBtn.Text = oldText
				actBtn.BackgroundColor3 = Color3.fromRGB(0,0,0)
			else
				warn("[TFLHub] Action failed:", res)
				actBtn.Text = "Error"
				actBtn.BackgroundColor3 = Color3.fromRGB(0, 100, 0)
				wait(1.2)
				actBtn.Text = oldText
				actBtn.BackgroundColor3 = Color3.fromRGB(0,0,0)
			end
			running = false
		end)
	end)
	return row
end

-- ======= Pages & content (kept from original) =======
local pageWelcome = createPage("Welcome")
local welcomeText = Instance.new("TextLabel")
welcomeText.Size = UDim2.new(1, -24, 0, 120)
welcomeText.BackgroundTransparency = 1
welcomeText.TextWrapped = true
welcomeText.TextXAlignment = Enum.TextXAlignment.Left
welcomeText.Font = Enum.Font.Code
welcomeText.TextSize = 18
welcomeText.TextColor3 = DEFAULT_THEME.Text
welcomeText.Text = "Welcome to the TFL Hub. Made by TFL Fromer Leader, Dyllan. Note that this hub will no longer recieve updates with Me gone, and I will also not return. Enjoy the scripts. Hopefully it's 'Strong' enough for you all. Goodbye, and Good luck. - Dyllan"
welcomeText.Parent = pageWelcome

local Welcome = {
	{"Get Base", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Get%20Base.lua"},
	{"Respawn", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Respawn.lua"},
	{"Get Tools", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Tool%20Grabber.lua"},
}

for i, t in ipairs(Welcome) do
	local row = createActionButton(t[1], t[2])
	row.LayoutOrder = 10 + i
	row.Parent = pageWelcome
end

-- ======= Updates page (scrollable changelog) =======
local updatesPage = createPage("Updates")
local updatesScroll = Instance.new("ScrollingFrame")
updatesScroll.Size = UDim2.new(1, 0, 1, 0)
updatesScroll.Position = UDim2.new(0, 0, 0, 0)
updatesScroll.BackgroundTransparency = 1
updatesScroll.ScrollBarThickness = 8
updatesScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
updatesScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
updatesScroll.Parent = updatesPage

local updatesLayout = Instance.new("UIListLayout")
updatesLayout.Padding = UDim.new(0, 12)
updatesLayout.SortOrder = Enum.SortOrder.LayoutOrder
updatesLayout.Parent = updatesScroll

local updatesPadding = Instance.new("UIPadding")
updatesPadding.PaddingTop = UDim.new(0, 8)
updatesPadding.PaddingLeft = UDim.new(0, 8)
updatesPadding.PaddingRight = UDim.new(0, 8)
updatesPadding.Parent = updatesScroll

local function addUpdateEntry(version, date, notes)
	local entry = Instance.new("Frame")
	entry.Size = UDim2.new(1, -4, 0, 0)
	entry.BackgroundColor3 = Color3.fromRGB(0, 20, 0)
	entry.BorderSizePixel = 0
	entry.AutomaticSize = Enum.AutomaticSize.Y
	entry.Parent = updatesScroll
	addRound(entry, UDim.new(0, 10))
	addStroke(entry, DEFAULT_THEME.Accent, 1)

	local headerFrame = Instance.new("Frame")
	headerFrame.Size = UDim2.new(1, 0, 0, 36)
	headerFrame.BackgroundTransparency = 1
	headerFrame.Parent = entry

	local versionLabel = Instance.new("TextLabel")
	versionLabel.Size = UDim2.new(0.5, -6, 1, 0)
	versionLabel.Position = UDim2.new(0, 12, 0, 0)
	versionLabel.BackgroundTransparency = 1
	versionLabel.Font = Enum.Font.Code
	versionLabel.TextSize = 20
	versionLabel.TextColor3 = DEFAULT_THEME.Accent
	versionLabel.TextXAlignment = Enum.TextXAlignment.Left
	versionLabel.TextYAlignment = Enum.TextYAlignment.Center
	versionLabel.Text = version
	versionLabel.Parent = headerFrame

	local dateLabel = Instance.new("TextLabel")
	dateLabel.Size = UDim2.new(0.5, -6, 1, 0)
	dateLabel.Position = UDim2.new(0.5, 6, 0, 0)
	dateLabel.BackgroundTransparency = 1
	dateLabel.Font = Enum.Font.Code
	dateLabel.TextSize = 16
	dateLabel.TextColor3 = DEFAULT_THEME.Muted
	dateLabel.TextXAlignment = Enum.TextXAlignment.Right
	dateLabel.TextYAlignment = Enum.TextYAlignment.Center
	dateLabel.Text = date
	dateLabel.Parent = headerFrame

	local divider = Instance.new("Frame")
	divider.Size = UDim2.new(1, -24, 0, 1)
	divider.Position = UDim2.new(0, 12, 0, 36)
	divider.BackgroundColor3 = DEFAULT_THEME.Accent
	divider.BackgroundTransparency = 0.6
	divider.BorderSizePixel = 0
	divider.Parent = entry

	local notesLabel = Instance.new("TextLabel")
	notesLabel.Size = UDim2.new(1, -24, 0, 0)
	notesLabel.Position = UDim2.new(0, 12, 0, 44)
	notesLabel.BackgroundTransparency = 1
	notesLabel.Font = Enum.Font.Code
	notesLabel.TextSize = 17
	notesLabel.TextColor3 = DEFAULT_THEME.Text
	notesLabel.TextXAlignment = Enum.TextXAlignment.Left
	notesLabel.TextYAlignment = Enum.TextYAlignment.Top
	notesLabel.TextWrapped = true
	notesLabel.RichText = true
	notesLabel.AutomaticSize = Enum.AutomaticSize.Y
	notesLabel.Text = notes
	notesLabel.Parent = entry

	-- Adjust entry size to fit content
	local function updateEntrySize()
		local h = 48 + notesLabel.TextBounds.Y + 8
		entry.Size = UDim2.new(1, -4, 0, math.max(60, h))
	end
	notesLabel:GetPropertyChangedSignal("TextBounds"):Connect(updateEntrySize)
	task.spawn(updateEntrySize)
end

-- Update entries — add as many as you want!
addUpdateEntry("v1.2.0", "2026-07-13", "• Added Feedback page\n• Players can now submit feedback directly to the hub owner for him to read and respond to\n• Feedback form includes username, script selection dropdown, and feedback text area\n• All 3 fields are required with validation\n• Automatically detects game name, executor, player info, and more\n• Added rules section to prevent abuse\n• Feedback page is the last sidebar button\n• Fixed dropdown visibility - all options now display correctly\n• Improved executor detection for modern executors (Solara, JJsploit, Hydrogen)\n• Added unique feedback ID (TFL_XXXXXXXXXX format) for tracking\n• Added second webhook for simplified feedback log")
addUpdateEntry("v1.10", "2026-07-12", "• Thank you to all of those who have supported me (Dyllan) in the making of the TFL Hub, and Scripts. and to those of you who were true friends and didn't use me for my scripts. I will not be returning, and this is my final decision. Thank you all for your support, and goodbye. - Dyllan")
addUpdateEntry("v1.1.0", "2026-07-12", "• Added the Updates page with scrollable changelog\n• Updates page is now the first page you see when opening the hub\n• Reorganized sidebar — Updates button is now at the top.\n• Fixed noclip not working correctly, it now works fine after testing. Enjoy!")

-- ============================================================================
-- TFL HUB V2 UPDATE - 2026-07-20
-- ============================================================================
addUpdateEntry("v2.0.0", "2026-07-20", "• **MAJOR OPTIMIZATION UPDATE**\n\n**Use Tools.lua:**\n• Fixed critical syntax errors and undefined function calls\n• Instant tool activation on enable - no delays\n• Single equip on activation, no re-equipping loops\n• PreSimulation timing for maximum responsiveness\n• Pre-allocated buffers to reduce GC pressure\n• Optimized Guide() function with minimal delay for respawn\n• Removed burst firing to prevent network overflow\n\n**Tool Grabber.lua:**\n• Removed excessive thread spawning (task.spawn)\n• Batched touch events instead of parallel threads\n• Better connection management\n• Immediate tool acquisition on character spawn\n\n**Kill Aura.lua:**\n• Fixed syntax error `if part or then`\n• Fixed extra `end` statement\n• PreSimulation timing for better responsiveness\n• Pre-allocated target parts buffer\n\n**Damage.lua:**\n• Added player caching to reduce per-frame iteration\n• Only runs when enabled\n• Smart cache invalidation\n\n**Loop Tools.lua:**\n• Removed `task.wait(0.1)` and `task.wait(0.05)` delays\n• PreSimulation timing\n• Immediate tool cache updates\n\n**Loopbring.lua:**\n• Fixed `+=` operator syntax errors\n• PreSimulation timing\n• Better connection management\n\n**Loopkill.lua:**\n• PreSimulation timing\n• Connection management\n• Removed unnecessary delays\n\n**Anti-Aura Shield.lua:**\n• Added proper connection tracking\n• PreSimulation timing\n• Cleanup function for memory management\n\n**Damage Amplifier Field.lua:**\n• PreSimulation timing\n• Connection management\n• Cleanup function\n\n**Hit Amplifier.lua:**\n• PreSimulation timing\n• Better tool caching\n• Connection management\n\n**Insta-Kill.lua:**\n• Reduced spawn burst time (2.0s → 0.5s)\n• Reduced burst count (10 → 5)\n• PreSimulation timing\n• Pre-allocated buffers\n\n**Get Base.lua:**\n• Added rate limiting (0.5s interval)\n• PreSimulation timing\n• Connection management\n\n**Grip.lua:**\n• PreSimulation timing\n• Removed `wait(1)` delay\n• Better tool handling\n\n**Axe Smash.lua:**\n• PreSimulation timing\n• Cached tool/remote lookups\n• Connection management\n\n**Respawn.lua:**\n• Added Guide() integration for instant re-equip\n• Added cooldown to prevent multi-firing (0.3s)\n• Heartbeat wait for better ping handling\n• Network-efficient respawn\n\nAll scripts now follow professional Roblox Luau engineering practices with maximum responsiveness, minimal CPU usage, network stability, and proper cleanup.")

-- Tools / Player / Other / Settings pages: preserved
local toolsPage = createPage("Tool Scripts")
local toolsHeader = Instance.new("TextLabel")
toolsHeader.Size = UDim2.new(1, -24, 0, 26)
toolsHeader.BackgroundTransparency = 1
toolsHeader.Font = Enum.Font.Code
toolsHeader.TextSize = 16
toolsHeader.TextColor3 = DEFAULT_THEME.Text
toolsHeader.TextXAlignment = Enum.TextXAlignment.Left
toolsHeader.Text = "Tool Scripts"
toolsHeader.Parent = toolsPage

local tools = {
	{"No Cooldown", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/No%20Cooldown.lua"},
	{"Insta-Kill", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Insta-Kill.lua"},
	{"Use Tools", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Use%20Tools.lua"},
	{"Hit Amplifier", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Hit%20Amplifier.lua"},
	{"Loop Tools", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Loop%20Tools.lua"},
}

for i, t in ipairs(tools) do
	local row = createActionButton(t[1], t[2])
	row.LayoutOrder = 10 + i
	row.Parent = toolsPage
end

local playerPage = createPage("Player Scripts")
local pHeader = Instance.new("TextLabel")
pHeader.Size = UDim2.new(1, -24, 0, 26)
pHeader.BackgroundTransparency = 1
pHeader.Font = Enum.Font.Code
pHeader.TextSize = 16
pHeader.TextColor3 = DEFAULT_THEME.Text
pHeader.TextXAlignment = Enum.TextXAlignment.Left
pHeader.Text = "Player Scripts"
pHeader.Parent = playerPage

local playerScripts = {
	{"Hitbox", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Damage.lua"},
	{"Loopbring", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Loopbring.lua"},
	{"Kill Aura", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Kill%20Aura.lua"},
	{"Loopkill", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Loopkill.lua"},
	{"Anti-Lag", "https://pastefy.app/vppgT4ae/raw"},
}

for i,t in ipairs(playerScripts) do
	local row = createActionButton(t[1], t[2])
	row.LayoutOrder = 10 + i
	row.Parent = playerPage
end

local otherPage = createPage("Other Scripts")
local oHeader = Instance.new("TextLabel")
oHeader.Size = UDim2.new(1, -24, 0, 26)
oHeader.BackgroundTransparency = 1
oHeader.Font = Enum.Font.Code
oHeader.TextSize = 16
oHeader.TextColor3 = DEFAULT_THEME.Text
oHeader.TextXAlignment = Enum.TextXAlignment.Left
oHeader.Text = "Other Scripts"
oHeader.Parent = otherPage

local otherScripts = {
	{"Infinite Yield", "https://raw.githubusercontent.com/EdgeIY/infiniteyield/master/source"},
	{"Anti-Aura", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Anti-Aura%20Shield.lua"},
	{"Damage Amplifier", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Damage%20Amplifier%20Field.lua"},
	{"Grip", "https://raw.githubusercontent.com/iamrobloxstudio/OG1-Hub-Scripts/refs/heads/main/Grip.lua"},
	{"Axe Smash Spam", "https://pastefy.app/CvywWIZ9/raw"},
	{"Emote GUI", "https://pastefy.app/T4YoBRGj/raw"},
}

for i,t in ipairs(otherScripts) do
	local row = createActionButton(t[1], t[2])
	row.LayoutOrder = 10 + i
	row.Parent = otherPage
end

-- Settings page (preserved sliders + restore buttons)
local settingsPage = createPage("Settings")
local sHeader = Instance.new("TextLabel")
sHeader.Size = UDim2.new(1, -24, 0, 26)
sHeader.BackgroundTransparency = 1
sHeader.Font = Enum.Font.Code
sHeader.TextSize = 16
sHeader.TextColor3 = DEFAULT_THEME.Text
sHeader.TextXAlignment = Enum.TextXAlignment.Left
sHeader.Text = "Settings"
sHeader.Parent = settingsPage

local autoRow, getAutoState, setAutoState = createToggle("Auto Execute Hub on Rejoin", Settings.AutoExecute)
autoRow.LayoutOrder = 2
autoRow.Parent = settingsPage
task.spawn(function()
	while settingsPage.Parent do
		Settings.AutoExecute = getAutoState()
		saveSettings()
		task.wait(0.6)
	end
end)

-- Slider factory (kept)
local function createSlider(labelText, min, max, initial)
	local row = Instance.new("Frame")
	row.Size = UDim2.new(1, 0, 0, 56)
	row.BackgroundTransparency = 1

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(0.6, 0, 0, 18)
	lbl.BackgroundTransparency = 1
	lbl.Text = labelText
	lbl.Font = Enum.Font.Code
	lbl.TextSize = 18
	lbl.TextColor3 = DEFAULT_THEME.Text
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.Parent = row

	local valueLbl = Instance.new("TextLabel")
	valueLbl.Size = UDim2.new(0.4, -6, 0, 18)
	valueLbl.Position = UDim2.new(0.6, 6, 0, 0)
	valueLbl.BackgroundTransparency = 1
	valueLbl.Text = tostring(initial)
	valueLbl.Font = Enum.Font.Code
	valueLbl.TextSize = 18
	valueLbl.TextColor3 = DEFAULT_THEME.Text
	valueLbl.TextXAlignment = Enum.TextXAlignment.Right
	valueLbl.Parent = row

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0, 14)
	bar.Position = UDim2.new(0, 0, 0, 28)
	bar.BackgroundColor3 = Color3.fromRGB(0, 40, 0)
	bar.Parent = row
	addRound(bar, UDim.new(0, 8))

	local fill = Instance.new("Frame")
	fill.Size = UDim2.new((initial - min)/(max - min), 0, 1, 0)
	fill.BackgroundColor3 = Settings.Theme and Settings.Theme.Accent or DEFAULT_THEME.Accent
	fill.Parent = bar
	addRound(fill, UDim.new(0, 8))

	local dragging = false
	local function setToPercent(p)
		p = math.clamp(p, 0, 1)
		fill.Size = UDim2.new(p, 0, 1, 0)
		local val = math.floor(min + p * (max - min) + 0.5)
		valueLbl.Text = tostring(val)
		return val
	end

	local function updateFromPos(px)
		local barPos = bar.AbsolutePosition
		local barSize = bar.AbsoluteSize
		local p = (px - barPos.X) / (barSize.X)
		return setToPercent(p)
	end

	bar.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			local conn
			conn = UserInputService.InputChanged:Connect(function(inp)
				if dragging and inp.Position then
					updateFromPos(inp.Position.X)
				end
			end)
			repeat
				local pos = UserInputService:GetMouseLocation()
				updateFromPos(pos.X)
				task.wait()
			until not dragging
			conn:Disconnect()
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	setToPercent((initial - min)/(max - min))
	return row, function() return tonumber(valueLbl.Text) end, function(v) setToPercent((v-min)/(max-min)) end
end

local walkRow, getWalkVal, setWalkVal = createSlider("Player WalkSpeed", 8, 500, Settings.WalkSpeed or 16)
walkRow.LayoutOrder = 10
walkRow.Parent = settingsPage

local jumpRow, getJumpVal, setJumpVal = createSlider("Player JumpPower", 20, 500, Settings.JumpPower or 50)
jumpRow.LayoutOrder = 11
jumpRow.Parent = settingsPage

task.spawn(function()
	while true do
		Settings.WalkSpeed = getWalkVal()
		Settings.JumpPower = getJumpVal()
		local char = LocalPlayer.Character
		if char and char:FindFirstChildWhichIsA("Humanoid") then
			local hum = char:FindFirstChildWhichIsA("Humanoid")
			if hum then
				hum.WalkSpeed = Settings.WalkSpeed
				hum.JumpPower = Settings.JumpPower
			end
		end
		saveSettings()
		task.wait(0.3)
	end
end)

local function addRestoreButton(text, callback, order)
	local resBtn = Instance.new("TextButton")
	resBtn.Size = UDim2.new(0, 160, 0, 28)
	resBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	resBtn.Text = text
	resBtn.Font = Enum.Font.Code
	resBtn.TextSize = 13
	resBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
	resBtn.Parent = settingsPage
	resBtn.LayoutOrder = order
	addRound(resBtn, UDim.new(0, 8))
	addStroke(resBtn, DEFAULT_THEME.Accent, 1)
	resBtn.MouseButton1Click:Connect(callback)
end

addRestoreButton("Restore WalkSpeed", function() setWalkVal(16) end, 30)
addRestoreButton("Restore JumpPower", function() setJumpVal(50) end, 31)

local rejoinBtn = Instance.new("TextButton")
rejoinBtn.Size = UDim2.new(0, 160, 0, 36)
rejoinBtn.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
rejoinBtn.Text = "🔄 Rejoin Server"
rejoinBtn.Font = Enum.Font.Code
rejoinBtn.TextSize = 18
rejoinBtn.TextColor3 = Color3.fromRGB(0, 255, 0)
rejoinBtn.Parent = settingsPage
rejoinBtn.LayoutOrder = 40
addRound(rejoinBtn, UDim.new(0, 8))
addStroke(rejoinBtn, DEFAULT_THEME.Accent, 1)

rejoinBtn.MouseButton1Click:Connect(function()
	local TeleportService = game:GetService("TeleportService")
	local LocalPlayer = Players.LocalPlayer
	TeleportService:Teleport(game.PlaceId, LocalPlayer)
end)

-- ======= Feedback page with Discord webhook =======
local MarketplaceService = game:GetService("MarketplaceService")
local feedbackConnections = {}

local function cleanupFeedback()
	for _, conn in ipairs(feedbackConnections) do
		pcall(function() conn:Disconnect() end)
	end
	table.clear(feedbackConnections)
end

-- Override showPage to add cleanup when leaving Feedback page
local origShowPage = showPage
showPage = function(name)
	if currentPageName == "Feedback" and name ~= "Feedback" then
		cleanupFeedback()
	end
	origShowPage(name)
end

local fbPage = createPage("Feedback")
local fbContent = Instance.new("ScrollingFrame")
fbContent.Size = UDim2.new(1, 0, 1, 0)
fbContent.BackgroundTransparency = 1
fbContent.ScrollBarThickness = 8
fbContent.CanvasSize = UDim2.new(0, 0, 0, 0)
fbContent.AutomaticCanvasSize = Enum.AutomaticSize.Y
fbContent.Parent = fbPage

local fbLayout = Instance.new("UIListLayout")
fbLayout.Padding = UDim.new(0, 10)
fbLayout.SortOrder = Enum.SortOrder.LayoutOrder
fbLayout.Parent = fbContent

local fbPadding = Instance.new("UIPadding")
fbPadding.PaddingTop = UDim.new(0, 6)
fbPadding.PaddingLeft = UDim.new(0, 6)
fbPadding.PaddingRight = UDim.new(0, 6)
fbPadding.Parent = fbContent

-- Helper to create a styled input section
local function createInputSection(title, hint)
	local section = Instance.new("Frame")
	section.Size = UDim2.new(1, -4, 0, 0)
	section.BackgroundColor3 = Color3.fromRGB(0, 20, 0)
	section.BorderSizePixel = 0
	section.AutomaticSize = Enum.AutomaticSize.Y
	section.Parent = fbContent
	addRound(section, UDim.new(0, 10))
	addStroke(section, DEFAULT_THEME.Accent, 1)

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, -20, 0, 30)
	titleLabel.Position = UDim2.new(0, 10, 0, 6)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Font = Enum.Font.Code
	titleLabel.TextSize = 17
	titleLabel.TextColor3 = DEFAULT_THEME.Accent
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.TextYAlignment = Enum.TextYAlignment.Center
	titleLabel.Text = title
	titleLabel.Parent = section

	if hint then
		local hintLabel = Instance.new("TextLabel")
		hintLabel.Size = UDim2.new(1, -20, 0, 20)
		hintLabel.Position = UDim2.new(0, 10, 0, 30)
		hintLabel.BackgroundTransparency = 1
		hintLabel.Font = Enum.Font.Code
		hintLabel.TextSize = 12
		hintLabel.TextColor3 = DEFAULT_THEME.Muted
		hintLabel.TextXAlignment = Enum.TextXAlignment.Left
		hintLabel.TextYAlignment = Enum.TextYAlignment.Top
		hintLabel.Text = hint
		hintLabel.Parent = section
	end

	return section
end

-- Rules section
local rulesSection = Instance.new("Frame")
rulesSection.Size = UDim2.new(1, -4, 0, 0)
rulesSection.BackgroundColor3 = Color3.fromRGB(5, 15, 5)
rulesSection.BorderSizePixel = 0
rulesSection.AutomaticSize = Enum.AutomaticSize.Y
rulesSection.Parent = fbContent
addRound(rulesSection, UDim.new(0, 10))
addStroke(rulesSection, DEFAULT_THEME.Muted, 0.5)

local rulesTitle = Instance.new("TextLabel")
rulesTitle.Size = UDim2.new(1, -20, 0, 26)
rulesTitle.Position = UDim2.new(0, 10, 0, 6)
rulesTitle.BackgroundTransparency = 1
rulesTitle.Font = Enum.Font.Code
rulesTitle.TextSize = 16
rulesTitle.TextColor3 = DEFAULT_THEME.Accent
rulesTitle.TextXAlignment = Enum.TextXAlignment.Left
rulesTitle.Text = "📋 Feedback Rules"
rulesTitle.Parent = rulesSection

local rulesText = Instance.new("TextLabel")
rulesText.Size = UDim2.new(1, -20, 0, 0)
rulesText.Position = UDim2.new(0, 10, 0, 34)
rulesText.BackgroundTransparency = 1
rulesText.Font = Enum.Font.Code
rulesText.TextSize = 14
rulesText.TextColor3 = DEFAULT_THEME.Muted
rulesText.TextXAlignment = Enum.TextXAlignment.Left
rulesText.TextYAlignment = Enum.TextYAlignment.Top
rulesText.TextWrapped = true
rulesText.AutomaticSize = Enum.AutomaticSize.Y
rulesText.Text = "• Do NOT submit spam, false, or troll feedback.\n• Be respectful and constructive with your feedback.\n• All submissions are logged with your username, Place ID, and Job ID.\n• Abuse of this system may result in restricted access.\n• By submitting, you agree to provide honest and helpful feedback."
rulesText.Parent = rulesSection

-- Username input
local nameSection = createInputSection("Username", "Enter your in-game username (required)")
local nameBox = Instance.new("TextBox")
nameBox.Size = UDim2.new(1, -20, 0, 36)
nameBox.Position = UDim2.new(0, 10, 0, 52)
nameBox.BackgroundColor3 = Color3.fromRGB(0, 10, 0)
nameBox.PlaceholderText = "Your username..."
nameBox.Text = ""
nameBox.ClearTextOnFocus = false
nameBox.Font = Enum.Font.Code
nameBox.TextSize = 16
nameBox.TextColor3 = DEFAULT_THEME.Text
nameBox.PlaceholderColor3 = DEFAULT_THEME.Muted
nameBox.Parent = nameSection
addRound(nameBox, UDim.new(0, 8))
addStroke(nameBox, DEFAULT_THEME.Accent, 1)

-- Reason for feedback dropdown
local reasonSection = createInputSection("Reason for Feedback", "Select the reason for your submission (required)")
local reasonOptions = {
	"-- Select a Reason --", "Script Bug Report", "Script Suggestion", "General Feedback", "Other"
}
local selectedReason = reasonOptions[1]
local reasonDropdownOpen = false
local reasonDropdownFrame

local reasonBtn = Instance.new("TextButton")
reasonBtn.Size = UDim2.new(1, -20, 0, 36)
reasonBtn.Position = UDim2.new(0, 10, 0, 52)
reasonBtn.BackgroundColor3 = Color3.fromRGB(0, 10, 0)
reasonBtn.AutoButtonColor = false
reasonBtn.Font = Enum.Font.Code
reasonBtn.TextSize = 16
reasonBtn.TextColor3 = DEFAULT_THEME.Muted
reasonBtn.TextXAlignment = Enum.TextXAlignment.Left
reasonBtn.Text = "  " .. reasonOptions[1]
reasonBtn.Parent = reasonSection
addRound(reasonBtn, UDim.new(0, 8))
addStroke(reasonBtn, DEFAULT_THEME.Accent, 1)

local reasonArrow = Instance.new("TextLabel")
reasonArrow.Size = UDim2.new(0, 30, 1, 0)
reasonArrow.Position = UDim2.new(1, -34, 0, 0)
reasonArrow.BackgroundTransparency = 1
reasonArrow.Font = Enum.Font.Code
reasonArrow.TextSize = 18
reasonArrow.TextColor3 = DEFAULT_THEME.Accent
reasonArrow.TextXAlignment = Enum.TextXAlignment.Center
reasonArrow.TextYAlignment = Enum.TextYAlignment.Center
reasonArrow.Text = "▼"
reasonArrow.Parent = reasonBtn

local function closeReasonDropdown()
	if reasonDropdownFrame then
		reasonDropdownFrame:Destroy()
		reasonDropdownFrame = nil
	end
	reasonDropdownOpen = false
	reasonArrow.Text = "▼"
end

local function openReasonDropdown()
	if reasonDropdownOpen then
		closeReasonDropdown()
		return
	end
	reasonDropdownOpen = true
	reasonArrow.Text = "▲"

	reasonDropdownFrame = Instance.new("Frame")
	reasonDropdownFrame.Size = UDim2.new(1, 0, 0, 0)
	reasonDropdownFrame.Position = UDim2.new(0, 0, 1, 4)
	reasonDropdownFrame.BackgroundColor3 = Color3.fromRGB(0, 15, 0)
	reasonDropdownFrame.BorderSizePixel = 0
	reasonDropdownFrame.ZIndex = 10
	reasonDropdownFrame.Parent = reasonBtn
	addRound(reasonDropdownFrame, UDim.new(0, 8))
	addStroke(reasonDropdownFrame, DEFAULT_THEME.Accent, 1)

	local rLayout = Instance.new("UIListLayout")
	rLayout.Padding = UDim.new(0, 2)
	rLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rLayout.Parent = reasonDropdownFrame

	local rMaxVisible = math.min(#reasonOptions, 6)
	local rItemHeight = 32
	reasonDropdownFrame.Size = UDim2.new(1, 0, 0, rMaxVisible * rItemHeight + 8)

	local rClip = Instance.new("Frame")
	rClip.Size = UDim2.new(1, 0, 0, rMaxVisible * rItemHeight + 4)
	rClip.BackgroundTransparency = 1
	rClip.ClipsDescendants = true
	rClip.Parent = reasonDropdownFrame

	local rScroll = Instance.new("ScrollingFrame")
	rScroll.Size = UDim2.new(1, 0, 1, 0)
	rScroll.BackgroundTransparency = 1
	rScroll.ScrollBarThickness = 6
	rScroll.CanvasSize = UDim2.new(0, 0, 0, #reasonOptions * rItemHeight)
	rScroll.BorderSizePixel = 0
	rScroll.Parent = rClip

	local rItemLayout = Instance.new("UIListLayout")
	rItemLayout.Padding = UDim.new(0, 1)
	rItemLayout.SortOrder = Enum.SortOrder.LayoutOrder
	rItemLayout.Parent = rScroll

		for _, opt in ipairs(reasonOptions) do
			local item = Instance.new("TextButton")
			item.Size = UDim2.new(1, -4, 0, rItemHeight)
			item.BackgroundColor3 = Color3.fromRGB(0, 20, 0)
			item.AutoButtonColor = false
			item.Font = Enum.Font.Code
			item.TextSize = 14
			item.TextColor3 = opt == reasonOptions[1] and DEFAULT_THEME.Muted or DEFAULT_THEME.Text
			item.TextXAlignment = Enum.TextXAlignment.Left
			item.TextYAlignment = Enum.TextYAlignment.Center
			item.Text = "  " .. opt
			item.ZIndex = 15
			item.Parent = rScroll
			addRound(item, UDim.new(0, 4))

		item.MouseEnter:Connect(function()
			tw(item, {BackgroundColor3 = Color3.fromRGB(0, 40, 0)}, 0.08):Play()
		end)
		item.MouseLeave:Connect(function()
			tw(item, {BackgroundColor3 = Color3.fromRGB(0, 20, 0)}, 0.08):Play()
		end)
		item.MouseButton1Click:Connect(function()
			selectedReason = opt
			reasonBtn.Text = "  " .. opt
			reasonBtn.TextColor3 = opt == reasonOptions[1] and DEFAULT_THEME.Muted or DEFAULT_THEME.Text
			closeReasonDropdown()
			-- Show/hide script dropdown based on reason
			if opt == "Script Bug Report" or opt == "Script Suggestion" then
				scriptSection.Visible = true
			else
				scriptSection.Visible = false
				selectedScript = scriptOptions[1]
				scriptBtn.Text = "  " .. scriptOptions[1]
				scriptBtn.TextColor3 = DEFAULT_THEME.Muted
			end
		end)
	end
end

reasonBtn.MouseButton1Click:Connect(function()
	openReasonDropdown()
end)

-- Affected Script dropdown (conditionally visible)
local scriptSection = createInputSection("Affected Script", "Select the script this relates to (optional)")
scriptSection.Visible = false
local scriptOptions = {
	"-- Not specified --", "The Hub", "Get Base", "Respawn", "Tool Grabber",
	"No Cooldown", "Insta-Kill", "Use Tools", "Hit Amplifier", "Loop Tools",
	"Hitbox", "Loopbring", "Kill Aura", "Loopkill", "Anti-Lag",
	"Infinite Yield", "Grip", "Axe Smash Spam", "Emote GUI",
	"Anti-Aura Shield", "Damage Amplifier Field", "Fling"
}
local selectedScript = scriptOptions[1]
local scriptDropdownOpen = false
local scriptDropdownFrame

local scriptBtn = Instance.new("TextButton")
scriptBtn.Size = UDim2.new(1, -20, 0, 36)
scriptBtn.Position = UDim2.new(0, 10, 0, 52)
scriptBtn.BackgroundColor3 = Color3.fromRGB(0, 10, 0)
scriptBtn.AutoButtonColor = false
scriptBtn.Font = Enum.Font.Code
scriptBtn.TextSize = 16
scriptBtn.TextColor3 = DEFAULT_THEME.Muted
scriptBtn.TextXAlignment = Enum.TextXAlignment.Left
scriptBtn.Text = "  " .. scriptOptions[1]
scriptBtn.Parent = scriptSection
addRound(scriptBtn, UDim.new(0, 8))
addStroke(scriptBtn, DEFAULT_THEME.Accent, 1)

local scriptArrow = Instance.new("TextLabel")
scriptArrow.Size = UDim2.new(0, 30, 1, 0)
scriptArrow.Position = UDim2.new(1, -34, 0, 0)
scriptArrow.BackgroundTransparency = 1
scriptArrow.Font = Enum.Font.Code
scriptArrow.TextSize = 18
scriptArrow.TextColor3 = DEFAULT_THEME.Accent
scriptArrow.TextXAlignment = Enum.TextXAlignment.Center
scriptArrow.TextYAlignment = Enum.TextYAlignment.Center
scriptArrow.Text = "▼"
scriptArrow.Parent = scriptBtn

local function closeScriptDropdown()
	if scriptDropdownFrame then
		scriptDropdownFrame:Destroy()
		scriptDropdownFrame = nil
	end
	scriptDropdownOpen = false
	scriptArrow.Text = "▼"
end

local function openScriptDropdown()
	if scriptDropdownOpen then
		closeScriptDropdown()
		return
	end
	scriptDropdownOpen = true
	scriptArrow.Text = "▲"

	scriptDropdownFrame = Instance.new("Frame")
	scriptDropdownFrame.Size = UDim2.new(1, 0, 0, 0)
	scriptDropdownFrame.Position = UDim2.new(0, 0, 1, 4)
	scriptDropdownFrame.BackgroundColor3 = Color3.fromRGB(0, 15, 0)
	scriptDropdownFrame.BorderSizePixel = 0
	scriptDropdownFrame.ZIndex = 10
	scriptDropdownFrame.Parent = scriptBtn
	addRound(scriptDropdownFrame, UDim.new(0, 8))
	addStroke(scriptDropdownFrame, DEFAULT_THEME.Accent, 1)

	local sLayout = Instance.new("UIListLayout")
	sLayout.Padding = UDim.new(0, 2)
	sLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sLayout.Parent = scriptDropdownFrame

	local sMaxVisible = math.min(#scriptOptions, 8)
	local sItemHeight = 32
	scriptDropdownFrame.Size = UDim2.new(1, 0, 0, sMaxVisible * sItemHeight + 8)

	local sClip = Instance.new("Frame")
	sClip.Size = UDim2.new(1, 0, 0, sMaxVisible * sItemHeight + 4)
	sClip.BackgroundTransparency = 1
	sClip.ClipsDescendants = true
	sClip.Parent = scriptDropdownFrame

	local sScroll = Instance.new("ScrollingFrame")
	sScroll.Size = UDim2.new(1, 0, 1, 0)
	sScroll.BackgroundTransparency = 1
	sScroll.ScrollBarThickness = 6
	sScroll.CanvasSize = UDim2.new(0, 0, 0, #scriptOptions * sItemHeight)
	sScroll.BorderSizePixel = 0
	sScroll.Parent = sClip

	local sItemLayout = Instance.new("UIListLayout")
	sItemLayout.Padding = UDim.new(0, 1)
	sItemLayout.SortOrder = Enum.SortOrder.LayoutOrder
	sItemLayout.Parent = sScroll

	for _, opt in ipairs(scriptOptions) do
		local item = Instance.new("TextButton")
		item.Size = UDim2.new(1, -4, 0, sItemHeight)
		item.BackgroundColor3 = Color3.fromRGB(0, 20, 0)
		item.AutoButtonColor = false
		item.Font = Enum.Font.Code
		item.TextSize = 14
		item.TextColor3 = opt == scriptOptions[1] and DEFAULT_THEME.Muted or DEFAULT_THEME.Text
		item.TextXAlignment = Enum.TextXAlignment.Left
		item.TextYAlignment = Enum.TextYAlignment.Center
		item.Text = "  " .. opt
		item.ZIndex = 15
		item.Parent = sScroll
		addRound(item, UDim.new(0, 4))

		item.MouseEnter:Connect(function()
			tw(item, {BackgroundColor3 = Color3.fromRGB(0, 40, 0)}, 0.08):Play()
		end)
		item.MouseLeave:Connect(function()
			tw(item, {BackgroundColor3 = Color3.fromRGB(0, 20, 0)}, 0.08):Play()
		end)
		item.MouseButton1Click:Connect(function()
			selectedScript = opt
			scriptBtn.Text = "  " .. opt
			scriptBtn.TextColor3 = opt == scriptOptions[1] and DEFAULT_THEME.Muted or DEFAULT_THEME.Text
			closeScriptDropdown()
		end)
	end
end

scriptBtn.MouseButton1Click:Connect(function()
	openScriptDropdown()
end)

-- Close dropdowns if user clicks elsewhere
table.insert(feedbackConnections, UserInputService.InputBegan:Connect(function(input, gpe)
	if gpe then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		-- Close reason dropdown
		if reasonDropdownOpen and reasonDropdownFrame then
			local pos = UserInputService:GetMouseLocation()
			local absPos = reasonBtn.AbsolutePosition
			local absSize = reasonBtn.AbsoluteSize
			local ddPos = reasonDropdownFrame.AbsolutePosition
			local ddSize = reasonDropdownFrame.AbsoluteSize
			local inBtn = pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
			local inDD = pos.X >= ddPos.X and pos.X <= ddPos.X + ddSize.X and pos.Y >= ddPos.Y and pos.Y <= ddPos.Y + ddSize.Y
			if not inBtn and not inDD then
				closeReasonDropdown()
			end
		end
		-- Close script dropdown
		if scriptDropdownOpen and scriptDropdownFrame then
			local pos = UserInputService:GetMouseLocation()
			local absPos = scriptBtn.AbsolutePosition
			local absSize = scriptBtn.AbsoluteSize
			local ddPos = scriptDropdownFrame.AbsolutePosition
			local ddSize = scriptDropdownFrame.AbsoluteSize
			local inBtn = pos.X >= absPos.X and pos.X <= absPos.X + absSize.X and pos.Y >= absPos.Y and pos.Y <= absPos.Y + absSize.Y
			local inDD = pos.X >= ddPos.X and pos.X <= ddPos.X + ddSize.X and pos.Y >= ddPos.Y and pos.Y <= ddPos.Y + ddSize.Y
			if not inBtn and not inDD then
				closeScriptDropdown()
			end
		end
	end
end))

-- Feedback text area
local fbSection = createInputSection("Feedback", "Write your detailed feedback here (required)")
local fbBox = Instance.new("TextBox")
fbBox.Size = UDim2.new(1, -20, 0, 120)
fbBox.Position = UDim2.new(0, 10, 0, 52)
fbBox.BackgroundColor3 = Color3.fromRGB(0, 10, 0)
fbBox.PlaceholderText = "Type your feedback here..."
fbBox.Text = ""
fbBox.ClearTextOnFocus = false
fbBox.Font = Enum.Font.Code
fbBox.TextSize = 16
fbBox.TextColor3 = DEFAULT_THEME.Text
fbBox.PlaceholderColor3 = DEFAULT_THEME.Muted
fbBox.TextXAlignment = Enum.TextXAlignment.Left
fbBox.TextYAlignment = Enum.TextYAlignment.Top
fbBox.MultiLine = true
fbBox.Parent = fbSection
addRound(fbBox, UDim.new(0, 8))
addStroke(fbBox, DEFAULT_THEME.Accent, 1)

-- Character count
local charCount = Instance.new("TextLabel")
charCount.Size = UDim2.new(1, -24, 0, 20)
charCount.Position = UDim2.new(0, 12, 0, 172)
charCount.BackgroundTransparency = 1
charCount.Font = Enum.Font.Code
charCount.TextSize = 12
charCount.TextColor3 = DEFAULT_THEME.Muted
charCount.TextXAlignment = Enum.TextXAlignment.Right
charCount.Text = "0 / 2000"
charCount.Parent = fbSection

fbBox:GetPropertyChangedSignal("Text"):Connect(function()
	local len = #fbBox.Text
	if len > 2000 then
		fbBox.Text = fbBox.Text:sub(1, 2000)
		len = 2000
	end
	charCount.Text = len .. " / 2000"
end)

-- Submit button
local submitBtnFrame = Instance.new("Frame")
submitBtnFrame.Size = UDim2.new(1, -4, 0, 0)
submitBtnFrame.BackgroundTransparency = 1
submitBtnFrame.AutomaticSize = Enum.AutomaticSize.Y
submitBtnFrame.Parent = fbContent

local submitBtn = Instance.new("TextButton")
submitBtn.Size = UDim2.new(0, 260, 0, 48)
submitBtn.Position = UDim2.new(0.5, -130, 0, 6)
submitBtn.BackgroundColor3 = Color3.fromRGB(0, 20, 0)
submitBtn.AutoButtonColor = false
submitBtn.Font = Enum.Font.Code
submitBtn.TextSize = 20
submitBtn.TextColor3 = DEFAULT_THEME.Accent
submitBtn.Text = "▶  SUBMIT FEEDBACK"
submitBtn.Parent = submitBtnFrame
addRound(submitBtn, UDim.new(0, 12))
addStroke(submitBtn, DEFAULT_THEME.Accent, 2)

-- Submit button animations
submitBtn.MouseEnter:Connect(function()
	tw(submitBtn, {BackgroundColor3 = Color3.fromRGB(0, 40, 0)}, 0.12):Play()
	tw(submitBtn, {Size = UDim2.new(0, 270, 0, 52)}, 0.12):Play()
	submitBtn.Position = UDim2.new(0.5, -135, 0, 6)
end)
submitBtn.MouseLeave:Connect(function()
	tw(submitBtn, {BackgroundColor3 = Color3.fromRGB(0, 20, 0)}, 0.12):Play()
	tw(submitBtn, {Size = UDim2.new(0, 260, 0, 48)}, 0.12):Play()
	submitBtn.Position = UDim2.new(0.5, -130, 0, 6)
end)

-- Generate unique feedback ID (TFL_XXXXXXXXXX - max 14 chars total)
local function generateFeedbackId()
	math.randomseed(tick() + os.clock() + math.random(1, 99999))
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
	local id = "TFL_"
	for i = 1, 10 do
		id = id .. chars:sub(math.random(1, #chars), math.random(1, #chars))
	end
	return id
end

-- Submit logic
local isSubmitting = false
submitBtn.MouseButton1Click:Connect(function()
	if isSubmitting then return end

	-- Validate fields
	local username = nameBox.Text:match("^%s*(.-)%s*$") or ""
	local feedback = fbBox.Text:match("^%s*(.-)%s*$") or ""
	if username == "" or feedback == "" or selectedReason == reasonOptions[1] then
		showToast("⚠️ Please fill in all required fields before submitting!", 3, false)
		return
	end

	isSubmitting = true
	submitBtn.Text = "⏳  SENDING..."
	submitBtn.TextColor3 = DEFAULT_THEME.Muted

	local feedbackId = generateFeedbackId()

	task.spawn(function()
		-- Detect executor with improved fallback detection
		local executor = "Unknown"
		local execName = getexecutorname and getexecutorname() or nil
		if execName and type(execName) == "string" and execName ~= "" then
			executor = execName
		else
			local ok, result = pcall(function()
				return identifyexecutor()
			end)
			if ok and type(result) == "table" then
				executor = result.name or result[1] or "Unknown"
			elseif ok and type(result) == "string" then
				executor = result
			end
		end
		if executor == "Unknown" then
			local executorChecks = {
				{ syn and syn.crypt, "Synapse" },
				{ is_sirhurt_closure and is_sirhurt_closure(), "SirHurt" },
				{ pebc_execute, "ProtoSmasher" },
				{ KRNL_LOADED, "Krnl" },
				{ VALVE_LOADED, "Valve" },
				{ FLUXUS_LOADED, "Fluxus" },
				{ OXYGEN_LOADED, "Oxygen U" },
				{ SENTINEL_LOADED, "Sentinel" },
				{ SCRIPTWARE_LOADED, "Script-Ware" },
				{ EV_LOADED, "Eclipse" },
				{ VEGA_LOADED, "Vega X" },
				{ SOLARA_LOADED, "Solara" },
				{ JJS_LOADED, "JJsploit" },
				{ HYDROGEN_LOADED, "Hydrogen" },
			}
			for _, check in ipairs(executorChecks) do
				if check[1] then
					executor = check[2]
					break
				end
			end
		end

		-- Get game info
		local gameName = "Unknown"
		local ok3, productInfo = pcall(function()
			return MarketplaceService:GetProductInfo(game.PlaceId)
		end)
		if ok3 and type(productInfo) == "table" then
			gameName = productInfo.Name or "Unknown"
		end

		local playerName = LocalPlayer.Name
		local displayName = LocalPlayer.DisplayName
		local dateStr = os.date("%Y-%m-%d %H:%M:%S")

		-- Build script info string
		local scriptInfo = selectedScript
		if selectedScript == scriptOptions[1] then
			scriptInfo = "Not specified"
		end

		-- Build Discord embed
		local embed = {
			{
				["title"] = "📬 New Feedback [" .. feedbackId .. "]",
				["color"] = 65535,
				["fields"] = {
					{["name"] = "Feedback ID", ["value"] = tostring(feedbackId), ["inline"] = false},
					{["name"] = "Game", ["value"] = tostring(gameName), ["inline"] = true},
					{["name"] = "Place ID", ["value"] = tostring(game.PlaceId), ["inline"] = true},
					{["name"] = "Job ID", ["value"] = tostring(game.JobId), ["inline"] = false},
					{["name"] = "Player", ["value"] = tostring(displayName) .. " (@" .. tostring(playerName) .. ")", ["inline"] = true},
					{["name"] = "Executor", ["value"] = tostring(executor), ["inline"] = true},
					{["name"] = "Version", ["value"] = tostring(HUB_VERSION), ["inline"] = true},
					{["name"] = "Date", ["value"] = tostring(dateStr), ["inline"] = false},
					{["name"] = "Reason", ["value"] = tostring(selectedReason), ["inline"] = true},
					{["name"] = "Script", ["value"] = tostring(scriptInfo), ["inline"] = true},
					{["name"] = "Feedback", ["value"] = tostring(feedback), ["inline"] = false}
				}
			}
		}

		-- Use executor-compatible HTTP request
		local httpRequest = request or http_request or (syn and syn.request)
		if not httpRequest then
			warn("[TFLHub] Executor does not support HTTP requests")
			showToast("❌ Your executor does not support webhook requests.", 3, false)
			isSubmitting = false
			submitBtn.Text = "▶  SUBMIT FEEDBACK"
			submitBtn.TextColor3 = DEFAULT_THEME.Accent
			return
		end

		local success, err = pcall(function()
			return httpRequest({
				Url = WEBHOOK_URL,
				Method = "POST",
				Headers = {["Content-Type"] = "application/json"},
				Body = HttpService:JSONEncode({embeds = embed, username = "TFL Hub Feedback", avatar_url = ""})
			})
		end)

		if success then
			-- Send simplified log to second webhook
			pcall(function()
				httpRequest({
					Url = FEEDBACK_LOG_WEBHOOK,
					Method = "POST",
					Headers = {["Content-Type"] = "application/json"},
					Body = HttpService:JSONEncode({
						["embeds"] = {{
							["title"] = "📝 New Feedback Submission",
							["color"] = 30621,
							["fields"] = {
								{["name"] = "Username", ["value"] = tostring(displayName) .. " (@" .. tostring(playerName) .. ")", ["inline"] = true},
								{["name"] = "Time", ["value"] = tostring(dateStr), ["inline"] = true},
								{["name"] = "Feedback ID", ["value"] = tostring(feedbackId), ["inline"] = false}
							},
							["footer"] = {["text"] = "TFL Hub Feedback Log"}
						}},
						["username"] = "TFL Feedback Log",
						["avatar_url"] = ""
					})
				})
			end)

			showToast("✅ Feedback submitted! Your ID: " .. feedbackId, 4, false)
			nameBox.Text = ""
			fbBox.Text = ""
			selectedReason = reasonOptions[1]
			reasonBtn.Text = "  " .. reasonOptions[1]
			reasonBtn.TextColor3 = DEFAULT_THEME.Muted
			selectedScript = scriptOptions[1]
			scriptBtn.Text = "  " .. scriptOptions[1]
			scriptBtn.TextColor3 = DEFAULT_THEME.Muted
			scriptSection.Visible = false
			charCount.Text = "0 / 2000"
		else
			warn("[TFLHub] Webhook failed:", err)
			showToast("❌ Failed to submit feedback. Please try again.", 3, false)
		end

		isSubmitting = false
		submitBtn.Text = "▶  SUBMIT FEEDBACK"
		submitBtn.TextColor3 = DEFAULT_THEME.Accent
	end)
end)

-- ======= Sidebar build (Updates first, then rest) =======
local btnUpdates = createSidebarButton("Updates", 1); btnUpdates.SetAccent(true)
local btnWelcome = createSidebarButton("Welcome", 2)
local btnTools = createSidebarButton("Tool Scripts", 3)
local btnPlayer = createSidebarButton("Player Scripts", 4)
local btnOther = createSidebarButton("Other Scripts", 5)
local btnSettings = createSidebarButton("Settings", 6)
local btnFeedback = createSidebarButton("Feedback", 7)

-- ======= Dragging (PC + Mobile) =======
local dragging, dragInput, dragStart, startPos = false, nil, nil, nil
header.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		dragStart = input.Position
		startPos = main.Position
		input.Changed:Connect(function()
			if input.UserInputState == Enum.UserInputState.End then dragging = false end
		end)
	end
end)

header.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		dragInput = input
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input == dragInput and dragging and dragStart and startPos then
		local delta = input.Position - dragStart
		main.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
	end
end)

-- ======= Search filter (preserved) =======
searchBox:GetPropertyChangedSignal("Text"):Connect(function()
	local q = searchBox.Text:lower()
	for _, child in ipairs(buttonsHolder:GetChildren()) do
		if child:IsA("Frame") and child.Name:match("Btn$") then
			local btn = child:FindFirstChildWhichIsA("TextButton")
			local lbl = btn and btn:FindFirstChildWhichIsA("TextLabel")
			local visible = q == "" or (lbl and lbl.Text:lower():find(q))
			child.Visible = visible
			child.Size = visible and UDim2.new(1,0,0,44) or UDim2.new(1,0,0,0)
			child.LayoutOrder = visible and child.LayoutOrder or 999
		end
	end
end)

-- ======= Hub API (preserved) =======
local HubAPI = {}
function HubAPI.AddPage(pageName, builderFunc)
	if Pages[pageName] then warn("Page already exists:", pageName); return end
	local p = createPage(pageName)
	if type(builderFunc) == "function" then builderFunc(p) end
	createSidebarButton(pageName, #buttonsHolder:GetChildren()+1)
end
function HubAPI.GetPage(pageName) return Pages[pageName] end
function HubAPI.Show(pageName) showPage(pageName) end

-- Auto-execute behavior
if Settings.AutoExecute then
	saveSettings()
	_G.TflHubAutoExecuted = true
end

-- Save settings periodically
task.spawn(function()
	while screenGui.Parent do
		saveSettings()
		task.wait(2.5)
	end
end)

_G.TflHub = HubAPI

-- Hub Animation
local function hubOpenAnim()
	fxHolder.Visible = true
	blur.Enabled = true
	tw(blur, {Size = 24}, 0.35):Play()
	local scale = uiScale.Scale or 1
	local W, H = math.floor(920 * scale), math.floor(580 * scale)
	main.Size = UDim2.new(0, math.max(320, W), 0, math.max(240, H))
	main.Visible = true
	main.Position = UDim2.new(0.5, 0, -1.2, 0)
	tw(main, {Position = UDim2.new(0.5, 0, 0.5, 0)}, 0.35):Play()
	tw(main, {Size = UDim2.new(0, math.max(320, W), 0, math.max(240, H))}, 0.35):Play()
end

local function hubCloseAnim()
	tw(blur, {Size = 0}, 0.25):Play()
	local outTween = tw(main, {Position = UDim2.new(0.5, 0, -1.2, 0), Size = UDim2.new(0, 20, 0, 20)}, 0.28)
	outTween:Play()
	task.delay(0.25, function()
		blur.Enabled = false
		fxHolder.Visible = false
	end)
	task.delay(0.28, function()
		main.Visible = false
	end)
end

local function toggleHub()
	if not main.Visible or main.Position.Y.Scale < 0 then
		hubOpenAnim()
	else
		hubCloseAnim()
	end
end

---------------------------------------------------------------------
-- 🔥 TFL HUB TOGGLE BUTTON
---------------------------------------------------------------------

-- Safety: ensure main & screenGui exist
if screenGui and main and toggleHub then
	local toggleButton = Instance.new("TextButton")
	toggleButton.Name = "HubToggle"
	toggleButton.Parent = screenGui
	toggleButton.Size = UDim2.new(0, 130, 0, 46)
	toggleButton.Position = UDim2.new(0, 25, 0.5, -60)
	toggleButton.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	toggleButton.AutoButtonColor = false
	toggleButton.Text = "HUB"
	toggleButton.Font = Enum.Font.Code
	toggleButton.TextSize = 20
	toggleButton.TextColor3 = Color3.fromRGB(0, 255, 0)
	addRound(toggleButton, DEFAULT_THEME.Radius)
	addStroke(toggleButton, DEFAULT_THEME.Accent)

	toggleButton.MouseButton1Click:Connect(function()
		toggleHub()
	end)

	UserInputService.InputBegan:Connect(function(key, gp)
		if gp then return end
		if key.KeyCode == Enum.KeyCode.G then
			toggleHub()
		end
	end)

	print("[TFLHub] Toggle button successfully initialized.")
else
	warn("[TFLHub] Toggle button could not initialize — required objects missing.")
end

-- One-time startup toast
if not _G.TflHub_FirstSeen then
	_G.TflHub_FirstSeen = true
	task.spawn(function()
		showToast("TFL Hub Executed — REMEMBER TO READ UPDATES AND INFO PAGES!!", 3.4, false)
		wait(1.0)
	end)
end

-- ======= Finalize and initial print =======
showPage("Updates")

-- ======= Noclip (preserved) =======
local noclipEnabled = true
local originalCollision = {}
local watchedConnections = {}

local function disconnectWatchers()
	for _,conn in ipairs(watchedConnections) do
		conn:Disconnect()
	end
	table.clear(watchedConnections)
end

local function applyPart(part)
	if not part:IsA("BasePart") then return end
	if part:FindFirstAncestorOfClass("Tool") then return end
	if originalCollision[part] == nil then
		originalCollision[part] = part.CanCollide
	end
	part.CanCollide = false
end

local function restorePart(part)
	local original = originalCollision[part]
	if original ~= nil and part.Parent then
		part.CanCollide = original
	end
	originalCollision[part] = nil
end

local function applyCharacter(character)
	for _,obj in ipairs(character:GetDescendants()) do
		if obj:IsA("BasePart") then
			applyPart(obj)
		end
	end
	table.insert(watchedConnections,
		character.DescendantAdded:Connect(function(obj)
			if noclipEnabled and obj:IsA("BasePart") then
				applyPart(obj)
			end
		end)
	)
end

local function restoreCharacter()
	for part,_ in pairs(originalCollision) do
		restorePart(part)
	end
	table.clear(originalCollision)
end

local function onCharacter(character)
	disconnectWatchers()
	if noclipEnabled then
		applyCharacter(character)
	end
end

if LocalPlayer.Character then
	onCharacter(LocalPlayer.Character)
end

LocalPlayer.CharacterAdded:Connect(function(character)
	task.wait(0.2)
	onCharacter(character)
end)

RunService.Heartbeat:Connect(function()
	if not noclipEnabled then return end
	local character = LocalPlayer.Character
	if not character then return end
	for part in pairs(originalCollision) do
		if not part.Parent then
			originalCollision[part] = nil
		elseif part.CanCollide then
			part.CanCollide = false
		end
	end
end)

local function setNoclip(state)
	noclipEnabled = state
	local character = LocalPlayer.Character
	if not character then return end
	if state then
		applyCharacter(character)
	else
		restoreCharacter()
	end
end

UserInputService.InputBegan:Connect(function(input,gpe)
	if gpe then return end
	if input.KeyCode == Enum.KeyCode.N then
		setNoclip(not noclipEnabled)
	end
end)

setNoclip(true)

print("TFL Hub + Auto-Noclip Initialized")
