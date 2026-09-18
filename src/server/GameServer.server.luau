local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local root = ServerScriptService:WaitForChild("Game")
local Registry = require(root:WaitForChild("CombatantRegistry"))
local CombatCore = require(root:WaitForChild("CombatCore"))
local BallCore = require(root:WaitForChild("BallCore"))
local TrainingOpponent = require(root:WaitForChild("TrainingOpponent"))
local DuelService = require(root:WaitForChild("DuelService"))

local remotes = ReplicatedStorage:WaitForChild("Game"):WaitForChild("Remotes")
local parryIntent = remotes:WaitForChild("ParryIntent")
local snapshot = remotes:WaitForChild("BallSnapshot")
local combatEvent = remotes:WaitForChild("CombatEvent")
local gameplay = workspace:WaitForChild("Game"):WaitForChild("Arena"):WaitForChild("Gameplay")
local npcContainer = gameplay:WaitForChild("NPCs")

Players.CharacterAutoLoads = false
local registry = Registry.new()
local combat = CombatCore.new(registry, combatEvent)
local ball = BallCore.new(registry, snapshot, combatEvent, gameplay)
combat:SetBall(ball)
local opponent = TrainingOpponent.new(registry, combat, ball, npcContainer)
local duel = DuelService.new(registry, combat, ball, opponent, gameplay)

local playerConnections = {}
local function addPlayer(player)
	if registry:GetByPlayer(player) then return end
	registry:RegisterPlayer(player)
	playerConnections[player] = player.CharacterAdded:Connect(function(character)
		local combatant = registry:GetByPlayer(player)
		if combatant then
			task.spawn(function()
				local CharacterUtil = require(ReplicatedStorage.Game.Shared.Util.CharacterUtil)
				if CharacterUtil.WaitForR15(character, 8) and registry:GetByPlayer(player) == combatant then registry:BindCharacter(combatant, character) end
			end)
		end
	end)
end

local function removePlayer(player)
	local connection = playerConnections[player]
	if connection then connection:Disconnect(); playerConnections[player] = nil end
	registry:Unregister(registry:GetByPlayer(player))
end

for _, player in Players:GetPlayers() do addPlayer(player) end
local connections = {
	Players.PlayerAdded:Connect(addPlayer),
	Players.PlayerRemoving:Connect(removePlayer),
	parryIntent.OnServerEvent:Connect(function(player) combat:TryParry(registry:GetByPlayer(player)) end),
	RunService.Heartbeat:Connect(function(dt) duel:Update(dt) end),
}

game:BindToClose(function()
	for _, connection in connections do connection:Disconnect() end
	for _, connection in playerConnections do connection:Disconnect() end
	duel:Destroy()
	registry:Destroy()
end)
