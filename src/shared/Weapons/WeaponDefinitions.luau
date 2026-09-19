local Definitions = {
	TrainingBlade = table.freeze({
		Id = "TrainingBlade",
		AssetName = "TrainingBlade",
		Grip = table.freeze({
			Hand = "RightHand",
			HandAttachment = "RightGripAttachment",
			WeaponAttachment = "WeaponGripAttachment",
		}),
		AnimationSet = "TrainingBladeDefault",
		ParryEffect = "DefaultParryEffect",
		Sounds = table.freeze({ Parry = "", Hit = "" }),
	}),
}

return table.freeze(Definitions)
