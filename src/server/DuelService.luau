local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local CharacterUtil = require(ReplicatedStorage.Game.Shared.Util.CharacterUtil)
local CombatTypes = require(ReplicatedStorage.Game.Shared.Combat.CombatTypes)
local State = CombatTypes.DuelState

local DuelService = {}
DuelService.__index = DuelService

function DuelService.new(registry, combat, ball, opponent, gameplay, combatEvent)
	local spawns = gameplay:WaitForChild("SpawnPoints"):GetChildren()
	table.sort(spawns, function(a, b) return a.Name < b.Name end)
	return setmetatable({ Registry = registry, Combat = combat, Ball = ball, Opponent = opponent, Event = combatEvent, Spawns = spawns, State = State.Waiting, Deadline = 0, Busy = false }, DuelService)
end

function DuelService:_transition(nextState, duration)
	assert(self.State ~= nextState, "duplicate duel transition: " .. nextState)
	local previous = self.State
	self.State = nextState
	self.Deadline = if duration then workspace:GetServerTimeNow() + duration else 0
	if self.Event then
		self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.DuelStateChanged, {
			Previous = previous, State = nextState,
		}))
	end
	if Config.Telemetry.Enabled then print(string.format("[COMBAT] duel=%s->%s", previous, nextState)) end
end

function DuelService:_firstPlayer()
	return Players:GetPlayers()[1]
end

function DuelService:_readyPlayer(player, cframe)
	local combatant = self.Registry:GetByPlayer(player)
	if not combatant then return nil end
	local body = player.Character and CharacterUtil.Resolve(player.Character)
	if not body or body.Humanoid.Health <= 0 then
		local ok = pcall(function() player:LoadCharacterAsync() end)
		if not ok then return nil end
		body = player.Character and CharacterUtil.WaitForR15(player.Character, Config.Duel.CharacterTimeout)
	end
	if not body then return nil end
	self.Registry:BindCharacter(combatant, body.Character)
	body.Character:PivotTo(cframe)
	self.Registry:SetAlive(combatant, true)
	return combatant
end

function DuelService:_prepare()
	self.Combat:SetActive(false)
	self.Ball:Stop()
	self.Opponent:Clear()
	local player = self:_firstPlayer()
	if not player then return false end
	local playerPosition = self.Spawns[1].Position + Vector3.new(0, 3, 0)
	local npcPosition = self.Spawns[2].Position + Vector3.new(0, 3, 0)
	local playerCFrame = CFrame.lookAt(playerPosition, Vector3.new(npcPosition.X, playerPosition.Y, npcPosition.Z))
	local npcCFrame = CFrame.lookAt(npcPosition, Vector3.new(playerPosition.X, npcPosition.Y, playerPosition.Z))
	local playerCombatant = self:_readyPlayer(player, playerCFrame)
	if not playerCombatant then return false end
	local npc = self.Opponent:Spawn(npcCFrame)
	if not npc then return false end
	self:_transition(State.Countdown, Config.Duel.Countdown)
	return true
end

function DuelService:_finish()
	self.Combat:SetActive(false)
	self.Ball:Stop()
	self:_transition(State.Ending, Config.Duel.Ending)
end

function DuelService:_step(dt)
	local now = workspace:GetServerTimeNow()
	if self.State == State.Waiting then
		if self:_firstPlayer() then self:_prepare() end
	elseif self.State == State.Countdown then
		if now >= self.Deadline then
			local player = self.Registry:GetByPlayer(self:_firstPlayer())
			if not self.Registry:IsAlive(player) or not self.Registry:IsAlive(self.Opponent.Combatant) then self:_transition(State.Resetting); return end
			self.Combat:SetActive(true)
			self.Ball:Start(player)
			self:_transition(State.Active)
		end
	elseif self.State == State.Active then
		self.Ball:Update(dt, function()
			self.Combat:UpdatePending()
			self.Opponent:Update()
		end)
		if #self.Registry:GetAlive() <= 1 then self:_finish() end
	elseif self.State == State.Ending and now >= self.Deadline then
		self:_transition(State.Resetting)
		self.Opponent:Clear()
		local player = self:_firstPlayer()
		local combatant = player and self.Registry:GetByPlayer(player)
		if combatant and combatant.Alive then self.Registry:SetAlive(combatant, false) end
	elseif self.State == State.Resetting then
		self:_transition(State.Waiting)
	end
end

function DuelService:Update(dt)
	if self.Busy then return end
	self.Busy = true
	local ok, failure = xpcall(function() self:_step(dt) end, debug.traceback)
	self.Busy = false
	if not ok then error(failure) end
end

function DuelService:Destroy()
	self.Combat:SetActive(false)
	self.Ball:Stop()
	self.Opponent:Clear()
end

return DuelService
