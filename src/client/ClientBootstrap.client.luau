local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Game"):WaitForChild("Remotes")
local parryIntent = remotes:WaitForChild("ParryIntent")
local snapshot = remotes:WaitForChild("BallSnapshot")
local combatEvent = remotes:WaitForChild("CombatEvent")
local rallyLabel = player:WaitForChild("PlayerGui"):WaitForChild("RallyGui"):WaitForChild("Rally")
local currentBall = nil
local orientedRevision = -1
local trailPulse = 0

local function parry()
	parryIntent:FireServer()
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F then parry() end
end)

snapshot.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" or type(state.Rally) ~= "number" then return end
	currentBall = if typeof(state.Ball) == "Instance" and state.Ball:IsA("BasePart") then state.Ball else nil
	rallyLabel.Text = if state.Rally > 0 then string.format("RALLY  %d", state.Rally) else ""
	if state.State == "Tracking" and state.Rally == 0 and state.Revision ~= orientedRevision then
		orientedRevision = state.Revision
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local camera = workspace.CurrentCamera
		if root and root:IsA("BasePart") and camera then
			local focus = root.Position + root.CFrame.LookVector * 18 + Vector3.new(0, 2, 0)
			camera.CFrame = CFrame.lookAt(root.Position - root.CFrame.LookVector * 10 + Vector3.new(0, 5, 0), focus)
		end
	end
end)

combatEvent.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" or event.Kind ~= "Parry" or typeof(event.Position) ~= "Vector3" then return end
	local trail = currentBall and currentBall:FindFirstChildOfClass("Trail")
	if trail then
		trailPulse += 1
		local pulse = trailPulse
		trail.Lifetime = 0.2
		task.delay(0.1, function() if pulse == trailPulse and trail.Parent then trail.Lifetime = 0.1 end end)
	end
end)
