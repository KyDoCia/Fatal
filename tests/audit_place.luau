local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local place = roblox.deserializePlace(fs.readFile("Fatal.rbxlx"))

local expected = {
	["ServerScriptService.Game.GameServer"] = "Script",
	["ServerScriptService.Game.CombatantRegistry"] = "ModuleScript",
	["ServerScriptService.Game.CombatCore"] = "ModuleScript",
	["ServerScriptService.Game.BallCore"] = "ModuleScript",
	["ServerScriptService.Game.TrainingOpponent"] = "ModuleScript",
	["ServerScriptService.Game.DuelService"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Game.ClientBootstrap"] = "LocalScript",
}
for path, className in expected do
	local value = place
	for segment in string.gmatch(path, "[^%.]+") do value = value:FindFirstChild(segment); assert(value, "missing " .. path) end
	assert(value.ClassName == className, "wrong class for " .. path)
end

local replicated = place:GetService("ReplicatedStorage").Game
for _, name in { "ParryIntent", "BallSnapshot", "CombatEvent" } do assert(replicated.Remotes[name]:IsA("RemoteEvent"), "missing remote " .. name) end
local ball = replicated.Assets.CombatBall
assert((ball.Size - roblox.Vector3.one * 1.4).Magnitude < 1e-4, "visual ball diameter must match radius 0.7")
local gui = place:GetService("StarterGui")
assert(gui:FindFirstChild("RallyGui") and not gui:FindFirstChild("HUD") and not gui:FindFirstChild("RoundGui") and not gui:FindFirstChild("CombatGui"), "V2 normal UI must contain only RallyGui")
local saved = 0
for _, value in place:GetService("Workspace"):GetDescendants() do if value:GetAttribute("FatalV2Ball") then saved += 1 end end
assert(saved == 0, "saved place contains authoritative ball")
local spawns = place:GetService("Workspace").Game.Arena.Gameplay.SpawnPoints:GetChildren()
table.sort(spawns, function(a, b) return a.Name < b.Name end)
local between = (spawns[2].CFrame.Position - spawns[1].CFrame.Position).Unit
assert(spawns[1].CFrame.LookVector:Dot(between) > 0.999 and spawns[2].CFrame.LookVector:Dot(-between) > 0.999, "duel spawns must face each other")
print("PASS: V2 place contract, compact ball, minimal UI, no saved ball")
