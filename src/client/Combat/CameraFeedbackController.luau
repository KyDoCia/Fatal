local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.UIConfig)

local CameraFeedbackController = {}

function CameraFeedbackController.Start(state)
	local punch = 0
	local shakeUntil = 0
	local event = state.CombatChanged.Event:Connect(function(kind)
		if kind == "ParrySuccess" then punch = Config.Camera.ParryPunch; shakeUntil = os.clock() + Config.Camera.Recovery end
	end)
	local render = RunService.RenderStepped:Connect(function(dt)
		local camera = workspace.CurrentCamera
		if not camera then return end
		local targetFOV = if state.Combat.Threat == "CRITICAL" then Config.Camera.CriticalFOV else Config.Camera.TargetFOV
		local targetBonus = if state.Combat.IsTarget then targetFOV - Config.Camera.DefaultFOV else 0
		local desired = Config.Camera.DefaultFOV + targetBonus + punch
		camera.FieldOfView += (desired - camera.FieldOfView) * (1 - math.exp(-Config.Camera.Response * dt))
		punch *= math.exp(-Config.Camera.Response * dt)
		local character = Players.LocalPlayer.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			if os.clock() < shakeUntil then
				local amount = Config.ScreenShake
				humanoid.CameraOffset = Vector3.new((math.random() - 0.5) * amount, (math.random() - 0.5) * amount, 0)
			else humanoid.CameraOffset = humanoid.CameraOffset:Lerp(Vector3.zero, 1 - math.exp(-Config.Camera.OffsetRecovery * dt)) end
		end
	end)
	return function() event:Disconnect(); render:Disconnect() end
end

return CameraFeedbackController
