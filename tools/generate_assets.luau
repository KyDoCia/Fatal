local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local Vector2 = roblox.Vector2
local Vector3 = roblox.Vector3
local UDim = roblox.UDim
local UDim2 = roblox.UDim2
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local ColorSequence = roblox.ColorSequence
local Enum = roblox.Enum
local Font = roblox.Font

fs.writeDir("assets")

local colors = {
	Background = Color3.fromRGB(9, 10, 13),
	Panel = Color3.fromRGB(19, 21, 26),
	Floor = Color3.fromRGB(35, 37, 42),
	Wall = Color3.fromRGB(21, 23, 27),
	Text = Color3.fromRGB(238, 240, 242),
	Muted = Color3.fromRGB(130, 136, 146),
	Red = Color3.fromRGB(235, 38, 50),
}

local function part(name, size, cframe, color, material, parent)
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.CFrame = cframe
	value.Color = color
	value.Material = material or Enum.Material.SmoothPlastic
	value.Anchored = true
	value.Parent = parent
	return value
end

local function weld(root, child)
	local constraint = Instance.new("WeldConstraint")
	constraint.Part0 = root
	constraint.Part1 = child
	constraint.Parent = child
end

-- Neutral 120x120 arena. Gameplay geometry is the only geometry in the lab.
local world = Instance.new("Folder")
world.Name = "Game"
part("LobbySpawn", Vector3.new(10, 1, 10), CFrame.new(0, 0, -48), colors.Floor, nil, world)
local arena = Instance.new("Model")
arena.Name = "Arena"
arena.Parent = world
local gameplay = Instance.new("Folder")
gameplay.Name = "Gameplay"
gameplay.Parent = arena
local npcs = Instance.new("Folder")
npcs.Name = "NPCs"
npcs.Parent = gameplay
part("Floor", Vector3.new(120, 2, 120), CFrame.new(0, -1, 0), colors.Floor, nil, gameplay)
local walls = Instance.new("Folder")
walls.Name = "Walls"
walls.Parent = gameplay
for _, spec in {
	{ "North", Vector3.new(124, 18, 4), CFrame.new(0, 8, -62) },
	{ "South", Vector3.new(124, 18, 4), CFrame.new(0, 8, 62) },
	{ "West", Vector3.new(4, 18, 120), CFrame.new(-62, 8, 0) },
	{ "East", Vector3.new(4, 18, 120), CFrame.new(62, 8, 0) },
} do
	part(spec[1], spec[2], spec[3], colors.Wall, nil, walls)
end
local spawns = Instance.new("Folder")
spawns.Name = "SpawnPoints"
spawns.Parent = gameplay
for index, x in { -22, 22 } do
	local spawn = part(string.format("Spawn%02d", index), Vector3.new(4, 0.2, 4), CFrame.new(x, 0.1, 0), colors.Red, Enum.Material.Neon, spawns)
	spawn.Transparency = 0.78
	spawn.CanCollide = false
end
local killBounds = part("KillBounds", Vector3.new(160, 2, 160), CFrame.new(0, -22, 0), colors.Background, nil, gameplay)
killBounds.Transparency = 1
killBounds.CanCollide = false
local visual = Instance.new("Folder")
visual.Name = "Visual"
visual.Parent = arena
fs.writeFile("assets/World.rbxm", roblox.serializeModel({ world }))

-- One readable server-owned ball template.
local ball = Instance.new("Part")
ball.Name = "FatalBall"
ball.Shape = Enum.PartType.Ball
ball.Size = Vector3.one * 4.5
ball.Color = Color3.fromRGB(20, 21, 24)
ball.Material = Enum.Material.Metal
ball.Anchored = true
ball.CanCollide = false
ball.CanTouch = false
ball.CanQuery = false
local light = Instance.new("PointLight")
light.Name = "CoreLight"
light.Color = colors.Red
light.Brightness = 2.5
light.Range = 18
light.Parent = ball
local trailTop = Instance.new("Attachment")
trailTop.Position = Vector3.new(0, 1.05, 0)
trailTop.Parent = ball
local trailBottom = Instance.new("Attachment")
trailBottom.Position = Vector3.new(0, -1.05, 0)
trailBottom.Parent = ball
local trail = Instance.new("Trail")
trail.Name = "MomentumTrail"
trail.Attachment0 = trailTop
trail.Attachment1 = trailBottom
trail.Color = ColorSequence.new(colors.Red)
trail.Lifetime = 0.18
trail.LightEmission = 1
trail.FaceCamera = true
trail.Parent = ball
fs.writeFile("assets/FatalBall.rbxm", roblox.serializeModel({ ball }))

