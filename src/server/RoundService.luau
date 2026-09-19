--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Game.Config)
local CombatantService = require(script.Parent.CombatantService)
local BallService = require(script.Parent.BallService)

local RoundService = {}

local state = "Lobby"

local function setState(newState: string)
	state = newState
	workspace:SetAttribute("FatalRoundState", newState)
end

local function waitForEnoughPlayers()
	setState("Lobby")
	while #Players:GetPlayers() < Config.MinimumPlayers do
		task.wait(1)
	end
end

local function countdown()
	setState("Countdown")
	for remaining = Config.CountdownDuration, 1, -1 do
		workspace:SetAttribute("FatalCountdown", remaining)
		task.wait(1)
	end
	workspace:SetAttribute("FatalCountdown", 0)
end

local function waitForWinner(): any?
	while state == "Active" do
		local alive = CombatantService.GetAlive()
		if #alive <= 1 then
			return alive[1]
		end
		task.wait(0.1)
	end
	return nil
end

function RoundService.RunForever()
	while true do
		waitForEnoughPlayers()
		CombatantService.RefreshPlayers()
		countdown()

		local alive = CombatantService.GetAlive()
		if #alive < Config.MinimumPlayers then
			continue
		end

		setState("Active")
		local center = Vector3.zero
		for _, combatant in alive do
			center += combatant.Root.Position
		end
		center /= #alive

		if not BallService.Start(center) then
			setState("Cleanup")
			task.wait(1)
			continue
		end

		local winner = waitForWinner()
		BallService.Stop()

		setState("Winner")
		workspace:SetAttribute("FatalWinner", winner and winner.Id or "")
		task.wait(Config.IntermissionDuration)

		setState("Cleanup")
		workspace:SetAttribute("FatalWinner", "")
		task.wait(1)
	end
end

function RoundService.GetState(): string
	return state
end

return RoundService
