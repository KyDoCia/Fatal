local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local replicatedGame = ReplicatedStorage:WaitForChild("Game")
local Config = require(replicatedGame:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CombatConfig"))
local remotes = replicatedGame:WaitForChild("Remotes")
local parryIntent = remotes:WaitForChild("ParryIntent")
local snapshot = remotes:WaitForChild("BallSnapshot")
local combatEvent = remotes:WaitForChild("CombatEvent")
local rallyLabel = player:WaitForChild("PlayerGui"):WaitForChild("RallyGui"):WaitForChild("Rally")
local baseColor = Color3.fromRGB(255, 76, 58)
local currentBall = nil
local orientedRevision = -1
local pulseRevision = 0

local function parry()
	parryIntent:FireServer()
end

local function setBallReadability(ball, intensity)
	if not ball or not ball.Parent then return end
	ball.Color = baseColor:Lerp(Color3.fromRGB(255, 220, 175), intensity * 0.35)
	local light = ball:FindFirstChild("CoreLight")
	if light and light:IsA("PointLight") then light.Brightness = 0.8 + intensity * 1.4 end
	local trail = ball:FindFirstChildOfClass("Trail")
	if trail then trail.LightEmission = 0.8 + intensity * 0.2 end
end

local function playSoundHook(ball, name)
	local sound = ball and ball:FindFirstChild(name)
	if sound and sound:IsA("Sound") and sound.SoundId ~= "" then sound:Play() end
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F then parry() end
end)

snapshot.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" or type(state.Rally) ~= "number" then return end
	currentBall = if typeof(state.Ball) == "Instance" and state.Ball:IsA("BasePart") then state.Ball else nil
	rallyLabel.Text = if state.Rally > 0 then string.format("RALLY  %d", state.Rally) else ""
	if currentBall and pulseRevision == 0 then
		local character = player.Character
		local center = character and character:FindFirstChild("UpperTorso")
		local localTarget = state.TargetId == "P:" .. player.UserId
		local intensity = 0
		if localTarget and center and center:IsA("BasePart") then
			local distance = (center.Position - state.Position).Magnitude
			local cueStart = Config.Parry.DefensiveRadius * 1.6
			intensity = math.clamp((cueStart - distance) / (cueStart - Config.Parry.DefensiveRadius), 0, 1)
		end
		setBallReadability(currentBall, intensity)
	end
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
	if type(event) ~= "table" or type(event.Kind) ~= "string" or typeof(event.Position) ~= "Vector3" then return end
	if event.Kind == "ParryConfirmed" then
		local ball = currentBall
		if not ball or not ball.Parent then return end
		pulseRevision += 1
		local pulse = pulseRevision
		ball.Color = Color3.fromRGB(255, 245, 215)
		local light = ball:FindFirstChild("CoreLight")
		if light and light:IsA("PointLight") then light.Brightness = 4 end
		local trail = ball:FindFirstChildOfClass("Trail")
		if trail then trail.Lifetime = 0.22; trail.LightEmission = 1 end
		playSoundHook(ball, "ParrySound")
		task.delay(0.11, function()
			if pulse ~= pulseRevision or not ball.Parent then return end
			pulseRevision = 0
			ball.Color = baseColor
			if light and light.Parent then light.Brightness = 0.8 end
			if trail and trail.Parent then trail.Lifetime = 0.1; trail.LightEmission = 0.8 end
		end)
	elseif event.Kind == "BodyHit" then
		playSoundHook(currentBall, "HitSound")
		local flash = Instance.new("Part")
		flash.Name = "V3BodyHitFlash"
		flash.Shape = Enum.PartType.Ball
		flash.Size = Vector3.one * 1.4
		flash.Position = event.Position
		flash.Color = Color3.fromRGB(255, 236, 210)
		flash.Material = Enum.Material.Neon
		flash.Anchored = true
		flash.CanCollide = false
		flash.CanTouch = false
		flash.CanQuery = false
		flash.Parent = workspace
		TweenService:Create(flash, TweenInfo.new(0.12), { Size = Vector3.one * 2.4, Transparency = 1 }):Play()
		Debris:AddItem(flash, 0.15)
	end
end)
