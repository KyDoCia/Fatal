local Config = {
	HUDScale = 1,
	TargetScale = 1,
	TargetPosition = UDim2.fromScale(0.5, 0.34),
	Transparency = 0.14,
	ScreenShake = 0.18,
	VFXIntensity = 1,
	BallPredictionLimit = 0.12,
	BallLerpResponse = 18,
	GoDuration = 0.7,
	Colors = {
		Safe = Color3.fromRGB(139, 145, 155),
		Threat = Color3.fromRGB(203, 151, 83),
		Danger = Color3.fromRGB(206, 69, 55),
		Critical = Color3.fromRGB(255, 42, 51),
	},
	Camera = {
		DefaultFOV = 70,
		TargetFOV = 68.5,
		CriticalFOV = 66.5,
		ParryPunch = 4,
		Response = 9,
		Recovery = 0.18,
		OffsetRecovery = 12,
	},
	VFX = {
		Duration = 0.16,
		StartSize = 1.5,
		EndSize = 6,
	},
	Audio = {
		Attempt = "",
		ParrySuccess = "",
		WallBounce = "",
		Elimination = "",
	},
}

return table.freeze(Config)
