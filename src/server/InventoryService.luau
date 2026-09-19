local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Definitions = require(ReplicatedStorage.Game.Shared.Weapons.WeaponDefinitions)

local InventoryService = {}
InventoryService.__index = InventoryService

function InventoryService.new(profiles, stateRemote)
	return setmetatable({ Profiles = profiles, State = stateRemote }, InventoryService)
end

function InventoryService:Sync(player)
	local profile = self.Profiles:Get(player)
	if not profile then return end
	self.State:FireClient(player, { Weapons = profile.Inventory.Weapons, EquippedWeapon = profile.Equipped.Weapon })
end

function InventoryService:Equip(player, itemId)
	local profile = self.Profiles:Get(player)
	if not profile or type(itemId) ~= "string" or not Definitions[itemId] then return false, "UNKNOWN_ITEM" end
	if profile.Inventory.Weapons[itemId] ~= true then return false, "NOT_OWNED" end
	profile.Equipped.Weapon = itemId
	self:Sync(player)
	return true
end

return InventoryService
