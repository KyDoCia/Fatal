local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local Vector2 = roblox.Vector2
local Vector3 = roblox.Vector3
local UDim2 = roblox.UDim2
local CFrame = roblox.CFrame
local Color3 = roblox.Color3
local ColorSequence = roblox.ColorSequence
local Enum = roblox.Enum
local Font = roblox.Font

fs.writeDir("assets")

local function part(name, size, cframe, color, parent)
	local value = Instance.new("Part")
	value.Name = name
	value.Size = size
	value.CFrame = cframe
	value.Color = color
	value.Material = Enum.Material.SmoothPlastic
	value.Anchored = true
	value.Parent = parent
	return value
end

local world = Instance.new("Folder")
world.Name = "Game"
world:SetAttribute("FatalRuntimeContract", "CombatCoreV2CleanRoom")
local arena = Instance.new("Model")
arena.Name = "Arena"
arena.Parent = world
local gameplay = Instance.new("Folder")
gameplay.Name = "Gameplay"
gameplay.Parent = arena
local floor = part("Floor", Vector3.new(100, 2, 70), CFrame.new(0, -1, 0), Color3.fromRGB(32, 35, 42), gameplay)
floor.Material = Enum.Material.Slate
local npcs = Instance.new("Folder")
npcs.Name = "NPCs"
npcs.Parent = gameplay
local spawns = Instance.new("Folder")
spawns.Name = "SpawnPoints"
spawns.Parent = gameplay
for index, x in { -20, 20 } do
	local position = Vector3.new(x, 0.1, 0)
	local spawn = part(string.format("Spawn%02d", index), Vector3.new(3, 0.2, 3), CFrame.lookAt(position, Vector3.new(0, 0.1, 0)), Color3.fromRGB(70, 75, 86), spawns)
	spawn.Transparency = 1
	spawn.CanCollide = false
	spawn.CanTouch = false
	spawn.CanQuery = false
end
fs.writeFile("assets/World.rbxm", roblox.serializeModel({ world }))

local ball = Instance.new("Part")
ball.Name = "CombatBall"
ball.Shape = Enum.PartType.Ball
ball.Size = Vector3.one * 2
ball.Color = Color3.fromRGB(255, 76, 58)
ball.Material = Enum.Material.Neon
ball.Anchored = true
ball.CanCollide = false
ball.CanTouch = false
ball.CanQuery = false
local top = Instance.new("Attachment")
top.Position = Vector3.new(0, 0.45, 0)
top.Parent = ball
local bottom = Instance.new("Attachment")
bottom.Position = Vector3.new(0, -0.45, 0)
bottom.Parent = ball
local trail = Instance.new("Trail")
trail.Attachment0 = top
trail.Attachment1 = bottom
trail.Color = ColorSequence.new(ball.Color)
trail.Lifetime = 0.1
trail.LightEmission = 0.8
trail.FaceCamera = true
trail.Parent = ball
local light = Instance.new("PointLight")
light.Name = "CoreLight"
light.Color = ball.Color
light.Brightness = 0.8
light.Range = 5
light.Parent = ball
for _, name in { "ParrySound", "HitSound" } do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.Volume = 0.35
	sound.Parent = ball
end
fs.writeFile("assets/CombatBall.rbxm", roblox.serializeModel({ ball }))

local blade = Instance.new("Part")
blade.Name = "TrainingBlade"
blade.Size = Vector3.new(0.22, 3.4, 0.42)
blade.Color = Color3.fromRGB(205, 215, 230)
blade.Material = Enum.Material.Metal
blade.Anchored = false
blade.CanCollide = false
blade.CanTouch = false
blade.CanQuery = false
blade.Massless = true
fs.writeFile("assets/TrainingBlade.rbxm", roblox.serializeModel({ blade }))

local gui = Instance.new("ScreenGui")
gui.Name = "RallyGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
local label = Instance.new("TextLabel")
label.Name = "Rally"
label.AnchorPoint = Vector2.new(0.5, 0)
label.Position = UDim2.fromScale(0.5, 0.025)
label.Size = UDim2.fromOffset(180, 30)
label.BackgroundTransparency = 1
label.FontFace = Font.fromEnum(Enum.Font.GothamMedium)
label.Text = ""
label.TextColor3 = Color3.fromRGB(235, 238, 244)
label.TextSize = 16
label.Parent = gui
fs.writeFile("assets/RallyGui.rbxm", roblox.serializeModel({ gui }))

print("Generated Combat Core V2 assets")
