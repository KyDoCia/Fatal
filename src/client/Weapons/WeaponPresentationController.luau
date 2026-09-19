local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponPresentationController = {}
WeaponPresentationController.__index = WeaponPresentationController

function WeaponPresentationController.new(player, definition)
	local self = setmetatable({ Player = player, Definition = definition, Model = nil, Joint = nil }, WeaponPresentationController)
	self.Connection = player.CharacterAdded:Connect(function(character) self:Equip(character) end)
	self.RemovingConnection = player.CharacterRemoving:Connect(function() self:Unequip() end)
	if player.Character then self:Equip(player.Character) end
	return self
end

function WeaponPresentationController:Unequip()
	if self.Joint then self.Joint:Destroy(); self.Joint = nil end
	if self.Model then self.Model:Destroy(); self.Model = nil end
end

function WeaponPresentationController:Equip(character)
	self:Unequip()
	local grip = self.Definition.Grip
	local hand = character:WaitForChild(grip.Hand, 5)
	local source = ReplicatedStorage.Game.Assets:FindFirstChild(self.Definition.AssetName)
	if not hand or not source then return end
	local model = source:Clone()
	model.Name = "Equipped" .. self.Definition.Id
	local handle = if model:IsA("Model") then model.PrimaryPart else model
	local handAttachment = hand:FindFirstChild(grip.HandAttachment)
	local weaponAttachment = handle and handle:FindFirstChild(grip.WeaponAttachment)
	if not handle or not handAttachment or not weaponAttachment then model:Destroy(); return end
	for _, value in model:GetDescendants() do
		if value:IsA("BasePart") then
			value.Anchored = false; value.CanCollide = false; value.CanTouch = false; value.CanQuery = false; value.Massless = true
		end
	end
	model.Parent = character
	local weld = Instance.new("Motor6D")
	weld.Name = "WeaponGrip"; weld.Part0 = hand; weld.Part1 = handle
	weld.C0 = handAttachment.CFrame; weld.C1 = weaponAttachment.CFrame; weld.Parent = hand
	self.Model = model
	self.Joint = weld
end

function WeaponPresentationController:PresentIntent() end

function WeaponPresentationController:PresentParry() end

function WeaponPresentationController:PresentMiss()
	-- Miss presentation never changes the semantic grip or adds confirmed impact.
end

function WeaponPresentationController:Destroy()
	if self.Connection then self.Connection:Disconnect() end
	if self.RemovingConnection then self.RemovingConnection:Disconnect() end
	self:Unequip()
end

return WeaponPresentationController
