local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Game.Shared.Config.CombatConfig)
local CharacterUtil = require(ReplicatedStorage.Game.Shared.Util.CharacterUtil)
local TrajectoryMath = require(ReplicatedStorage.Game.Shared.Util.TrajectoryMath)

local TrainingOpponent = {}
TrainingOpponent.__index = TrainingOpponent

function TrainingOpponent.new(registry, combat, ball, container)
	return setmetatable({ Registry = registry, Combat = combat, Ball = ball, Container = container, Combatant = nil, Model = nil, AttemptedRevision = -1 }, TrainingOpponent)
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
	assert(CharacterUtil.WaitForR15(model, Config.Duel.CharacterTimeout), "TrainingOpponent incomplete R15")
	self.Model = model
	self.Combatant = self.Registry:RegisterNPC(model)
	self.Registry:SetAlive(self.Combatant, true)
	self.AttemptedRevision = -1
	return self.Combatant
end

function TrainingOpponent:Update()
	local actor = self.Combatant
	if not self.Registry:IsAlive(actor) or self.Ball:GetTarget() ~= actor then return end
	local revision = self.Ball:GetRevision()
	if revision == self.AttemptedRevision then return end
	local position, velocity = self.Ball:GetKinematics()
	local center = actor.CenterPart.Position
	local distance = (center - position).Magnitude
	if not TrajectoryMath.IsApproaching(position, velocity, center, Config.Parry.ApproachEpsilon) then return end
	if distance <= Config.NPC.ReactionRadius then
		self.AttemptedRevision = revision
		self.Combat:TryParry(actor, nil)
	end
end

function TrainingOpponent:Clear()
	if self.Combatant then self.Registry:Unregister(self.Combatant) end
	if self.Model then self.Model:Destroy() end
	self.Combatant = nil
	self.Model = nil
	self.AttemptedRevision = -1
end

return TrainingOpponent
