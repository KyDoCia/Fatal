local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local PhysicsService = game:GetService("PhysicsService")
local CollectionService = game:GetService("CollectionService")
local StarterGui = game:GetService("StarterGui")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local function child(parent, name, className, timeout)
	local value = parent:WaitForChild(name, timeout or 10)
	assert(value and value:IsA(className), string.format("FATAL startup missing %s.%s (%s)", parent:GetFullName(), name, className))
	return value
end

local serverRoot = child(ServerScriptService, "Game", "Folder")
assert(script == child(serverRoot, "GameServer", "Script"), "FATAL rejected a non-canonical server bootstrap")
assert(ServerScriptService:FindFirstChild("Server") == nil, "FATAL rejected legacy server root")

local replicatedGame = child(ReplicatedStorage, "Game", "Folder")
local shared = child(replicatedGame, "Shared", "Folder")
local config = child(shared, "Config", "Folder")
for _, name in { "CombatConfig", "NPCConfig", "UIConfig", "UITheme" } do require(child(config, name, "ModuleScript")) end
local characterUtil = require(child(child(shared, "Util", "Folder"), "CharacterUtil", "ModuleScript"))
local roundConfig = require(child(config, "RoundConfig", "ModuleScript"))
for _, guiName in { "HUD", "RoundGui", "CombatGui" } do child(StarterGui, guiName, "ScreenGui", roundConfig.StartupTimeout) end

local remotes = child(replicatedGame, "Remotes", "Folder")
local combatRemotes = child(remotes, "Combat", "Folder")
local roundRemotes = child(remotes, "Round", "Folder")
local parryRequest = child(combatRemotes, "ParryRequest", "RemoteEvent")
local ballSnapshot = child(combatRemotes, "BallSnapshot", "RemoteEvent")
local combatEffect = child(combatRemotes, "CombatEffect", "RemoteEvent")
local roundState = child(roundRemotes, "RoundState", "RemoteEvent")

local combatFolder = child(serverRoot, "Combat", "Folder")
local npcFolder = child(serverRoot, "NPC", "Folder")
local roundsFolder = child(serverRoot, "Rounds", "Folder")
local CombatantService = require(child(combatFolder, "CombatantService", "ModuleScript"))
local CombatService = require(child(combatFolder, "CombatService", "ModuleScript"))
local BallService = require(child(combatFolder, "BallService", "ModuleScript"))
local WeaponService = require(child(combatFolder, "WeaponService", "ModuleScript"))
local NPCService = require(child(npcFolder, "NPCService", "ModuleScript"))
local RoundService = require(child(roundsFolder, "RoundService", "ModuleScript"))

local arena = child(child(workspace, "Game", "Folder"), "Arena", "Model")
local gameplay = child(arena, "Gameplay", "Folder")
local walls = child(gameplay, "Walls", "Folder")
for _, groupName in { "Players", "NPCs", "Weapons" } do pcall(function() PhysicsService:RegisterCollisionGroup(groupName) end) end
PhysicsService:CollisionGroupSetCollidable("Weapons", "Players", false)
PhysicsService:CollisionGroupSetCollidable("Weapons", "NPCs", false)
for _, wall in walls:GetChildren() do if wall:IsA("BasePart") then CollectionService:AddTag(wall, "BallCollision") end end
for _, visual in child(arena, "Visual", "Folder"):GetDescendants() do CollectionService:AddTag(visual, "IgnoreBall") end

local combatants = CombatantService.new()
local weapons = WeaponService.new()
local combat = CombatService.new(combatants, combatEffect)
local ball = BallService.new(combatants, combat, ballSnapshot, combatEffect, arena)
combat:SetBall(ball)
local npcs = NPCService.new(combatants, combat, ball, weapons, arena)
local rounds = RoundService.new({
	Combatants = combatants,
	Combat = combat,
	Ball = ball,
	NPCs = npcs,
	Weapons = weapons,
	Remote = roundState,
	Arena = arena,
})

Players.CharacterAutoLoads = false
local playerConnections = {}
local function onCharacter(player, character)
	task.spawn(function()
		local body = characterUtil.WaitForR15(character, roundConfig.StartupTimeout)
		if not body then warn("[Fatal/Player] incomplete R15 character: " .. player.Name); return end
		local combatant = combatants:GetByPlayer(player)
		if combatant then combatants:BindCharacter(combatant, character) end
		for _, descendant in character:GetDescendants() do if descendant:IsA("BasePart") then descendant.CollisionGroup = "Players" end end
		if rounds.State ~= "Playing" and rounds.State ~= "Starting" then character:PivotTo(roundConfig.LobbyCFrame) end
		weapons:Equip(character)
	end)
end
local function addPlayer(player)
	-- PlayerAdded and the startup GetPlayers snapshot can overlap; this table is the
	-- single lifecycle ownership gate. RoundService never registers Players.
	if playerConnections[player] then return end
	combatants:RegisterPlayer(player)
	playerConnections[player] = player.CharacterAdded:Connect(function(character) onCharacter(player, character) end)
	if player.Character then onCharacter(player, player.Character) else task.spawn(function() pcall(function() player:LoadCharacterAsync() end) end) end
end
local function removePlayer(player)
	rounds:RemovePlayer(player)
	local connection = playerConnections[player]
	if connection then connection:Disconnect() end
	playerConnections[player] = nil
end

local connections = {}
table.insert(connections, Players.PlayerAdded:Connect(addPlayer))
table.insert(connections, Players.PlayerRemoving:Connect(removePlayer))
table.insert(connections, parryRequest.OnServerEvent:Connect(function(player, timestamp, ballRevision)
	local combatant = combatants:GetByPlayer(player)
	combat:TryParry(combatant, { ClientTime = timestamp, BallRevision = ballRevision })
end))
for _, player in Players:GetPlayers() do addPlayer(player) end
table.insert(connections, RunService.Heartbeat:Connect(function(dt) rounds:Update(dt) end))

game:BindToClose(function()
	for _, connection in connections do connection:Disconnect() end
	rounds:Destroy()
	for player, connection in playerConnections do connection:Disconnect(); playerConnections[player] = nil end
	combatants:Destroy()
end)
