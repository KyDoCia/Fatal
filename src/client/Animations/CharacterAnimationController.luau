local Controller = {}
Controller.__index = Controller

local slots = table.freeze({
	Idle = { { "idle", "Animation1" }, { "idle", "Animation2" } },
	Walk = { { "walk", "WalkAnim" } },
	Run = { { "run", "RunAnim" } },
	Jump = { { "jump", "JumpAnim" } },
	Fall = { { "fall", "FallAnim" } },
})

function Controller.new(player, animationSet)
	local self = setmetatable({ Player = player, Set = animationSet, Originals = {} }, Controller)
	self.Connection = player.CharacterAdded:Connect(function(character) self:Apply(character) end)
	self.RemovingConnection = player.CharacterRemoving:Connect(function(character) self:Clear(character) end)
	if player.Character then self:Apply(player.Character) end
	return self
end

function Controller:Clear(character)
	if character ~= self.Character then return end
	local restored = false
	for animation, id in self.Originals do
		if animation.Parent then animation.AnimationId = id; restored = true end
	end
	table.clear(self.Originals)
	local animate = character and character:FindFirstChild("Animate")
	if restored and animate and animate:IsA("LocalScript") then
		animate.Disabled = true
		animate.Disabled = false
	end
	self.Character = nil
end

function Controller:Apply(character)
	self:Clear(self.Character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then return end
	self.Character = character
	local animate = character:FindFirstChild("Animate") or character:WaitForChild("Animate", 3)
	if not animate then return end
	local changed = false
	for state, paths in slots do
		local id = self.Set[state]
		if type(id) == "string" and id ~= "" then
			for _, path in paths do
				local folder = animate:FindFirstChild(path[1])
				local animation = folder and folder:FindFirstChild(path[2])
				if animation and animation:IsA("Animation") then
					self.Originals[animation] = animation.AnimationId
					animation.AnimationId = id
					changed = true
				end
			end
		end
	end
	if changed and animate:IsA("LocalScript") then
		animate.Disabled = true
		animate.Disabled = false
	end
end

function Controller:Destroy()
	self:Clear(self.Character)
	if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
	if self.RemovingConnection then self.RemovingConnection:Disconnect(); self.RemovingConnection = nil end
end

return Controller
