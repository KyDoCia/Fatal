return table.freeze({
	StandardBall = table.freeze({
		Id = "StandardBall",
		AssetName = "CombatBall",
		VisualScale = 1,
		Material = "Neon",
		Trail = table.freeze({ BaseLifetime = 0.08, SpeedLifetime = 0.06, LightEmission = 0.8 }),
		ParryFeedback = table.freeze({ FlashDuration = 0.11, TrailLifetime = 0.22 }),
		Sounds = table.freeze({ Parry = "", Hit = "" }),
	}),
})
