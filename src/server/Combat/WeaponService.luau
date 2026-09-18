local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CharacterUtil = require(ReplicatedStorage.Game.Shared.Util.CharacterUtil)

local WeaponService = {}
WeaponService.__index = WeaponService

function WeaponService.new()
	local template = ReplicatedStorage.Game.Assets:WaitForChild("DefaultWeapon", 10)
	assert(template and template:IsA("Model") and template:FindFirstChild("Handle"), "DefaultWeapon asset is invalid")
	return setmetatable({ Template = template }, WeaponService)
end

function WeaponService:Unequip(character)
	local existing = character and character:FindFirstChild("FatalWeapon")
	if existing then existing:Destroy() end
	local body = character and CharacterUtil.Resolve(character)
	local joint = body and body.RightHand:FindFirstChild("FatalWeaponJoint")
	if joint then joint:Destroy() end
end

function WeaponService:Equip(character)
	local body = CharacterUtil.Resolve(character)
	if not body then return false end
	self:Unequip(character)
	local weapon = self.Template:Clone()
	weapon.Name = "FatalWeapon"
	for _, descendant in weapon:GetDescendants() do
		if descendant:IsA("BasePart") then
			descendant.Anchored = false
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.CollisionGroup = "Weapons"
		end
	end
	weapon.Parent = character
	local handle = weapon:FindFirstChild("Handle")
	local grip = CFrame.new(0, -1.35, -0.25) * CFrame.Angles(0, 0, math.rad(-18))
	handle.CFrame = body.RightHand.CFrame * grip
	local joint = Instance.new("Motor6D")
	joint.Name = "FatalWeaponJoint"
	joint.Part0 = body.RightHand
	joint.Part1 = handle
	joint.C0 = grip
	joint.Parent = body.RightHand
	return true
end

return WeaponService
