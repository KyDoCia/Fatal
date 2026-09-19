local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local root = ServerScriptService:WaitForChild("Game")
local Config = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local Registry = require(root:WaitForChild("CombatantRegistry"))
local CombatCore = require(root:WaitForChild("CombatCore"))
local BallCore = require(root:WaitForChild("BallCore"))
local TrainingOpponent = require(root:WaitForChild("TrainingOpponent"))
local DuelService = require(root:WaitForChild("DuelService"))
local ProfileService = require(root:WaitForChild("ProfileService"))
local TargetSelector = require(root:WaitForChild("TargetSelector"))
local InventoryService = require(root:WaitForChild("InventoryService"))

local remotes = ReplicatedStorage:WaitForChild("Game"):WaitForChild("Remotes")
local parryIntent = remotes:WaitForChild("ParryIntent")
local snapshot = remotes:WaitForChild("BallSnapshot")
local combatEvent = remotes:WaitForChild("CombatEvent")
local inventoryRequest = remotes:WaitForChild("InventoryRequest")
local inventoryState = remotes:WaitForChild("InventoryState")
local gameplay = workspace:WaitForChild("Game"):WaitForChild("Arena"):WaitForChild("Gameplay")
local npcContainer = gameplay:WaitForChild("NPCs")

Players.CharacterAutoLoads = false
local registry = Registry.new()
local profileStore = ProfileService.new(if RunService:IsStudio() then nil else DataStoreService:GetDataStore("FatalProfiles_v1"))
local inventory = InventoryService.new(profileStore, inventoryState)
local combat = CombatCore.new(registry, combatEvent)
local ball = BallCore.new(registry, snapshot, combatEvent, gameplay, TargetSelector)
combat:SetBall(ball)
local opponent = TrainingOpponent.new(registry, combat, ball, npcContainer)
local duel = DuelService.new(registry, combat, ball, opponent, gameplay, combatEvent, profileStore)

local playerConnections = {}
local intentReadyAt = {}
local function addPlayer(player)
	if registry:GetByPlayer(player) then return end
	registry:RegisterPlayer(player)
	profileStore:Load(player)
	inventory:Sync(player)
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
	local combatant = registry:GetByPlayer(player)
	duel:HandleDeparture(combatant)
	registry:Unregister(combatant)
	profileStore:Release(player)
	intentReadyAt[player] = nil
end

for _, player in Players:GetPlayers() do addPlayer(player) end
local connections = {
	Players.PlayerAdded:Connect(addPlayer),
	Players.PlayerRemoving:Connect(removePlayer),
	parryIntent.OnServerEvent:Connect(function(player)
		local now = workspace:GetServerTimeNow()
		if now < (intentReadyAt[player] or 0) then return end
		intentReadyAt[player] = now + Config.Parry.IntentMinInterval
		combat:TryParry(registry:GetByPlayer(player))
	end),
	inventoryRequest.OnServerEvent:Connect(function(player, action, itemId)
		if action == "EquipWeapon" then inventory:Equip(player, itemId)
		elseif action == "GetState" then inventory:Sync(player) end
	end),
	RunService.Heartbeat:Connect(function(dt) duel:Update(dt) end),
}

game:BindToClose(function()
	for _, connection in connections do connection:Disconnect() end
	for _, connection in playerConnections do connection:Disconnect() end
	duel:Destroy()
	profileStore:Destroy()
	registry:Destroy()
end)
