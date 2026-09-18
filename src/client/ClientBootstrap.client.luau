local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Game"):WaitForChild("Remotes")
local parryIntent = remotes:WaitForChild("ParryIntent")
local snapshot = remotes:WaitForChild("BallSnapshot")
local combatEvent = remotes:WaitForChild("CombatEvent")
local rallyLabel = player:WaitForChild("PlayerGui"):WaitForChild("RallyGui"):WaitForChild("Rally")

local function parry()
	parryIntent:FireServer()
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.KeyCode == Enum.KeyCode.F then parry() end
end)

snapshot.OnClientEvent:Connect(function(state)
	if type(state) ~= "table" or type(state.Rally) ~= "number" then return end
	rallyLabel.Text = if state.Rally > 0 then string.format("RALLY  %d", state.Rally) else ""
end)

combatEvent.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" or event.Kind ~= "Parry" or typeof(event.Position) ~= "Vector3" then return end
	local flash = Instance.new("Part")
	flash.Name = "V2ParryFeedback"
	flash.Shape = Enum.PartType.Ball
	flash.Size = Vector3.one * 1.2
	flash.Position = event.Position
	flash.Color = Color3.fromRGB(235, 242, 255)
	flash.Material = Enum.Material.Neon
	flash.Anchored = true
	flash.CanCollide = false
	flash.CanQuery = false
	flash.CanTouch = false
	flash.Parent = workspace
	TweenService:Create(flash, TweenInfo.new(0.12), { Size = Vector3.one * 3.5, Transparency = 1 }):Play()
	Debris:AddItem(flash, 0.15)
end)
