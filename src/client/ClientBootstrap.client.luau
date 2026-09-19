local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local replicatedGame = ReplicatedStorage:WaitForChild("Game")
local Config = require(replicatedGame:WaitForChild("Shared"):WaitForChild("Config"):WaitForChild("CombatConfig"))
local CombatTypes = require(replicatedGame.Shared.Combat.CombatTypes)
local WeaponDefinitions = require(replicatedGame.Shared.Weapons.WeaponDefinitions)
local BallDefinition = require(replicatedGame.Shared.Balls.BallDefinitions).StandardBall
local Effects = require(replicatedGame.Shared.Effects.ParryEffectDefinitions)
local CombatInputController = require(script.Parent.Input.CombatInputController)
local WeaponPresentationController = require(script.Parent.Weapons.WeaponPresentationController)
local InventoryController = require(script.Parent.InventoryController)
local ParryEffectController = require(script.Parent.ParryEffectController)
local remotes = replicatedGame:WaitForChild("Remotes")
local parryIntent = remotes:WaitForChild("ParryIntent")
local snapshot = remotes:WaitForChild("BallSnapshot")
local combatEvent = remotes:WaitForChild("CombatEvent")
local inventoryRequest = remotes:WaitForChild("InventoryRequest")
local inventoryState = remotes:WaitForChild("InventoryState")

local function awaitChild(parent, name)
	local found = parent:FindFirstChild(name)
	while not found do
		local child = parent.ChildAdded:Wait()
		if child.Name == name then found = child else found = parent:FindFirstChild(name) end
	end
	return found
end

assert(StarterGui:FindFirstChild("RallyGui"), "canonical StarterGui.RallyGui is missing")
local playerGui = awaitChild(player, "PlayerGui")
local rallyGui = awaitChild(playerGui, "RallyGui")
local rallyLabel = awaitChild(rallyGui, "Rally")
local baseColor = Color3.fromRGB(255, 76, 58)
local currentBall = nil
local authoritativeBall = nil
local snapshotPosition = Vector3.zero
local snapshotVelocity = Vector3.zero
local snapshotAt = 0
local orientedRevision = -1
local pulseRevision = 0

local weapon = WeaponPresentationController.new(player, WeaponDefinitions.TrainingBlade)
local input = CombatInputController.new(parryIntent, function(direction) weapon:PresentIntent(direction) end)
input:Bind()
InventoryController.Start(player, inventoryRequest, inventoryState)

local function setBallReadability(ball, intensity)
	if not ball or not ball.Parent then return end
	ball.Color = baseColor:Lerp(Color3.fromRGB(255, 220, 175), intensity * 0.35)
	local light = ball:FindFirstChild("CoreLight")
	if light and light:IsA("PointLight") then light.Brightness = 0.8 + intensity * 1.4 end
	local trail = ball:FindFirstChildOfClass("Trail")
	if trail then trail.LightEmission = 0.8 + intensity * 0.2 end
end

local function playSoundHook(ball, name, intensity)
	local sound = ball and ball:FindFirstChild(name)
	if sound and sound:IsA("Sound") and sound.SoundId ~= "" then sound.PlaybackSpeed = 0.95 + (intensity or 0) * 0.2; sound:Play() end
end

snapshot.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" or type(state.Rally) ~= "number" then return end
	local incoming = if typeof(state.Ball) == "Instance" and state.Ball:IsA("BasePart") then state.Ball else nil
	if incoming ~= authoritativeBall then
		if currentBall then currentBall:Destroy() end
		authoritativeBall = incoming
		currentBall = nil
		if incoming then
			incoming.LocalTransparencyModifier = 1
			currentBall = incoming:Clone()
			currentBall.Name = "BallPresentation"
			currentBall:SetAttribute("FatalV2Ball", nil)
			currentBall.Parent = workspace
		end
	end
	if typeof(state.Position) == "Vector3" then snapshotPosition = state.Position end
	if typeof(state.Velocity) == "Vector3" then snapshotVelocity = state.Velocity end
	snapshotAt = os.clock()
	if currentBall and pulseRevision == 0 then
		local character = player.Character
		local center = character and character:FindFirstChild("UpperTorso")
		local localTarget = state.TargetId == "P:" .. player.UserId
		local intensity = 0
		if localTarget and center and center:IsA("BasePart") then
			local distance = (center.Position - state.Position).Magnitude
			local cueStart = Config.Parry.DefensiveRadius * Config.Feedback.CueStartMultiplier
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

