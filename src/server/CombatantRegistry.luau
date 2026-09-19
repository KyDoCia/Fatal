local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterUtil = require(ReplicatedStorage.Game.Shared.Util.CharacterUtil)

local Registry = {}
Registry.__index = Registry

function Registry.new()
	return setmetatable({ ById = {}, ByPlayer = {}, DeathConnections = {} }, Registry)
end

function Registry:RegisterPlayer(player)
	local id = "P:" .. player.UserId
	assert(not self.ById[id], "duplicate Player combatant: " .. id)
	local combatant = { Id = id, Kind = "Player", Player = player, Alive = false }
	self.ById[id] = combatant
	self.ByPlayer[player] = combatant
	return combatant
end

function Registry:RegisterNPC(model)
	local id = model:GetAttribute("CombatantId")
	assert(type(id) == "string" and id ~= "" and not self.ById[id], "invalid or duplicate NPC combatant")
	local combatant = { Id = id, Kind = "NPC", Player = nil, Alive = false }
	self.ById[id] = combatant
	self:BindCharacter(combatant, model)
	return combatant
end

function Registry:BindCharacter(combatant, character)
	assert(combatant and self.ById[combatant.Id] == combatant, "unregistered combatant")
	if combatant.Character == character and combatant.Humanoid and combatant.RootPart and combatant.CenterPart then return combatant end
	local body = CharacterUtil.Resolve(character)
	assert(body, "combatant requires complete R15 character")
	local old = self.DeathConnections[combatant.Id]
	if old then old:Disconnect() end
	combatant.Character = body.Character
	combatant.Humanoid = body.Humanoid
	combatant.RootPart = body.RootPart
	combatant.CenterPart = body.CenterPart
	combatant.Alive = false
	self.DeathConnections[combatant.Id] = body.Humanoid.Died:Connect(function() combatant.Alive = false end)
	return combatant
end

function Registry:GetByPlayer(player) return self.ByPlayer[player] end
function Registry:Get(id) return self.ById[id] end

function Registry:IsAlive(combatant)
	return combatant ~= nil and self.ById[combatant.Id] == combatant and combatant.Alive and combatant.Character and combatant.Character.Parent
		and combatant.Humanoid and combatant.Humanoid.Health > 0 and combatant.CenterPart and combatant.CenterPart.Parent
end

function Registry:SetAlive(combatant, alive)
	if not combatant or combatant.Alive == alive then return false end
	if alive then assert(combatant.Humanoid and combatant.Humanoid.Health > 0, "cannot activate dead combatant") end
	combatant.Alive = alive
	if not alive and combatant.Humanoid and combatant.Humanoid.Health > 0 then combatant.Humanoid.Health = 0 end
	return true
end

function Registry:GetAlive()
	local alive = {}
	for _, combatant in self.ById do if self:IsAlive(combatant) then table.insert(alive, combatant) end end
	table.sort(alive, function(a, b) return a.Id < b.Id end)
	return alive
end

function Registry:Unregister(combatant)
	if not combatant or self.ById[combatant.Id] ~= combatant then return false end
	local connection = self.DeathConnections[combatant.Id]
	if connection then connection:Disconnect(); self.DeathConnections[combatant.Id] = nil end
	self.ById[combatant.Id] = nil
	if combatant.Player then self.ByPlayer[combatant.Player] = nil end
	return true
end

function Registry:Destroy()
	local values = {}
	for _, combatant in self.ById do table.insert(values, combatant) end
	for _, combatant in values do self:Unregister(combatant) end
end

return Registry
