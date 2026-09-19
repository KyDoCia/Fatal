local Definitions = {}

Definitions.StandardBall = table.freeze({
		Id = "StandardBall",
		AssetName = "CombatBall",
		VisualScale = 1,
		ImpactScale = table.freeze({ Squash = 0.82, StretchBase = 1.25, StretchIntensity = 0.2 }),
		Material = "Neon",
		Trail = table.freeze({ BaseLifetime = 0.12, SpeedLifetime = 0.08, LightEmission = 0.8 }),
		ParryFeedback = table.freeze({ FlashDuration = 0.11, TrailLifetime = 0.22 }),
		Sounds = table.freeze({ Parry = "", Hit = "" }),
	})

function Definitions.CanonicalVisualSize(definition, assetSize)
	return assetSize * definition.VisualScale
end

function Definitions.ImpactVisualSize(definition, baseSize, intensity)
	local scale = definition.ImpactScale
	return Vector3.new(baseSize.X * scale.Squash, baseSize.Y * scale.Squash, baseSize.Z * (scale.StretchBase + intensity * scale.StretchIntensity))
end

return table.freeze(Definitions)
