--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatantService = require(script.Parent.CombatantService)
local BallService = require(script.Parent.BallService)
local RoundService = require(script.Parent.RoundService)

local remotes = ReplicatedStorage.Game:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage.Game
end

local parryRequest = remotes:FindFirstChild("ParryRequest")
if not parryRequest then
	parryRequest = Instance.new("RemoteEvent")
	parryRequest.Name = "ParryRequest"
	parryRequest.Parent = remotes
end

local lastParryAt: {[Player]: number} = {}

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		task.defer(function()
			CombatantService.RegisterPlayer(player)
		end)
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	lastParryAt[player] = nil
	CombatantService.RemovePlayer(player)
end)

parryRequest.OnServerEvent:Connect(function(player)
	local now = os.clock()
	local previous = lastParryAt[player] or 0
	if now - previous < 0.2 then
		return
	end
	lastParryAt[player] = now

	local combatant = CombatantService.RegisterPlayer(player)
	if not combatant then
		return
	end

	BallService.TryParry(combatant.Id)
end)

for _, player in Players:GetPlayers() do
	if player.Character then
		CombatantService.RegisterPlayer(player)
	end
end

task.spawn(RoundService.RunForever)
