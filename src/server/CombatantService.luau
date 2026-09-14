--!strict

local Players = game:GetService("Players")

local CombatantService = {}

local combatants: {[string]: any} = {}

local function idForPlayer(player: Player): string
	return `player:{player.UserId}`
end

function CombatantService.RegisterPlayer(player: Player): any?
	local character = player.Character
	if not character then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil
	end

	local id = idForPlayer(player)
	local combatant = {
		Id = id,
		Model = character,
		Root = root,
		Alive = true,
		IsPlayer = true,
		Player = player,
	}
	combatants[id] = combatant
	return combatant
end

function CombatantService.RemovePlayer(player: Player)
	combatants[idForPlayer(player)] = nil
end

function CombatantService.GetById(id: string): any?
	return combatants[id]
end

function CombatantService.GetAlive(): {any}
	local result = {}
	for _, combatant in combatants do
		if combatant.Alive and combatant.Model.Parent ~= nil then
			table.insert(result, combatant)
		end
	end
	return result
end

function CombatantService.RefreshPlayers()
	for _, player in Players:GetPlayers() do
		CombatantService.RegisterPlayer(player)
	end
end

function CombatantService.Eliminate(id: string)
	local combatant = combatants[id]
	if not combatant or not combatant.Alive then
		return
	end

	combatant.Alive = false
	local humanoid = combatant.Model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = 0
	end
end

return CombatantService
