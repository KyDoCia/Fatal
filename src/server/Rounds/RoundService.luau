local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.RoundConfig)
local CombatConfig = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local CharacterUtil = require(ReplicatedStorage.Game.Shared.Util.CharacterUtil)

local RoundService = {}
RoundService.__index = RoundService

function RoundService.new(dependencies)
	local self = setmetatable({
		State = "Waiting",
		Deadline = 0,
		RoundNumber = 0,
		WinnerId = "",
		WinnerName = "",
		Participants = {},
		SnapshotClock = 0,
		Busy = false,
	}, RoundService)
	for name, dependency in dependencies do self[name] = dependency end
	self.AliveConnection = self.Combatants.AliveChanged.Event:Connect(function(_, alive)
		if not alive and self.State == "Playing" then self:Publish() end
	end)
	return self
end

function RoundService:_enoughPlayers()
	local count = #Players:GetPlayers()
	return count >= Config.MinPlayers
end

function RoundService:_publicParticipants()
	local output = {}
	for _, combatant in self.Participants do
		table.insert(output, {
			Id = combatant.Id,
			Kind = combatant.Kind,
			DisplayName = combatant.Player and combatant.Player.DisplayName or combatant.Character.Name,
			Alive = self.Combatants:IsAlive(combatant.Id),
			Character = combatant.Character,
		})
	end
	return output
end

function RoundService:Publish()
	self.Remote:FireAllClients({
		State = self.State,
		Deadline = self.Deadline,
		Round = self.RoundNumber,
		AliveCount = #self.Combatants:GetAlive(),
		WinnerId = self.WinnerId,
		WinnerName = self.WinnerName,
		Participants = self:_publicParticipants(),
		ServerTime = workspace:GetServerTimeNow(),
	})
end

function RoundService:_transition(state, duration)
	self.State = state
	self.Deadline = if duration then workspace:GetServerTimeNow() + duration else 0
	if CombatConfig.DebugCombat then print("[Fatal/Round]", state, self.RoundNumber) end
	self:Publish()
end

function RoundService:_readyPlayer(player, spawnPoint)
	local combatant = self.Combatants:GetByPlayer(player)
	if not combatant then return nil end
	local character = player.Character
	local body = character and CharacterUtil.Resolve(character)
	if not body or body.Humanoid.Health <= 0 then
		local ok = pcall(function() player:LoadCharacterAsync() end)
		if not ok then return nil end
		character = player.Character
		body = character and CharacterUtil.WaitForR15(character, Config.CharacterTimeout)
	end
	if not body then return nil end
	self.Combatants:BindCharacter(combatant, character)
	character:PivotTo(spawnPoint.CFrame + Vector3.new(0, Config.SpawnYOffset, 0))
	self.Weapons:Equip(character)
	self.Combatants:SetAlive(combatant.Id, true, "CombatLabPrepare")
	return combatant
end

function RoundService:_prepare()
	self.Ball:Stop()
	self.NPCs:Clear()
	table.clear(self.Participants)
	self.WinnerId = ""
	self.WinnerName = ""
	local points = self.Arena.Gameplay.SpawnPoints:GetChildren()
	table.sort(points, function(a, b) return a.Name < b.Name end)
	local index = 1
	for playerIndex, player in Players:GetPlayers() do
		if Config.CombatLab and playerIndex > 1 then break end
		local combatant = self:_readyPlayer(player, points[((index - 1) % #points) + 1])
		if combatant then table.insert(self.Participants, combatant); index += 1 end
	end
	if RunService:IsStudio() then
		local npcPoints = {}
		for npcIndex = 1, Config.StudioNPCCount do npcPoints[npcIndex] = points[((index - 1) % #points) + 1]; index += 1 end
		for _, combatant in self.NPCs:Spawn(Config.StudioNPCCount, npcPoints) do table.insert(self.Participants, combatant) end
	end
	return #self.Participants >= 2
end

function RoundService:_endRound(winner)
	self.Combat:SetPlaying(false)
	self.Ball:Stop()
	self.WinnerId = winner and winner.Id or ""
	self.WinnerName = winner and (winner.Player and winner.Player.DisplayName or (winner.Character and winner.Character.Name) or winner.Id) or ""
	self:_transition("Ending", Config.EndingDuration)
	if CombatConfig.DebugCombat then print("[Fatal/Round] winner", self.WinnerId) end
end

function RoundService:_cleanup()
	self.Ball:Stop()
	self.NPCs:Clear()
	for _, combatant in self.Participants do
		if combatant.Kind == "Player" and self.Combatants:Get(combatant.Id) then self.Combatants:SetAlive(combatant.Id, false, "CombatLabReset") end
	end
	table.clear(self.Participants)
end

function RoundService:RemovePlayer(player)
	local combatant = self.Combatants:GetByPlayer(player)
	if combatant then self.Combatants:Unregister(combatant.Id) end
end

function RoundService:_update(dt)
	local now = workspace:GetServerTimeNow()
	if self.State == "Waiting" then
		if self:_enoughPlayers() then
			if Config.CombatLab then
				if self:_prepare() then self:_transition("Starting", Config.CountdownDuration) end
			else self:_transition("Intermission", Config.IntermissionDuration) end
		end
	elseif self.State == "Intermission" then
		if not self:_enoughPlayers() then self:_transition("Waiting")
		elseif now >= self.Deadline then
			if self:_prepare() then self:_transition("Starting", Config.CountdownDuration) else self:_transition("Waiting") end
		end
	elseif self.State == "Starting" then
		if #self.Combatants:GetAlive() < 2 then self:_cleanup(); self:_transition("Waiting")
		elseif now >= self.Deadline then
			self.RoundNumber += 1
			self.Combat:SetPlaying(true)
			self.Ball:Start()
			self:_transition("Playing")
		end
	elseif self.State == "Playing" then
		self.Ball:Update(dt)
		self.NPCs:Update(dt)
		for _, combatant in self.Combatants:GetAlive() do
			if combatant.RootPart.Position.Y < self.Arena.Gameplay.KillBounds.Position.Y then
				self.Combatants:SetAlive(combatant.Id, false, "KillBounds")
			end
		end
		local alive = self.Combatants:GetAlive()
		if #alive <= 1 then self:_endRound(alive[1]) end
	elseif self.State == "Ending" and now >= self.Deadline then
		self:_cleanup()
		if self:_enoughPlayers() then
			if Config.CombatLab then
				if self:_prepare() then self:_transition("Starting", Config.CountdownDuration) else self:_transition("Waiting") end
			else self:_transition("Intermission", Config.IntermissionDuration) end
		else self:_transition("Waiting") end
	end
	self.SnapshotClock += dt
	if self.SnapshotClock >= Config.SnapshotInterval then self.SnapshotClock = 0; self:Publish() end
end

function RoundService:Update(dt)
	if self.Busy then return end
	self.Busy = true
	local ok, failure = xpcall(function() self:_update(dt) end, debug.traceback)
	self.Busy = false
	if not ok then error(failure) end
end

function RoundService:Destroy()
	if self.AliveConnection then self.AliveConnection:Disconnect(); self.AliveConnection = nil end
	self:_cleanup()
end

return RoundService
