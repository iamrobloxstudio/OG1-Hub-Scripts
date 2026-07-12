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

-- ======= Config / Defaults (preserved) =======
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
	bgGrad.Offset += Vector2.new(0.01 * dt, 0)
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

			p.Rotation += 0.4

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
	grad.Rotation += dt * 60
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
	grad.Offset += Vector2.new(0.02 * dt, 0)
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
welcomeText.Text = "Welcome to the TFL Hub. This hub is temporary and will be rebuilt in the future. For now, you can use the buttons below to execute scripts. Please note that some scripts may not work as expected."
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

-- ======= Sidebar build (kept) =======
local btnWelcome = createSidebarButton("Welcome", 1); btnWelcome.SetAccent(true)
local btnTools = createSidebarButton("Tool Scripts", 2)
local btnPlayer = createSidebarButton("Player Scripts", 3)
local btnOther = createSidebarButton("Other Scripts", 4)
local btnSettings = createSidebarButton("Settings", 5)

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

	tw(blur, {
		Size = 24
	}, 0.35):Play()

	local scale = uiScale.Scale or 1
	local W, H = math.floor(920 * scale), math.floor(580 * scale)

	main.Size = UDim2.new(0, math.max(320, W), 0, math.max(240, H))
	main.Visible = true

	main.Position = UDim2.new(0.5, 0, -1.2, 0)

	tw(main, {
		Position = UDim2.new(0.5, 0, 0.5, 0)
	}, 0.35):Play()

	tw(main, {
		Size = UDim2.new(0, math.max(320, W), 0, math.max(240, H))
	}, 0.35):Play()
end

local function hubCloseAnim()

	tw(blur, {
		Size = 0
	}, 0.25):Play()

	local outTween = tw(main, {
		Position = UDim2.new(0.5, 0, -1.2, 0),
		Size = UDim2.new(0, 20, 0, 20)
	}, 0.28)

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

	-- Position: Left Middle, slightly below chat bar
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
	
	-- Hover FX

	-- Hub Toggle
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
showPage("Welcome")

-- ============================================================================
-- 🔥 AUTO NOCLIP - Proper implementation
-- Walks through walls, no collision with hitboxes, no getting pushed
-- HumanoidRootPart retains CanCollide so you walk on the ground normally
-- ============================================================================
local noclipEnabled = true

local originalCanCollide = {}

local function restoreOriginalCollision(char)
	if not char then return end
	for part, val in pairs(originalCanCollide) do
		if part and part.Parent then
			part.CanCollide = val
		end
	end
	table.clear(originalCanCollide)
end

local function applyNoclip(char)
	if not char then return end
	
	-- Wait for HRP to exist
	local hrp = char:FindFirstChild("HumanoidRootPart")
	if not hrp then return end
	
	-- Process all parts in character: body parts, accessories, tools
	local function processParts(container)
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("BasePart") then
				if child ~= hrp then
					-- Save original state if not already saved
					if originalCanCollide[child] == nil then
						originalCanCollide[child] = child.CanCollide
					end
					-- Disable collision - this allows walking through walls
					-- and prevents hitboxes from pushing us around
					child.CanCollide = false
					
					-- Massless prevents physics interference with character movement
					if not child:GetAttribute("TFL_WasMassless") then
						child:SetAttribute("TFL_WasMassless", child.Massless)
					end
					child.Massless = true
				else
					-- HRP keeps CanCollide = true to stand on ground
					if originalCanCollide[child] == nil then
						originalCanCollide[child] = child.CanCollide
					end
					child.CanCollide = true
					child.Massless = false
				end
			elseif child:IsA("Tool") or child:IsA("Accessory") or child:IsA("Model") then
				processParts(child)
			end
		end
	end
	
	processParts(char)
end

local function restoreOriginalMass(char)
	if not char then return end
	local function processParts(container)
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("BasePart") then
				local wasMassless = child:GetAttribute("TFL_WasMassless")
				if wasMassless ~= nil then
					child.Massless = wasMassless
				end
			elseif child:IsA("Tool") or child:IsA("Accessory") or child:IsA("Model") then
				processParts(child)
			end
		end
	end
	processParts(char)
end

local function setNoclipState(char, enabled)
	if not char then return end
	if enabled then
		applyNoclip(char)
	else
		restoreOriginalCollision(char)
		restoreOriginalMass(char)
	end
end

-- Apply noclip on character spawn/change
LocalPlayer.CharacterAdded:Connect(function(char)
	char:WaitForChild("HumanoidRootPart", 5)
	task.wait(0.1)
	if noclipEnabled then
		setNoclipState(char, true)
	end
end)

-- Noclip maintenance loop: keeps noclip applied as new parts are added
RunService.Heartbeat:Connect(function()
	if noclipEnabled then
		local char = LocalPlayer.Character
		if char then
			local hrp = char:FindFirstChild("HumanoidRootPart")
			if hrp then
				-- Ensure HRP stays collidable for ground walking
				hrp.CanCollide = true
				hrp.Massless = false
				
				-- Re-apply noclip to all non-HRP parts
				local function enforceNoclip(container)
					for _, child in ipairs(container:GetChildren()) do
						if child:IsA("BasePart") and child ~= hrp then
							if child.CanCollide ~= false then
								if originalCanCollide[child] == nil then
									originalCanCollide[child] = child.CanCollide
								end
								child.CanCollide = false
							end
							if not child:GetAttribute("TFL_WasMassless") then
								child:SetAttribute("TFL_WasMassless", child.Massless)
							end
							child.Massless = true
						elseif child:IsA("Tool") or child:IsA("Accessory") or child:IsA("Model") then
							enforceNoclip(child)
						end
					end
				end
				enforceNoclip(char)
			end
		end
	end
end)

-- Noclip toggle key (N key)
UserInputService.InputBegan:Connect(function(input, gp)
	if gp then return end
	if input.KeyCode == Enum.KeyCode.N then
		noclipEnabled = not noclipEnabled
		local char = LocalPlayer.Character
		setNoclipState(char, noclipEnabled)
	end
end)

print("TFL Hub Initialized")
