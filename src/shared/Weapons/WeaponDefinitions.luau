local Definitions = {
	TrainingBlade = table.freeze({
		Id = "TrainingBlade",
		AssetName = "TrainingBlade",
		Grip = CFrame.new(0, 1.45, 0),
		AnimationSet = "TrainingBladeDefault",
		ParryEffect = "DefaultParryEffect",
		Sounds = table.freeze({ Parry = "", Hit = "" }),
	}),
}

return table.freeze(Definitions)
