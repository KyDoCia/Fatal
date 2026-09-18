local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local CharacterUtil = require(ReplicatedStorage.Game.Shared.Util.CharacterUtil)
local TrajectoryMath = require(ReplicatedStorage.Game.Shared.Util.TrajectoryMath)

local TrainingOpponent = {}
TrainingOpponent.__index = TrainingOpponent

function TrainingOpponent.new(registry, combat, ball, container)
	return setmetatable({ Registry = registry, Combat = combat, Ball = ball, Container = container, Random = Random.new(), Combatant = nil, Model = nil, Revision = -1, AttemptAt = nil }, TrainingOpponent)
end

function TrainingOpponent:Spawn(cframe)
	assert(not self.Model, "TrainingOpponent already exists")
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = Color3.fromRGB(105, 108, 118)
	description.TorsoColor = Color3.fromRGB(32, 34, 40)
	local ok, model = pcall(function() return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15) end)
	description:Destroy()
	assert(ok and model, "failed to create TrainingOpponent R15: " .. tostring(model))
	model.Name = "TrainingOpponent"
	model:SetAttribute("CombatantId", "N:TrainingOpponent")
	model.Parent = self.Container
	model:PivotTo(cframe)
	assert(CharacterUtil.WaitForR15(model, Config.Round.CharacterTimeout), "TrainingOpponent incomplete R15")
	self.Model = model
	self.Combatant = self.Registry:RegisterNPC(model)
	self.Registry:SetAlive(self.Combatant, true)
	self.Revision = -1
	self.AttemptAt = nil
	return self.Combatant
end

function TrainingOpponent:Update(now)
	local actor = self.Combatant
	if not self.Registry:IsAlive(actor) or self.Ball:GetTarget() ~= actor then self.AttemptAt = nil; return end
	local revision = self.Ball:GetRevision()
	if revision ~= self.Revision then self.Revision = revision; self.AttemptAt = nil end
	local position, velocity = self.Ball:GetKinematics()
	local center = actor.CenterPart.Position
	local distance = (center - position).Magnitude
	if not TrajectoryMath.IsApproaching(position, velocity, center, Config.Parry.ApproachEpsilon) then return end
	if not self.AttemptAt and distance <= Config.NPC.ReactionRadius then
		if self.Random:NextNumber() < Config.NPC.MissChance then self.AttemptAt = math.huge
		else self.AttemptAt = now + self.Random:NextNumber(Config.NPC.ReactionMin, Config.NPC.ReactionMax) end
	end
	if self.AttemptAt and now >= self.AttemptAt then
		self.AttemptAt = math.huge
		self.Combat:TryParry(actor)
	end
end

function TrainingOpponent:Clear()
	if self.Combatant then self.Registry:Unregister(self.Combatant) end
	if self.Model then self.Model:Destroy() end
	self.Combatant = nil
	self.Model = nil
	self.Revision = -1
	self.AttemptAt = nil
end

return TrainingOpponent