-- Simple visual weapon; combat never uses its geometry.
local weapon = Instance.new("Model")
weapon.Name = "DefaultWeapon"
local handle = part("Handle", Vector3.new(0.45, 3.2, 0.45), CFrame.new(), colors.Background, Enum.Material.Metal, weapon)
handle.Anchored = false
handle.CanCollide = false
handle.Massless = true
local guard = part("Guard", Vector3.new(2.8, 0.3, 0.55), CFrame.new(0, 1.75, 0), colors.Muted, Enum.Material.Metal, weapon)
local blade = part("Blade", Vector3.new(0.58, 5.4, 0.2), CFrame.new(0, 4.6, 0), colors.Text, Enum.Material.Metal, weapon)
for _, value in { guard, blade } do
	value.Anchored = false
	value.CanCollide = false
	value.CanTouch = false
	value.CanQuery = false
	value.Massless = true
	weld(handle, value)
end
weapon.PrimaryPart = handle
fs.writeFile("assets/DefaultWeapon.rbxm", roblox.serializeModel({ weapon }))

local function screen(name, order)
	local value = Instance.new("ScreenGui")
	value.Name = name
	value.ResetOnSpawn = false
	value.IgnoreGuiInset = true
	value.DisplayOrder = order
	return value
end

local function frame(name, position, size, parent)
	local value = Instance.new("Frame")
	value.Name = name
	value.AnchorPoint = Vector2.new(0.5, 0.5)
	value.Position = position
	value.Size = size
	value.BackgroundColor3 = colors.Panel
	value.BackgroundTransparency = 0.2
	value.BorderSizePixel = 0
	value.Parent = parent
	return value
end

local function label(name, text, position, size, textSize, color, parent)
	local value = Instance.new("TextLabel")
	value.Name = name
	value.AnchorPoint = Vector2.new(0.5, 0.5)
	value.Position = position
	value.Size = size
	value.BackgroundTransparency = 1
	value.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
	value.Text = text
	value.TextColor3 = color
	value.TextSize = textSize
	value.Parent = parent
	return value
end

local hud = screen("HUD", 10)
local top = frame("TopStatus", UDim2.fromScale(0.5, 0.05), UDim2.fromOffset(320, 38), hud)
label("Round", "WAITING", UDim2.fromScale(0.35, 0.5), UDim2.fromScale(0.65, 1), 14, colors.Text, top)
label("Alive", "00 ALIVE", UDim2.fromScale(0.82, 0.5), UDim2.fromScale(0.3, 1), 12, colors.Muted, top)
local telemetry = frame("Telemetry", UDim2.fromScale(0.5, 0.045), UDim2.fromOffset(180, 38), hud)
local rally = label("Rally", "00 RALLY", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 14, colors.Text, telemetry)
rally.TextXAlignment = Enum.TextXAlignment.Center
local speed = label("Speed", "--- VELOCITY", UDim2.fromScale(0.5, 0.8), UDim2.fromScale(1, 0.3), 10, colors.Muted, telemetry)
speed.Visible = false
local target = frame("TargetIndicator", UDim2.fromScale(0.5, 0.48), UDim2.fromOffset(130, 86), hud)
target.BackgroundTransparency = 1
target.Visible = false
local targetScale = Instance.new("UIScale")
targetScale.Name = "PulseScale"
targetScale.Parent = target
local targetStroke = Instance.new("UIStroke")
targetStroke.Name = "ReticleStroke"
targetStroke.Color = colors.Muted
targetStroke.Transparency = 0.5
targetStroke.Parent = target
label("State", "INCOMING", UDim2.fromScale(0.5, 0.38), UDim2.fromScale(1, 0.35), 11, colors.Muted, target)
label("Time", "", UDim2.fromScale(0.5, 0.67), UDim2.fromScale(1, 0.35), 17, colors.Text, target)
fs.writeFile("assets/HUD.rbxm", roblox.serializeModel({ hud }))

local roundGui = screen("RoundGui", 20)
local countdown = frame("Countdown", UDim2.fromScale(0.5, 0.42), UDim2.fromOffset(220, 100), roundGui)
countdown.BackgroundTransparency = 1
countdown.Visible = false
local countdownScale = Instance.new("UIScale")
countdownScale.Name = "MotionScale"
countdownScale.Parent = countdown
local countdownLabel = label("Label", "", UDim2.fromScale(0.5, 0.5), UDim2.fromScale(1, 1), 60, colors.Text, countdown)
countdownLabel.FontFace = Font.fromEnum(Enum.Font.GothamBold)
fs.writeFile("assets/RoundGui.rbxm", roblox.serializeModel({ roundGui }))

local combatGui = screen("CombatGui", 30)
local button = Instance.new("TextButton")
button.Name = "ParryButton"
button.AnchorPoint = Vector2.new(1, 1)
button.Position = UDim2.new(1, -30, 1, -30)
button.Size = UDim2.fromOffset(126, 50)
button.BackgroundColor3 = colors.Red
button.BorderSizePixel = 0
button.FontFace = Font.fromEnum(Enum.Font.GothamBold)
button.Text = "PARRY"
button.TextColor3 = colors.Text
button.TextSize = 14
button.Visible = false
button.Parent = combatGui
local buttonScale = Instance.new("UIScale")
buttonScale.Name = "MotionScale"
buttonScale.Parent = button
local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 3)
corner.Parent = button
fs.writeFile("assets/CombatGui.rbxm", roblox.serializeModel({ combatGui }))

print("Generated FATAL Combat Lab assets")
