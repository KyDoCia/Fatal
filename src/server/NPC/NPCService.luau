local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local NPCConfig = require(ReplicatedStorage.Game.Shared.Config.NPCConfig)
local CharacterUtil = require(ReplicatedStorage.Game.Shared.Util.CharacterUtil)
local NPCCombatController = require(script.Parent.NPCCombatController)

local NPCService = {}
NPCService.__index = NPCService

function NPCService.new(combatants, combat, ball, weapons, arena)
	local gameplay = arena:WaitForChild("Gameplay", 10)
	assert(gameplay and gameplay:IsA("Folder"), "FATAL arena missing Gameplay")
	local container = gameplay:FindFirstChild("NPCs") or Instance.new("Folder")
	container.Name = "NPCs"
	container.Parent = gameplay
	return setmetatable({
		Combatants = combatants,
		Combat = combat,
		Ball = ball,
		Weapons = weapons,
		Container = container,
		Floor = assert(gameplay:WaitForChild("Floor", 10), "FATAL arena missing Gameplay.Floor"),
		Controllers = {},
		Models = {},
		Clock = 0,
		Random = Random.new(),
	}, NPCService)
end

function NPCService:_createModel(index)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Color3.fromRGB(95, 99, 112)
	description.TorsoColor = Color3.fromRGB(34, 37, 46)
	description.LeftArmColor = Color3.fromRGB(72, 76, 89)
	description.RightArmColor = Color3.fromRGB(72, 76, 89)
	description.LeftLegColor = Color3.fromRGB(28, 30, 38)
	description.RightLegColor = Color3.fromRGB(28, 30, 38)
	local ok, model = pcall(function()
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	description:Destroy()
	if not ok then warn("[Fatal/NPC] R15 creation failed: " .. tostring(model)); return nil end
	model.Name = if index == 1 then "TrainingOpponent" else string.format("TrainingOpponent_%02d", index)
	model:SetAttribute("CombatantId", string.format("N:%02d", index))
	model.Parent = self.Container
	for _, descendant in model:GetDescendants() do
		if descendant:IsA("BasePart") then descendant.CollisionGroup = "NPCs" end
	end
	return model
end

function NPCService:Spawn(count, spawnPoints)
	local combatants = {}
	for index = 1, count do
		local model = self:_createModel(index)
		if model then
			model:PivotTo(spawnPoints[index].CFrame + Vector3.new(0, 3, 0))
			local body = CharacterUtil.WaitForR15(model, 5)
			if body then
				local combatant = self.Combatants:RegisterNPC(model)
				self.Combatants:SetAlive(combatant.Id, true, "CombatLabPrepare")
				self.Weapons:Equip(model)
				table.insert(self.Models, model)
				table.insert(self.Controllers, NPCCombatController.new(combatant, self.Combat, self.Ball, self.Floor, self.Random))
				table.insert(combatants, combatant)
			else
				warn("[Fatal/NPC] generated model did not satisfy the R15 contract")
				model:Destroy()
			end
		end
	end
	return combatants
end

function NPCService:Update(dt)
	self.Clock += dt
	if self.Clock < NPCConfig.ThinkInterval then return end
	self.Clock = 0
	local now = workspace:GetServerTimeNow()
	for _, controller in self.Controllers do controller:Update(now) end
end

function NPCService:Clear()
	for _, model in self.Models do
		local id = model:GetAttribute("CombatantId")
		if id then self.Combatants:Unregister(id) end
		self.Weapons:Unequip(model)
		model:Destroy()
	end
	table.clear(self.Models)
	table.clear(self.Controllers)
	self.Clock = 0
end

return NPCService
