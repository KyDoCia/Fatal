local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local CharacterUtil = require(ReplicatedStorage.Game.Shared.Util.CharacterUtil)
local CombatTypes = require(ReplicatedStorage.Game.Shared.Combat.CombatTypes)
local State = CombatTypes.DuelState

local DuelService = {}
DuelService.__index = DuelService

function DuelService.IsWinEligible(humanCount)
	return humanCount >= Config.Rewards.MinimumHumansForWin
end

function DuelService.ShouldSpawnTrainingBot(humanCount, settings)
	settings = settings or Config.NPC
	if not settings.Enabled or humanCount == 0 then return false end
	return if settings.SoloOnly then humanCount == 1 else true
end

function DuelService.new(registry, combat, ball, opponent, gameplay, combatEvent, profiles)
	local spawns = gameplay:WaitForChild("SpawnPoints"):GetChildren()
	table.sort(spawns, function(a, b) return a.Name < b.Name end)
	return setmetatable({ Registry = registry, Combat = combat, Ball = ball, Opponent = opponent, Event = combatEvent,
		Profiles = profiles, Spawns = spawns, State = State.Waiting, Deadline = 0, Busy = false,
		RoundId = 0, WinEligible = false, RewardGranted = false }, DuelService)
end

function DuelService:_transition(nextState, duration)
	assert(self.State ~= nextState, "duplicate duel transition: " .. nextState)
	local previous = self.State
	self.State = nextState
	self.Deadline = if duration then workspace:GetServerTimeNow() + duration else 0
	self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.DuelStateChanged, { Previous = previous, State = nextState }))
	if Config.Telemetry.Enabled then print(string.format("[COMBAT] duel=%s->%s round=%d", previous, nextState, self.RoundId)) end
end

function DuelService:_readyPlayer(player, cframe)
	local combatant = self.Registry:GetByPlayer(player)
	if not combatant or (self.Profiles and not self.Profiles:Get(player)) then return nil end
	local body = player.Character and CharacterUtil.Resolve(player.Character)
	if not body or body.Humanoid.Health <= 0 then
		if not pcall(function() player:LoadCharacterAsync() end) then return nil end
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
	local humans = {}
	for index, player in Players:GetPlayers() do
		local spawn = self.Spawns[index]
		if not spawn then break end
		local position = spawn.Position + Vector3.new(0, 3, 0)
		local actor = self:_readyPlayer(player, CFrame.lookAt(position, Vector3.new(0, position.Y, 0)))
		if actor then table.insert(humans, actor) end
	end
	if #humans == 0 then return false end
	if DuelService.ShouldSpawnTrainingBot(#humans) then
		local spawn = self.Spawns[2]
		self.Opponent:Spawn(CFrame.lookAt(spawn.Position + Vector3.new(0, 3, 0), humans[1].CenterPart.Position))
	end
	self.RoundId += 1
	self.WinEligible = DuelService.IsWinEligible(#humans)
	self.RewardGranted = false
	self:_transition(State.Countdown, Config.Duel.Countdown)
	return true
end

function DuelService:_finish()
	self.Combat:SetActive(false)
	self.Ball:Stop()
	local winner = self.Registry:GetAlive()[1]
	local rewarded = false
	if self.WinEligible and not self.RewardGranted and winner and winner.Kind == "Player" and self.Profiles then
		rewarded = self.Profiles:Award(winner.Player, { Wins = 1, Coins = Config.Rewards.WinnerCoins, Gems = Config.Rewards.WinnerGems }, "round:" .. self.RoundId)
		self.RewardGranted = rewarded
	end
	self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.RoundEnded, {
		RoundId = self.RoundId, WinnerId = winner and winner.Id or "", WinEligible = self.WinEligible, Rewarded = rewarded,
	}))
	self:_transition(State.Ending, Config.Duel.Ending)
end

function DuelService:HandleDeparture(combatant)
	if self.State == State.Active and combatant and combatant.Alive then
		self.Event:FireAllClients(CombatTypes.Event(CombatTypes.EventKind.CombatantEliminated, { CombatantId = combatant.Id, Reason = "LEFT" }))
	end
	local remainingHumans = #Players:GetPlayers()
	if combatant and combatant.Player then
		for _, player in Players:GetPlayers() do if player == combatant.Player then remainingHumans -= 1; break end end
	end
	if remainingHumans == 0 and self.State ~= State.Waiting and self.State ~= State.Resetting then
		self.Combat:SetActive(false)
		self.Ball:Stop()
		self.Opponent:Clear()
		self:_transition(State.Resetting)
	end
end

function DuelService:_step(dt)
	local now = workspace:GetServerTimeNow()
	if self.State == State.Waiting then
		if #Players:GetPlayers() > 0 then self:_transition(State.Intermission, Config.Duel.Intermission) end
	elseif self.State == State.Intermission then
		if #Players:GetPlayers() == 0 then self:_transition(State.Waiting)
		elseif now >= self.Deadline and not self:_prepare() then self.Deadline = now + Config.Duel.Intermission end
	elseif self.State == State.Countdown and now >= self.Deadline then
		if #self.Registry:GetAlive() < 2 then self:_transition(State.Resetting); return end
		self.Combat:SetActive(true)
		self.Ball:Start(self.Registry:GetAlive()[1])
		self:_transition(State.Active)
	elseif self.State == State.Active then
		self.Ball:Update(dt, function() self.Combat:UpdatePending(); self.Opponent:Update() end)
		local alive = self.Registry:GetAlive()
		if #alive <= 1 then
			self:_finish()
		elseif not self.Ball:IsTracking() then
			self.Ball:Stop()
			self.Ball:Start(alive[1])
		end
	elseif self.State == State.Ending and now >= self.Deadline then
		self:_transition(State.Resetting)
		self.Opponent:Clear()
		for _, combatant in self.Registry:GetAlive() do self.Registry:SetAlive(combatant, false) end
	elseif self.State == State.Resetting then
		if #Players:GetPlayers() > 0 then self:_transition(State.Intermission, Config.Duel.Intermission) else self:_transition(State.Waiting) end
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
