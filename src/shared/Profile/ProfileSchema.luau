local Schema = {}
Schema.Version = 1

function Schema.New()
	return {
		Version = Schema.Version,
		Stats = { Wins = 0 },
		Currency = { Coins = 0, Gems = 0 },
		Inventory = { Weapons = { TrainingBlade = true }, Balls = {}, Effects = {}, Animations = {} },
		Equipped = { Weapon = "TrainingBlade", Ball = "StandardBall", ParryEffect = "DefaultParryEffect", CharacterAnimationSet = "Default", WeaponAnimationSet = "TrainingBladeDefault" },
	}
end

function Schema.Normalize(value)
	local profile = Schema.New()
	if type(value) ~= "table" then return profile end
	if type(value.Stats) == "table" and type(value.Stats.Wins) == "number" then profile.Stats.Wins = math.max(0, math.floor(value.Stats.Wins)) end
	if type(value.Currency) == "table" then
		if type(value.Currency.Coins) == "number" then profile.Currency.Coins = math.max(0, math.floor(value.Currency.Coins)) end
		if type(value.Currency.Gems) == "number" then profile.Currency.Gems = math.max(0, math.floor(value.Currency.Gems)) end
	end
	if type(value.Inventory) == "table" and type(value.Inventory.Weapons) == "table" then
		for id, owned in value.Inventory.Weapons do if type(id) == "string" and owned == true then profile.Inventory.Weapons[id] = true end end
	end
	if type(value.Inventory) == "table" and type(value.Inventory.Animations) == "table" then
		for id, owned in value.Inventory.Animations do if type(id) == "string" and owned == true then profile.Inventory.Animations[id] = true end end
	end
	if type(value.Equipped) == "table" and type(value.Equipped.Weapon) == "string" and profile.Inventory.Weapons[value.Equipped.Weapon] then profile.Equipped.Weapon = value.Equipped.Weapon end
	if type(value.Equipped) == "table" then
		local characterSet = value.Equipped.CharacterAnimationSet
		if characterSet == "Default" or (type(characterSet) == "string" and profile.Inventory.Animations[characterSet]) then profile.Equipped.CharacterAnimationSet = characterSet end
		local weaponSet = value.Equipped.WeaponAnimationSet
		if weaponSet == "TrainingBladeDefault" or (type(weaponSet) == "string" and profile.Inventory.Animations[weaponSet]) then profile.Equipped.WeaponAnimationSet = weaponSet end
	end
	return profile
end

return table.freeze(Schema)
