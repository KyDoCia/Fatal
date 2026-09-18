local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.UIConfig)
local Theme = require(ReplicatedStorage.Game.Shared.Config.UITheme)

local Effects = {}
local boundUI = nil

function Effects.Bind(ui)
	boundUI = ui
end

local function sound(name)
	local soundId = Config.Audio[name]
	if soundId == "" then return end
	local object = Instance.new("Sound")
	object.Name = "Fatal" .. name
	object.SoundId = soundId
	object.Volume = 0.5
	object.Parent = SoundService
	object:Play()
	Debris:AddItem(object, 3)
end

local function flash(position, color, scale)
	local orb = Instance.new("Part")
	orb.Name = "FatalImpact"
	orb.Shape = Enum.PartType.Ball
	orb.Size = Vector3.one * (Config.VFX.StartSize * scale * Config.VFXIntensity)
	orb.Position = position
	orb.Color = color
	orb.Material = Enum.Material.Neon
	orb.Anchored = true
	orb.CanCollide = false
	orb.CanTouch = false
	orb.CanQuery = false
	orb.Parent = workspace
	TweenService:Create(orb, TweenInfo.new(Config.VFX.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.one * (Config.VFX.EndSize * scale * Config.VFXIntensity),
		Transparency = 1,
	}):Play()
	Debris:AddItem(orb, Config.VFX.Duration + 0.04)
end

local function ring(position, color)
	local value = Instance.new("Part")
	value.Name = "FatalParryRing"
	value.Shape = Enum.PartType.Cylinder
	value.Size = Vector3.new(0.08, 2.5, 2.5)
	value.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.pi / 2)
	value.Color = color
	value.Material = Enum.Material.Neon
	value.Anchored = true
	value.CanCollide = false
	value.CanTouch = false
	value.CanQuery = false
	value.Transparency = 0.2
	value.Parent = workspace
	TweenService:Create(value, TweenInfo.new(Config.VFX.Duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.08, 8, 8),
		Transparency = 1,
	}):Play()
	Debris:AddItem(value, Config.VFX.Duration + 0.04)
end

function Effects.LocalAttempt(character, position)
	local hand = character and character:FindFirstChild("RightHand")
	local joint = hand and hand:FindFirstChild("FatalWeaponJoint")
	if joint and joint:IsA("Motor6D") then
		joint.Transform = CFrame.Angles(math.rad(-22), 0, math.rad(-38))
		TweenService:Create(joint, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transform = CFrame.new() }):Play()
	end
	flash(position, Config.Colors.Threat, 0.55)
	if boundUI then
		boundUI.ParryScale.Scale = 0.94
		TweenService:Create(boundUI.ParryScale, TweenInfo.new(Theme.Motion.Fast, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	sound("Attempt")
end

function Effects.ServerEvent(kind, position, rallyCount)
	if typeof(position) ~= "Vector3" then return end
	if kind == "ParrySuccess" then
		flash(position, Config.Colors.Safe, 1 + math.min(rallyCount or 0, 12) * 0.025)
		ring(position, Config.Colors.Safe)
		if boundUI then
			boundUI.TargetScale.Scale = Theme.Motion.ParryPulseScale
			TweenService:Create(boundUI.TargetScale, TweenInfo.new(Theme.Motion.Standard, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end
		sound("ParrySuccess")
	elseif kind == "WallBounce" then flash(position, Config.Colors.Threat, 0.45); sound("WallBounce")
	elseif kind == "Elimination" then flash(position, Config.Colors.Critical, 1.25); sound("Elimination") end
end

return Effects
