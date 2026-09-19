local Controller = {}
Controller.__index = Controller

function Controller.new(player, animationSet)
	local self = setmetatable({ Player = player, Set = animationSet, Connection = nil }, Controller)
	self.Connection = player.CharacterAdded:Connect(function(character) self:Apply(character) end)
	if player.Character then self:Apply(player.Character) end
	return self
end

function Controller:Apply(character)
	-- Empty slots deliberately preserve Roblox's R15 Animate fallback.
	if not character:FindFirstChildOfClass("Humanoid") then return end
	for _, id in self.Set do if id ~= "" then return end end
end

function Controller:Destroy()
	if self.Connection then self.Connection:Disconnect(); self.Connection = nil end
end

return Controller
