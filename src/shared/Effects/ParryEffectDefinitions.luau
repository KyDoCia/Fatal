local Effects = {
	DefaultParryEffect = table.freeze({
		Id = "DefaultParryEffect",
		Duration = 0.14, ContactFlashDuration = 0.055,
		CoreFlash = Color3.fromRGB(255, 246, 210),
		ImpactRing = table.freeze({ StartScale = 1.2, EndScale = 5.5 }),
		Slash = table.freeze({ Length = 4.5, Width = 0.16 }),
		Shockwave = table.freeze({ Delay = 0.025, Scale = 7 }),
		TrailBurst = 0.24,
		CameraImpulse = 0.18,
		Sound = "ParrySound",
	}),
}

function Effects.ImpactIntensity(speed, rally, maximumSpeed)
	local speedFactor = math.clamp(speed / math.max(maximumSpeed, 1), 0, 1)
	local rallyFactor = math.clamp(rally / 20, 0, 1)
	return math.clamp(speedFactor * 0.7 + rallyFactor * 0.3, 0, 1)
end

function Effects.Resolve(id)
	return Effects[id] or Effects.DefaultParryEffect
end

return table.freeze(Effects)
