local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local WeaponPresentationController = {}
WeaponPresentationController.__index = WeaponPresentationController

function WeaponPresentationController.new(player, definition)
	local self = setmetatable({ Player = player, Definition = definition, Model = nil, Track = nil, Connection = nil }, WeaponPresentationController)
	self.Connection = player.CharacterAdded:Connect(function(character) self:Equip(character) end)
	if player.Character then self:Equip(player.Character) end
	return self
end

function WeaponPresentationController:Equip(character)
	if self.Model then self.Model:Destroy(); self.Model = nil end
	local hand = character:WaitForChild("RightHand", 5)
	local source = ReplicatedStorage.Game.Assets:FindFirstChild(self.Definition.AssetName)
	if not hand or not source then return end
	local model = source:Clone()
	model.Name = "Equipped" .. self.Definition.Id
	model.CanCollide = false
	model.CanTouch = false
	model.CanQuery = false
	model.Massless = true
	model.CFrame = hand.CFrame * self.Definition.Grip
	model.Parent = character
	local weld = Instance.new("Motor6D")
	weld.Name = "WeaponGrip"; weld.Part0 = hand; weld.Part1 = model; weld.C0 = self.Definition.Grip; weld.Parent = hand
	self.Model = model
	self.Joint = weld
	local animationId = self.Definition.Animations.ParryAnimations[1]
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if animator and animationId ~= "" then
		local animation = Instance.new("Animation")
		animation.AnimationId = animationId
		self.Track = animator:LoadAnimation(animation)
		animation:Destroy()
	end
end

function WeaponPresentationController:PresentIntent(direction)
	if self.Joint then
		local side = if direction and direction.X < 0 then -1 else 1
		self.Joint.Transform = CFrame.Angles(0, 0, math.rad(42 * side))
		TweenService:Create(self.Joint, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Transform = CFrame.identity }):Play()
	end
end

function WeaponPresentationController:PresentParry()
	if self.Track then self.Track:Play(0.03, 1, 1) end
end

function WeaponPresentationController:Destroy()
	if self.Connection then self.Connection:Disconnect() end
	if self.Model then self.Model:Destroy() end
end

return WeaponPresentationController
