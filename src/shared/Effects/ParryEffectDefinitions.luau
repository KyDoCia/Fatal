return table.freeze({
	DefaultParryEffect = table.freeze({
		Id = "DefaultParryEffect",
		Duration = 0.14,
		CoreFlash = Color3.fromRGB(255, 246, 210),
		ImpactRing = table.freeze({ StartScale = 1.2, EndScale = 5.5 }),
		Slash = table.freeze({ Length = 4.5, Width = 0.16 }),
		TrailBurst = 0.24,
		CameraImpulse = 0.18,
		Sound = "ParrySound",
	}),
})
