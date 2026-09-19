--!strict

local ContextActionService = game:GetService("ContextActionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local parryRequest = ReplicatedStorage.Game:WaitForChild("Remotes"):WaitForChild("ParryRequest") :: RemoteEvent

local ACTION = "FatalParry"
local localCooldown = false

local function requestParry(_: string, inputState: Enum.UserInputState): Enum.ContextActionResult
	if inputState ~= Enum.UserInputState.Begin or localCooldown then
		return Enum.ContextActionResult.Pass
	end

	localCooldown = true
	parryRequest:FireServer()
	task.delay(0.2, function()
		localCooldown = false
	end)
	return Enum.ContextActionResult.Sink
end

ContextActionService:BindAction(ACTION, requestParry, true, Enum.KeyCode.F, Enum.KeyCode.ButtonR2)
ContextActionService:SetTitle(ACTION, "PARRY")
ContextActionService:SetPosition(ACTION, UDim2.fromScale(0.82, 0.72))
