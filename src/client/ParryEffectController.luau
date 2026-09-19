local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definition = require(ReplicatedStorage.Game.Shared.Effects.ParryEffectDefinitions).DefaultParryEffect

local Controller = {}
local pool = {}
local hitPool = {}
local cursor = 0

local function part(name, shape)
	local value = Instance.new("Part")
	value.Name = name; value.Shape = shape; value.Anchored = true
	value.CanCollide = false; value.CanTouch = false; value.CanQuery = false
	value.Material = Enum.Material.Neon; value.Color = Definition.CoreFlash
	return value
end

for _ = 1, 4 do table.insert(pool, {
	Flash = part("ContactFlash", Enum.PartType.Ball), Ring = part("ParryRing", Enum.PartType.Cylinder),
	Shockwave = part("ParryShockwave", Enum.PartType.Cylinder), Slash = part("ParrySlash", Enum.PartType.Block),
}) end
for _ = 1, 3 do table.insert(hitPool, part("CombatantHitFlash", Enum.PartType.Ball)) end

function Controller.Present(position, direction, intensity)
	cursor = cursor % #pool + 1
	local slot = pool[cursor]
	local scale = 0.8 + intensity * 0.45
	slot.Flash.Size = Vector3.one * (0.55 + intensity * 0.35); slot.Flash.Position = position; slot.Flash.Transparency = 0; slot.Flash.Parent = workspace
	slot.Ring.Size = Vector3.new(0.08, Definition.ImpactRing.StartScale, Definition.ImpactRing.StartScale) * scale
	slot.Ring.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, math.rad(90), 0)
	slot.Ring.Transparency = 0.18; slot.Ring.Parent = workspace
	slot.Slash.Size = Vector3.new(Definition.Slash.Width, Definition.Slash.Length * scale, Definition.Slash.Width)
	slot.Slash.CFrame = CFrame.lookAt(position, position + direction) * CFrame.Angles(0, 0, math.rad(45))
	slot.Slash.Transparency = 0.05; slot.Slash.Parent = workspace
	slot.Shockwave.Size = Vector3.new(0.05, 1, 1) * scale; slot.Shockwave.CFrame = slot.Ring.CFrame
	slot.Shockwave.Transparency = 0.55; slot.Shockwave.Parent = workspace
	TweenService:Create(slot.Flash, TweenInfo.new(Definition.ContactFlashDuration), { Size = slot.Flash.Size * 1.8, Transparency = 1 }):Play()
	TweenService:Create(slot.Ring, TweenInfo.new(Definition.Duration), { Size = Vector3.new(0.08, Definition.ImpactRing.EndScale, Definition.ImpactRing.EndScale) * scale, Transparency = 1 }):Play()
	TweenService:Create(slot.Slash, TweenInfo.new(Definition.Duration), { Transparency = 1 }):Play()
	task.delay(Definition.Shockwave.Delay, function()
		TweenService:Create(slot.Shockwave, TweenInfo.new(Definition.Duration * 0.8), { Size = Vector3.new(0.05, Definition.Shockwave.Scale, Definition.Shockwave.Scale) * scale, Transparency = 1 }):Play()
	end)
	task.delay(Definition.Duration, function()
		if slot.Ring.Transparency >= 1 then for _, value in slot do value.Parent = nil end end
	end)
end

function Controller.PresentHit(position, intensity)
	local flash = hitPool[cursor % #hitPool + 1]
	flash.Size = Vector3.one * (1.3 + intensity * 0.5); flash.Position = position; flash.Transparency = 0.05; flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.13), { Size = flash.Size * 1.8, Transparency = 1 }):Play()
	task.delay(0.14, function() if flash.Transparency >= 1 then flash.Parent = nil end end)
end

return Controller
