local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Theme = require(ReplicatedStorage.Game.Shared.Config.UITheme)
local RoundConfig = require(ReplicatedStorage.Game.Shared.Config.RoundConfig)

local RootUI = {}

local function child(parent, name, className)
	local value = parent:FindFirstChild(name)
	assert(value and value:IsA(className), string.format("FATAL declarative UI contract missing %s.%s (%s)", parent:GetFullName(), name, className))
	return value
end

local function themeText(label, secondary)
	label.TextColor3 = if secondary then Theme.TextSecondary else Theme.TextPrimary
end

function RootUI.Create(playerGui)
	local hud = child(playerGui, "HUD", "ScreenGui")
	local roundGui = child(playerGui, "RoundGui", "ScreenGui")
	local combatGui = child(playerGui, "CombatGui", "ScreenGui")
	local topStatus = child(hud, "TopStatus", "Frame")
	local telemetry = child(hud, "Telemetry", "Frame")
	local target = child(hud, "TargetIndicator", "Frame")
	local countdown = child(roundGui, "Countdown", "Frame")
	local button = child(combatGui, "ParryButton", "TextButton")
	local ui = {
		HUD = hud,
		RoundGui = roundGui,
		CombatGui = combatGui,
		TopStatus = topStatus,
		RoundState = child(topStatus, "Round", "TextLabel"),
		AliveCount = child(topStatus, "Alive", "TextLabel"),
		Telemetry = telemetry,
		BallSpeed = child(telemetry, "Speed", "TextLabel"),
		RallyCount = child(telemetry, "Rally", "TextLabel"),
		TargetIndicator = target,
		TargetState = child(target, "State", "TextLabel"),
		TargetTime = child(target, "Time", "TextLabel"),
		TargetScale = child(target, "PulseScale", "UIScale"),
		TargetStroke = child(target, "ReticleStroke", "UIStroke"),
		Countdown = countdown,
		CountdownLabel = child(countdown, "Label", "TextLabel"),
		CountdownScale = child(countdown, "MotionScale", "UIScale"),
		ParryButton = button,
		ParryScale = child(button, "MotionScale", "UIScale"),
	}

	themeText(ui.RoundState, false)
	themeText(ui.AliveCount, true)
	themeText(ui.BallSpeed, true)
	themeText(ui.RallyCount, false)
	themeText(ui.CountdownLabel, false)
	ui.TopStatus.BackgroundColor3 = Theme.Panel
	ui.TopStatus.BackgroundTransparency = Theme.Transparency
	ui.Telemetry.BackgroundColor3 = Theme.Panel
	ui.Telemetry.BackgroundTransparency = Theme.Transparency
	ui.TargetStroke.Color = Theme.Stroke
	ui.ParryButton.BackgroundColor3 = Theme.Threat
	ui.ParryButton.TextColor3 = Theme.TextPrimary
	ui.TargetIndicator.Visible = false
	if RoundConfig.CombatLab then
		ui.TopStatus.Visible = false
		ui.Telemetry.Position = UDim2.fromScale(0.5, 0.045)
		ui.Telemetry.Size = UDim2.fromOffset(180, 38)
		ui.BallSpeed.Visible = false
		ui.RallyCount.Position = UDim2.fromScale(0.5, 0.5)
		ui.RallyCount.Size = UDim2.fromScale(1, 1)
		ui.RallyCount.TextXAlignment = Enum.TextXAlignment.Center
	end
	return ui
end

return RootUI
