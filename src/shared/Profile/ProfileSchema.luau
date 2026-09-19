local Schema = {}
Schema.Version = 1

function Schema.New()
	return {
		Version = Schema.Version,
		Stats = { Wins = 0 },
		Currency = { Coins = 0, Gems = 0 },
		Inventory = {},
		Equipped = { Weapon = "TrainingBlade", Ball = "StandardBall" },
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
	return profile
end

return table.freeze(Schema)
