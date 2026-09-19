local emptyCharacter = table.freeze({ Idle = "", Walk = "", Run = "", Jump = "", Fall = "" })

return table.freeze({
	CharacterSets = table.freeze({ Default = emptyCharacter }),
	WeaponSets = table.freeze({
		TrainingBladeDefault = table.freeze({
			Equip = "",
			ParryAttempt = "",
			ParryHit = table.freeze({ Default = "", Left = "", Right = "", Up = "" }),
			ParryMiss = table.freeze({ Default = "", Left = "", Right = "", Up = "" }),
		}),
	}),
})
