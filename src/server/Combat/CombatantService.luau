local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterUtil = require(ReplicatedStorage.Game.Shared.Util.CharacterUtil)

local CombatantService = {}
CombatantService.__index = CombatantService

function CombatantService.new()
	return setmetatable({
		_byId = {},
		_byPlayer = {},
		_deathConnections = {},
		AliveChanged = Instance.new("BindableEvent"),
	}, CombatantService)
end

function CombatantService:_disconnectDeath(id)
	local connection = self._deathConnections[id]
	if connection then connection:Disconnect(); self._deathConnections[id] = nil end
end

-- Registration owns stable identity. Character binding and round life are separate.
function CombatantService:RegisterPlayer(player)
	local id = "P:" .. player.UserId
	assert(self._byId[id] == nil, "duplicate combatant id: " .. id)
	local combatant = { Id = id, Kind = "Player", Player = player, Character = nil, Humanoid = nil, RootPart = nil, Alive = false }
	self._byId[id] = combatant
	self._byPlayer[player] = combatant
	return combatant
end

function CombatantService:RegisterNPC(model)
	local id = model:GetAttribute("CombatantId")
	assert(type(id) == "string" and id ~= "", "NPC requires CombatantId attribute")
	assert(self._byId[id] == nil, "duplicate combatant id: " .. id)
	local combatant = { Id = id, Kind = "NPC", Player = nil, Character = nil, Humanoid = nil, RootPart = nil, Alive = false }
	self._byId[id] = combatant
	self:BindCharacter(combatant, model)
	return combatant
end

function CombatantService:BindCharacter(subject, character)
	local combatant = if type(subject) == "string" then self._byId[subject] else subject
	assert(combatant and self._byId[combatant.Id] == combatant, "cannot bind an unregistered combatant")
	if combatant.Character == character and combatant.Humanoid and combatant.RootPart then return combatant end
	local body = CharacterUtil.Resolve(character)
	assert(body, "combatant requires a complete R15 character: " .. combatant.Id)
	self:_disconnectDeath(combatant.Id)
	combatant.Character = body.Character
	combatant.Humanoid = body.Humanoid
	combatant.RootPart = body.RootPart
	combatant.Alive = false
	self._deathConnections[combatant.Id] = body.Humanoid.Died:Connect(function()
		self:SetAlive(combatant.Id, false, "HumanoidDied")
	end)
	return combatant
end

function CombatantService:Unregister(id)
	local combatant = self._byId[id]
	if not combatant then return false end
	self:_disconnectDeath(id)
	self._byId[id] = nil
	if combatant.Player then self._byPlayer[combatant.Player] = nil end
	return true
end

function CombatantService:Get(id) return self._byId[id] end
function CombatantService:GetByPlayer(player) return self._byPlayer[player] end

function CombatantService:GetAlive()
	local alive = {}
	for _, combatant in self._byId do if self:IsAlive(combatant.Id) then table.insert(alive, combatant) end end
	table.sort(alive, function(a, b) return a.Id < b.Id end)
	return alive
end

function CombatantService:IsAlive(id)
	local combatant = self._byId[id]
	return combatant ~= nil and combatant.Alive and combatant.Character ~= nil and combatant.Character.Parent ~= nil
		and combatant.RootPart ~= nil and combatant.RootPart.Parent ~= nil and combatant.Humanoid ~= nil and combatant.Humanoid.Health > 0
end

function CombatantService:SetAlive(id, alive, reason)
	local combatant = self._byId[id]
	if not combatant or combatant.Alive == alive then return false end
	if alive then
		assert(combatant.Character and combatant.Humanoid and combatant.RootPart and combatant.Humanoid.Health > 0, "cannot activate unbound/dead combatant: " .. id)
	end
	combatant.Alive = alive
	if not alive and combatant.Humanoid and combatant.Humanoid.Health > 0 then combatant.Humanoid.Health = 0 end
	self.AliveChanged:Fire(combatant, alive, reason)
	return true
end

function CombatantService:ClearNPCs()
	local ids = {}
	for id, combatant in self._byId do if combatant.Kind == "NPC" then table.insert(ids, id) end end
	for _, id in ids do self:Unregister(id) end
end

function CombatantService:Clear()
	local ids = {}
	for id in self._byId do table.insert(ids, id) end
	for _, id in ids do self:Unregister(id) end
end

function CombatantService:Destroy()
	self:Clear()
	self.AliveChanged:Destroy()
end

return CombatantService
