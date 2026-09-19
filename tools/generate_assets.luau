local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Instance = roblox.Instance
local Vector2 = roblox.Vector2
local Vector3 = roblox.Vector3
local UDim2 = roblox.UDim2
local UDim = roblox.UDim
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
local spawnPositions = {
	Vector3.new(-20, 0.1, 0), Vector3.new(20, 0.1, 0),
	Vector3.new(0, 0.1, -20), Vector3.new(0, 0.1, 20),
	Vector3.new(-14, 0.1, -14), Vector3.new(14, 0.1, 14),
	Vector3.new(-14, 0.1, 14), Vector3.new(14, 0.1, -14),
}
for index, position in spawnPositions do
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

local bladeModel = Instance.new("Model")
bladeModel.Name = "TrainingBlade"
local function weaponPart(name, size, cframe, color, material)
	local value = Instance.new("Part")
	value.Name = name; value.Size = size; value.CFrame = cframe; value.Color = color; value.Material = material
	value.Anchored = false; value.CanCollide = false; value.CanTouch = false; value.CanQuery = false; value.Massless = true
	value.Parent = bladeModel
	return value
end
local handle = weaponPart("Handle", Vector3.new(0.28, 0.9, 0.28), CFrame.new(0, 0, 0), Color3.fromRGB(52, 38, 34), Enum.Material.SmoothPlastic)
local guard = weaponPart("Guard", Vector3.new(1.05, 0.16, 0.3), CFrame.new(0, 0.53, 0), Color3.fromRGB(116, 92, 58), Enum.Material.Metal)
local blade = weaponPart("Blade", Vector3.new(0.22, 3.1, 0.38), CFrame.new(0, 2.14, 0), Color3.fromRGB(205, 215, 230), Enum.Material.Metal)
local grip = Instance.new("Attachment")
grip.Name = "WeaponGripAttachment"
grip.Parent = handle
for _, connected in { guard, blade } do
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle; weld.Part1 = connected; weld.Parent = handle
end
bladeModel.PrimaryPart = handle
fs.writeFile("assets/TrainingBlade.rbxm", roblox.serializeModel({ bladeModel }))

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

local inventoryGui = Instance.new("ScreenGui")
inventoryGui.Name = "InventoryGui"
inventoryGui.ResetOnSpawn = false
inventoryGui.Enabled = false
local panel = Instance.new("Frame")
panel.Name = "Panel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(420, 250)
panel.BackgroundColor3 = Color3.fromRGB(18, 21, 28)
panel.Parent = inventoryGui
local corner = Instance.new("UICorner"); corner.CornerRadius = UDim.new(0, 14); corner.Parent = panel
local title = Instance.new("TextLabel")
title.Name = "Title"; title.Text = "WEAPONS"; title.Position = UDim2.fromOffset(24, 18); title.Size = UDim2.fromOffset(360, 36); title.BackgroundTransparency = 1; title.TextColor3 = Color3.fromRGB(240, 242, 248); title.TextSize = 24; title.TextXAlignment = Enum.TextXAlignment.Left; title.Parent = panel
local item = Instance.new("TextLabel")
item.Name = "Item"; item.Text = "TRAINING BLADE"; item.Position = UDim2.fromOffset(24, 78); item.Size = UDim2.fromOffset(372, 70); item.BackgroundColor3 = Color3.fromRGB(31, 36, 47); item.TextColor3 = Color3.fromRGB(220, 226, 238); item.TextSize = 18; item.Parent = panel
local itemCorner = Instance.new("UICorner"); itemCorner.CornerRadius = UDim.new(0, 10); itemCorner.Parent = item
local equip = Instance.new("TextButton")
equip.Name = "Equip"; equip.Text = "EQUIPPED"; equip.Position = UDim2.fromOffset(230, 178); equip.Size = UDim2.fromOffset(166, 48); equip.BackgroundColor3 = Color3.fromRGB(202, 62, 52); equip.TextColor3 = Color3.fromRGB(255, 255, 255); equip.TextSize = 16; equip.Parent = panel
local equipCorner = Instance.new("UICorner"); equipCorner.CornerRadius = UDim.new(0, 10); equipCorner.Parent = equip
fs.writeFile("assets/InventoryGui.rbxm", roblox.serializeModel({ inventoryGui }))

print("Generated Combat Core V2 assets")
