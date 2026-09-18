local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.UIConfig)
local Theme = require(ReplicatedStorage.Game.Shared.Config.UITheme)

local HUDController = {}

function HUDController.Start(state, ui, roundRemote)
	local previousState = state.Round.State
	local goUntil = 0
	local displayedSecond = -1
	local function animateCountdown(text)
		ui.Countdown.Visible = true
		ui.CountdownLabel.Text = text
		ui.CountdownLabel.TextTransparency = 0
		ui.CountdownScale.Scale = Theme.Motion.CountdownScale
		TweenService:Create(ui.CountdownScale, TweenInfo.new(Theme.Motion.Standard, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		TweenService:Create(ui.CountdownLabel, TweenInfo.new(Theme.Motion.Slow, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 0.18 }):Play()
	end
	local connection = roundRemote.OnClientEvent:Connect(function(snapshot)
		if type(snapshot) ~= "table"
			or type(snapshot.State) ~= "string"
			or type(snapshot.Deadline) ~= "number"
			or type(snapshot.Round) ~= "number"
			or type(snapshot.AliveCount) ~= "number"
			or type(snapshot.WinnerId) ~= "string"
			or type(snapshot.WinnerName) ~= "string"
			or type(snapshot.Participants) ~= "table"
			or type(snapshot.ServerTime) ~= "number"
		then
			warn("[Fatal/UI] rejected invalid RoundState snapshot")
			return
		end
		state.Round = snapshot
		state.RoundChanged:Fire(snapshot)
		if snapshot.State == "Playing" and previousState == "Starting" then
			goUntil = workspace:GetServerTimeNow() + Config.GoDuration
			animateCountdown("FIGHT")
		end
		if snapshot.State ~= previousState then displayedSecond = -1 end
		previousState = snapshot.State
		ui.AliveCount.Text = string.format("%02d  ALIVE", snapshot.AliveCount)
	end)
	local render = RunService.RenderStepped:Connect(function()
		local snapshot = state.Round
		local now = workspace:GetServerTimeNow()
		if snapshot.State == "Starting" then
			local second = math.max(1, math.ceil(snapshot.Deadline - now))
			if second ~= displayedSecond then displayedSecond = second; animateCountdown(tostring(second)) end
		elseif now >= goUntil then ui.Countdown.Visible = false end

		if snapshot.State == "Playing" then ui.RoundState.Text = string.format("ROUND  %02d", snapshot.Round)
		elseif snapshot.State == "Ending" and snapshot.WinnerName ~= "" then ui.RoundState.Text = "VICTOR  /  " .. string.upper(snapshot.WinnerName)
		elseif snapshot.State == "Intermission" then
			ui.RoundState.Text = string.format("NEXT ROUND  /  %02d", math.max(0, math.ceil(snapshot.Deadline - now)))
		else ui.RoundState.Text = string.upper(snapshot.State) end
	end)
	return function() connection:Disconnect(); render:Disconnect() end
end

return HUDController
