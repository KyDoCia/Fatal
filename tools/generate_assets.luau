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
	spawn.Transparency = 0.75
	spawn.CanCollide = false
end
fs.writeFile("assets/World.rbxm", roblox.serializeModel({ world }))

local ball = Instance.new("Part")
ball.Name = "CombatBall"
ball.Shape = Enum.PartType.Ball
ball.Size = Vector3.one * 1.7
ball.Color = Color3.fromRGB(238, 54, 66)
ball.Material = Enum.Material.Neon
ball.Anchored = true
ball.CanCollide = false
ball.CanTouch = false
ball.CanQuery = false
local top = Instance.new("Attachment")
top.Position = Vector3.new(0, 0.4, 0)
top.Parent = ball
local bottom = Instance.new("Attachment")
bottom.Position = Vector3.new(0, -0.4, 0)
bottom.Parent = ball
local trail = Instance.new("Trail")
trail.Attachment0 = top
trail.Attachment1 = bottom
trail.Color = ColorSequence.new(ball.Color)
trail.Lifetime = 0.12
trail.LightEmission = 1
trail.FaceCamera = true
trail.Parent = ball
fs.writeFile("assets/CombatBall.rbxm", roblox.serializeModel({ ball }))

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
