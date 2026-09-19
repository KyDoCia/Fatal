local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definition = require(ReplicatedStorage.Game.Shared.Effects.ParryEffectDefinitions).DefaultParryEffect

local Controller = {}
local pool = {}
local cursor = 0

local function part(name, shape)
	local value = Instance.new("Part")
	value.Name = name; value.Shape = shape; value.Anchored = true
	value.CanCollide = false; value.CanTouch = false; value.CanQuery = false
	value.Material = Enum.Material.Neon; value.Color = Definition.CoreFlash
	return value
end

for _ = 1, 4 do table.insert(pool, { Ring = part("ParryRing", Enum.PartType.Cylinder), Slash = part("ParrySlash", Enum.PartType.Block) }) end

function Controller.Present(position, direction, intensity)
	cursor = cursor % #pool + 1
	local slot = pool[cursor]
	local scale = 0.8 + intensity * 0.45
	slot.Ring.Size = Vector3.new(0.08, Definition.ImpactRing.StartScale, Definition.ImpactRing.StartScale) * scale
	slot.Ring.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.rad(90), 0)
	slot.Ring.Transparency = 0.18; slot.Ring.Parent = workspace
	slot.Slash.Size = Vector3.new(Definition.Slash.Width, Definition.Slash.Length * scale, Definition.Slash.Width)
	slot.Slash.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, 0, math.rad(45))
	slot.Slash.Transparency = 0.05; slot.Slash.Parent = workspace
	TweenService:Create(slot.Ring, TweenInfo.new(Definition.Duration), { Size = Vector3.new(0.08, Definition.ImpactRing.EndScale, Definition.ImpactRing.EndScale) * scale, Transparency = 1 }):Play()
	TweenService:Create(slot.Slash, TweenInfo.new(Definition.Duration), { Transparency = 1 }):Play()
	task.delay(Definition.Duration, function() if slot.Ring.Transparency >= 1 then slot.Ring.Parent = nil; slot.Slash.Parent = nil end end)
end

return Controller
