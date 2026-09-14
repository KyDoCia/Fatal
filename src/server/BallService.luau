--!strict

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Game.Config)
local CombatantService = require(script.Parent.CombatantService)

local BallService = {}

local ball: Part? = nil
local targetId: string? = nil
local speed = Config.Ball.BaseSpeed
local rally = 0
local heartbeatConnection: RBXScriptConnection? = nil

local function chooseTarget(excludeId: string?): any?
	local alive = CombatantService.GetAlive()
	local candidates = {}
	for _, combatant in alive do
		if combatant.Id ~= excludeId then
			table.insert(candidates, combatant)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

local function destroyBall()
	if heartbeatConnection then
		heartbeatConnection:Disconnect()
		heartbeatConnection = nil
	end
	if ball then
		ball:Destroy()
		ball = nil
	end
	targetId = nil
end

function BallService.Stop()
	destroyBall()
end

function BallService.Start(origin: Vector3): boolean
	destroyBall()

	local target = chooseTarget(nil)
	if not target then
		return false
	end

	local part = Instance.new("Part")
	part.Name = "GameplayBall"
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(3, 3, 3)
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Material = Enum.Material.Neon
	part.Position = origin + Vector3.new(0, Config.Ball.SpawnHeight, 0)
	part.Parent = workspace

	ball = part
	targetId = target.Id
	speed = Config.Ball.BaseSpeed
	rally = 0

	heartbeatConnection = RunService.Heartbeat:Connect(function(dt)
		if not ball or not targetId then
			return
		end

		local currentTarget = CombatantService.GetById(targetId)
		if not currentTarget or not currentTarget.Alive or currentTarget.Root.Parent == nil then
			local replacement = chooseTarget(nil)
			if not replacement then
				return
			end
			targetId = replacement.Id
			currentTarget = replacement
		end

		local delta = currentTarget.Root.Position - ball.Position
		local distance = delta.Magnitude
		if distance <= 2.6 then
			CombatantService.Eliminate(currentTarget.Id)
			local replacement = chooseTarget(currentTarget.Id)
			if replacement then
				targetId = replacement.Id
			else
				targetId = nil
			end
			return
		end

		if distance > 0 then
			ball.Position += delta.Unit * math.min(distance, speed * dt)
		end
	end)

	return true
end

function BallService.TryParry(combatantId: string): boolean
	if not ball or not targetId or combatantId ~= targetId then
		return false
	end

	local combatant = CombatantService.GetById(combatantId)
	if not combatant or not combatant.Alive then
		return false
	end

	local distance = (combatant.Root.Position - ball.Position).Magnitude
	if distance > Config.Parry.MaxDistance then
		return false
	end

	local nextTarget = chooseTarget(combatantId)
	if not nextTarget then
		return false
	end

	rally += 1
	speed = math.min(Config.Ball.MaxSpeed, Config.Ball.BaseSpeed + Config.Ball.SpeedPerParry * rally)
	targetId = nextTarget.Id
	return true
end

function BallService.GetTargetId(): string?
	return targetId
end

return BallService
