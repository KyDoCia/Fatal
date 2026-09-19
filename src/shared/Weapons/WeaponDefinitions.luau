local Definitions = {
	TrainingBlade = table.freeze({
		Id = "TrainingBlade",
		AssetName = "TrainingBlade",
		Grip = CFrame.new(0, -0.85, 0) * CFrame.Angles(0, 0, math.rad(-90)),
		Animations = table.freeze({ Equip = "", Idle = "", Parry = "" }),
		Sounds = table.freeze({ Parry = "", Hit = "" }),
	}),
}

return table.freeze(Definitions)
