local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)

local CombatDebugController = {}

local function debugPart(name, color, shape, folder)
	local value = Instance.new("Part")
	value.Name = name
	value.Shape = shape or Enum.PartType.Block
	value.Anchored = true
	value.CanCollide = false
	value.CanTouch = false
	value.CanQuery = false
	value.Material = Enum.Material.ForceField
	value.Color = color
	value.Transparency = 0.72
	value.Parent = folder
	return value
end

local function line(part, from, to, thickness)
	local delta = to - from
	part.Size = Vector3.new(thickness, thickness, math.max(delta.Magnitude, 0.01))
	part.CFrame = CFrame.lookAt((from + to) * 0.5, to)
end

function CombatDebugController.Start(state)
	if not Config.CombatDebug or not RunService:IsStudio() then return function() end end
	local folder = Instance.new("Folder")
	folder.Name = "FatalCombatDebug"
	folder.Parent = workspace
	local ballRadius = debugPart("BallRadius", Color3.fromRGB(255, 50, 60), Enum.PartType.Ball, folder)
	local hurt = debugPart("HurtVolume", Color3.fromRGB(60, 190, 255), Enum.PartType.Cylinder, folder)
	local velocity = debugPart("VelocityVector", Color3.fromRGB(255, 230, 80), nil, folder)
	local arcLines = {}
	for index = 1, 5 do arcLines[index] = debugPart("ParryArc" .. index, Color3.fromRGB(90, 255, 170), nil, folder) end
	local anchor = debugPart("Metrics", Color3.new(), nil, folder)
	anchor.Transparency = 1
	anchor.Size = Vector3.one
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.fromOffset(300, 96)
	billboard.StudsOffset = Vector3.new(0, 6, 0)
	billboard.AlwaysOnTop = true
	billboard.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 0.2
	label.BackgroundColor3 = Color3.fromRGB(8, 9, 12)
	label.TextColor3 = Color3.new(1, 1, 1)
	label.TextSize = 14
	label.Font = Enum.Font.Code
	label.Parent = billboard
	local render = RunService.RenderStepped:Connect(function()
		local ball = state.Ball.Ball
		local target = state.Ball.TargetCharacter
		local root = typeof(target) == "Instance" and target:FindFirstChild("HumanoidRootPart") or nil
		local visible = state.Ball.State == "Tracking" and typeof(ball) == "Instance" and ball:IsA("BasePart") and root and root:IsA("BasePart")
		for _, value in folder:GetChildren() do if value:IsA("BasePart") then value.Transparency = visible and (value == anchor and 1 or 0.72) or 1 end end
		billboard.Enabled = visible and true or false
		if not visible then return end
		ballRadius.Size = Vector3.one * Config.Ball.Radius * 2
		ballRadius.CFrame = CFrame.new(state.Ball.Position)
		hurt.Size = Vector3.new(Config.HurtVolume.PlayerHitHeight, Config.HurtVolume.PlayerHitRadius * 2, Config.HurtVolume.PlayerHitRadius * 2)
		hurt.CFrame = CFrame.new(root.Position) * CFrame.Angles(0, 0, math.pi / 2)
		line(velocity, state.Ball.Position, state.Ball.Position + state.Ball.CurrentDirection * math.min(state.Ball.Speed * 0.12, 30), 0.18)
		local halfArc = math.rad(Config.Parry.ArcDegrees * 0.5)
		for index, arcLine in arcLines do
			local alpha = (index - 1) / (#arcLines - 1)
			local direction = CFrame.fromAxisAngle(Vector3.yAxis, -halfArc + halfArc * 2 * alpha):VectorToWorldSpace(root.CFrame.LookVector)
			line(arcLine, root.Position, root.Position + direction * Config.Parry.Range, 0.12)
		end
		anchor.CFrame = CFrame.new(root.Position)
		label.Text = string.format("TARGET %s\nTTI %s  RALLY %d  REV %d\nPARRY %s  CLOSING %.1f",
			state.Ball.TargetId, state.Combat.TimeToImpact < math.huge and string.format("%.3f", state.Combat.TimeToImpact) or "INF",
			state.Ball.RallyCount, state.Ball.Revision, state.Combat.Phase,
			math.max(0, state.Ball.Speed * state.Ball.CurrentDirection:Dot((root.Position - state.Ball.Position).Unit)))
	end)
	return function() render:Disconnect(); folder:Destroy() end
end

return CombatDebugController
