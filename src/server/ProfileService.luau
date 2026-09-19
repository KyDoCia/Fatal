local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Schema = require(ReplicatedStorage.Game.Shared.Profile.ProfileSchema)

local ProfileService = {}
ProfileService.__index = ProfileService

local function validAmount(value)
	return type(value) == "number" and value >= 0 and value < math.huge and value == math.floor(value)
end

function ProfileService.new(store)
	return setmetatable({ Store = store, Profiles = {}, AwardReceipts = {} }, ProfileService)
end

function ProfileService:_sync(player)
	local profile = self.Profiles[player]
	local stats = player:FindFirstChild("leaderstats")
	local wins = stats and stats:FindFirstChild("Wins")
	if wins and profile then wins.Value = profile.Stats.Wins end
end

function ProfileService:Load(player)
	assert(not self.Profiles[player], "profile already loaded")
	local data
	if self.Store then
		local ok, result = pcall(function() return self.Store:GetAsync("P:" .. player.UserId) end)
		if ok then data = result else warn("profile load failed; player is ineligible until reconnect"); return nil end
	end
	self.Profiles[player] = Schema.Normalize(data)
	self.AwardReceipts[player] = {}
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	local wins = Instance.new("IntValue")
	wins.Name = "Wins"
	wins.Parent = leaderstats
	self:_sync(player)
	return self.Profiles[player]
end

function ProfileService:Get(player) return self.Profiles[player] end

function ProfileService:Award(player, delta, receipt)
	local profile = self.Profiles[player]
	if not profile or type(delta) ~= "table" or type(receipt) ~= "string" or receipt == "" then return false, "INVALID" end
	if self.AwardReceipts[player][receipt] then return false, "DUPLICATE" end
	local wins, coins, gems = delta.Wins or 0, delta.Coins or 0, delta.Gems or 0
	if not validAmount(wins) or not validAmount(coins) or not validAmount(gems) then return false, "INVALID_AMOUNT" end
	self.AwardReceipts[player][receipt] = true
	profile.Stats.Wins += wins
	profile.Currency.Coins += coins
	profile.Currency.Gems += gems
	self:_sync(player)
	return true
end

function ProfileService:Spend(player, currency, amount)
	local profile = self.Profiles[player]
	if not profile or (currency ~= "Coins" and currency ~= "Gems") or not validAmount(amount) then return false, "INVALID" end
	if profile.Currency[currency] < amount then return false, "INSUFFICIENT" end
	profile.Currency[currency] -= amount
	return true
end

function ProfileService:Save(player)
	local profile = self.Profiles[player]
	if not profile or not self.Store then return profile ~= nil end
	local ok, failure = pcall(function()
		self.Store:UpdateAsync("P:" .. player.UserId, function() return profile end)
	end)
	if not ok then warn("profile save failed: " .. tostring(failure)) end
	return ok
end

function ProfileService:Release(player)
	self:Save(player)
	self.Profiles[player] = nil
	self.AwardReceipts[player] = nil
end

function ProfileService:Destroy()
	for player in self.Profiles do self:Release(player) end
end

return ProfileService
