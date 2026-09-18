local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatConfig = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local UIConfig = require(ReplicatedStorage.Game.Shared.Config.UIConfig)
local Theme = require(ReplicatedStorage.Game.Shared.Config.UITheme)
local TrajectoryMath = require(ReplicatedStorage.Game.Shared.Util.TrajectoryMath)

local CombatController = {}

local function validSnapshot(snapshot)
	return type(snapshot) == "table"
		and type(snapshot.State) == "string"
		and typeof(snapshot.Position) == "Vector3"
		and typeof(snapshot.CurrentDirection) == "Vector3"
		and type(snapshot.Speed) == "number"
		and type(snapshot.TargetId) == "string"
		and type(snapshot.RallyCount) == "number"
		and type(snapshot.Revision) == "number"
end

function CombatController.Start(state, ui, remotes, effects)
	local player = Players.LocalPlayer
	local warnedInvalid = false
	local visualPosition = Vector3.zero
	local lastRevision = -1
	local previousTarget = false
	local previousThreat = "SAFE"
	local connections = {}
	local function pulseTarget(scale)
		ui.TargetScale.Scale = scale
		TweenService:Create(ui.TargetScale, TweenInfo.new(Theme.Motion.Standard, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	local function attempt()
		if state.Round.State ~= "Playing" or not state.Combat.IsTarget then return end
		local now = workspace:GetServerTimeNow()
		if now < state.Combat.ReadyAt then return end
		local character = player.Character
		local hand = character and character:FindFirstChild("RightHand")
		if hand and hand:IsA("BasePart") then effects.LocalAttempt(character, hand.Position) end
		remotes.ParryRequest:FireServer(now, state.Ball.Revision)
	end

	table.insert(connections, remotes.BallSnapshot.OnClientEvent:Connect(function(snapshot)
		if not validSnapshot(snapshot) then
			if not warnedInvalid then warnedInvalid = true; warn("[Fatal/Combat] rejected invalid BallSnapshot") end
			return
		end
		state.Ball = snapshot
		if snapshot.Revision ~= lastRevision then visualPosition = snapshot.Position; lastRevision = snapshot.Revision end
		state.BallChanged:Fire(snapshot)
	end))
	table.insert(connections, remotes.CombatEffect.OnClientEvent:Connect(function(payload)
		if type(payload) ~= "table" or type(payload.Kind) ~= "string" then return end
		if payload.Kind == "ParryWindow" then
			if type(payload.ActiveUntil) ~= "number" or type(payload.ReadyAt) ~= "number" then return end
			state.Combat.ActiveUntil = payload.ActiveUntil
			state.Combat.ReadyAt = payload.ReadyAt
			state.Combat.Phase = "Active"
		else
			effects.ServerEvent(payload.Kind, payload.Position, payload.RallyCount)
			state.CombatChanged:Fire(payload.Kind)
		end
	end))
	table.insert(connections, RunService.RenderStepped:Connect(function(dt)
		local now = workspace:GetServerTimeNow()
		local ball = state.Ball
		local localId = "P:" .. player.UserId
		local isTarget = ball.State == "Tracking" and ball.TargetId == localId
		local tti = math.huge
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if isTarget and root and root:IsA("BasePart") then
			tti = TrajectoryMath.TimeToImpact(ball.Position, ball.CurrentDirection, ball.Speed, root.Position, root.AssemblyLinearVelocity, CombatConfig.Ball.Radius + CombatConfig.HurtVolume.PlayerHitRadius)
		end
		local threat = "SAFE"
		if tti <= CombatConfig.Feedback.CriticalTime then threat = "CRITICAL"
		elseif tti <= CombatConfig.Feedback.DangerTime then threat = "DANGER"
		elseif tti <= CombatConfig.Feedback.TargetLeadTime then threat = "THREAT" end
		state.Combat.IsTarget = isTarget
		state.Combat.Threat = threat
		state.Combat.TimeToImpact = tti
		if state.Combat.Phase == "Active" and now > state.Combat.ActiveUntil then state.Combat.Phase = "Cooldown" end
		if state.Combat.Phase == "Cooldown" and now >= state.Combat.ReadyAt then state.Combat.Phase = "Idle" end
		ui.TargetIndicator.Visible = isTarget
		ui.TargetState.Text = if threat == "SAFE" then "INCOMING" else threat
		ui.TargetTime.Text = tti == math.huge and "" or string.format("%.2f", tti)
		local threatColor = UIConfig.Colors[threat:sub(1, 1) .. threat:sub(2):lower()] or UIConfig.Colors.Safe
		ui.TargetState.TextColor3 = threatColor
		ui.TargetStroke.Color = threatColor
		if isTarget ~= previousTarget then
			if isTarget then pulseTarget(Theme.Motion.TargetPulseScale) end
			previousTarget = isTarget
		end
		if threat ~= previousThreat then
			if threat == "CRITICAL" then pulseTarget(Theme.Motion.CriticalPulseScale) end
			previousThreat = threat
		end
		if isTarget and threat == "CRITICAL" then
			ui.TargetIndicator.BackgroundTransparency = 0.94 + math.sin(now * 8) * 0.025
		else ui.TargetIndicator.BackgroundTransparency = 1 end
		ui.BallSpeed.Text = if ball.State == "Tracking" then string.format("%03d  VELOCITY", math.round(ball.Speed)) else "---  VELOCITY"
		ui.RallyCount.Text = string.format("%02d  RALLY", ball.RallyCount)
		local remaining = math.max(0, state.Combat.ReadyAt - now)
		ui.ParryButton.Text = if remaining > 0 then string.format("%.1f", remaining) else "PARRY"
		local visual = ball.Ball
		if ball.State == "Tracking" and typeof(visual) == "Instance" and visual:IsA("BasePart") then
			local age = math.clamp(now - ball.ServerTime, 0, UIConfig.BallPredictionLimit)
			local predicted = ball.Position + ball.CurrentDirection * ball.Speed * age
			visualPosition = visualPosition:Lerp(predicted, 1 - math.exp(-UIConfig.BallLerpResponse * dt))
			visual.CFrame = CFrame.new(visualPosition)
		end
	end))

	return attempt, function() for _, connection in connections do connection:Disconnect() end end
end

return CombatController