RunService.RenderStepped:Connect(function(dt)
	if not currentBall or not currentBall.Parent then return end
	local predicted = snapshotPosition + snapshotVelocity * math.min(os.clock() - snapshotAt, 0.1)
	local alpha = 1 - math.exp(-24 * dt)
	currentBall.Position = currentBall.Position:Lerp(predicted, alpha)
	local trail = currentBall:FindFirstChildOfClass("Trail")
	if trail then trail.Lifetime = BallDefinition.Trail.BaseLifetime + math.clamp(snapshotVelocity.Magnitude / Config.Ball.MaxSpeed, 0, 1) * BallDefinition.Trail.SpeedLifetime end
end)

combatEvent.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" or type(event.Kind) ~= "string" or event.Version ~= CombatTypes.ProtocolVersion then return end
	if event.Kind == CombatTypes.EventKind.RallyChanged then
		if type(event.Rally) ~= "number" then return end
		rallyLabel.Text = if event.Rally > 0 then string.format("RALLY  %d", event.Rally) else ""
	elseif event.Kind == CombatTypes.EventKind.ParryConfirmed then
		if typeof(event.Position) ~= "Vector3" then return end
		local ball = currentBall
		if not ball or not ball.Parent then return end
		pulseRevision += 1
		local pulse = pulseRevision
		local intensity = Effects.ImpactIntensity(event.Speed or snapshotVelocity.Magnitude, event.Rally, Config.Ball.MaxSpeed)
		local baseSize = currentBall.Size
		ball.Color = Color3.fromRGB(255, 245, 215)
		ball.Size = Vector3.new(baseSize.X * 0.82, baseSize.Y * 0.82, baseSize.Z * (1.25 + intensity * 0.2))
		local direction = typeof(event.Direction) == "Vector3" and event.Direction or snapshotVelocity.Unit
		ball.CFrame = CFrame.lookAt(ball.Position, ball.Position + direction)
		local light = ball:FindFirstChild("CoreLight")
		if light and light:IsA("PointLight") then light.Brightness = 4 end
		local trail = ball:FindFirstChildOfClass("Trail")
		if trail then trail.Lifetime = Config.Feedback.ParryTrailLifetime; trail.LightEmission = 1 end
		playSoundHook(ball, "ParrySound", intensity)
		ParryEffectController.Present(event.Position, direction, intensity)
		weapon:PresentParry()
		local camera = workspace.CurrentCamera
		if camera then camera.CFrame *= CFrame.new(0, 0, Config.Feedback.CameraImpulse * (0.65 + intensity * 0.35)) end
		task.delay(Config.Feedback.ParryFlashDuration, function()
			if pulse ~= pulseRevision or not ball.Parent then return end
			pulseRevision = 0
			ball.Color = baseColor
			ball.Size = baseSize
			if light and light.Parent then light.Brightness = 0.8 end
			if trail and trail.Parent then trail.Lifetime = 0.1; trail.LightEmission = 0.8 end
		end)
	elseif event.Kind == CombatTypes.EventKind.CombatantHit then
		if typeof(event.Position) ~= "Vector3" then return end
		local intensity = Effects.ImpactIntensity(snapshotVelocity.Magnitude, event.Rally or 0, Config.Ball.MaxSpeed)
		playSoundHook(currentBall, "HitSound", intensity)
		ParryEffectController.PresentHit(event.Position, intensity)
	end
end)
