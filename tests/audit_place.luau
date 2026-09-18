local fs = require("@lune/fs")
local roblox = require("@lune/roblox")

local place = roblox.deserializePlace(fs.readFile("Fatal.rbxlx"))
local expectedScripts = {
	["ServerScriptService.Game.GameServer"] = "Script",
	["ServerScriptService.Game.Combat.CombatantService"] = "ModuleScript",
	["ServerScriptService.Game.Combat.CombatService"] = "ModuleScript",
	["ServerScriptService.Game.Combat.BallService"] = "ModuleScript",
	["ServerScriptService.Game.Combat.WeaponService"] = "ModuleScript",
	["ServerScriptService.Game.NPC.NPCService"] = "ModuleScript",
	["ServerScriptService.Game.NPC.NPCCombatController"] = "ModuleScript",
	["ServerScriptService.Game.Rounds.RoundService"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Game.ClientBootstrap"] = "LocalScript",
	["StarterPlayer.StarterPlayerScripts.Game.ClientState"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Game.UI.RootUI"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Game.UI.HUDController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Game.Combat.InputController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Game.Combat.CombatController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Game.Combat.CombatEffectsController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Game.Combat.CameraFeedbackController"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Game.Combat.CombatDebugController"] = "ModuleScript",
}
local foundScripts = {}
local localScriptCount = 0
local expectedScriptCount = 0
for _ in expectedScripts do expectedScriptCount += 1 end
for _, instance in place:GetDescendants() do
	if instance:IsA("LuaSourceContainer") then
		local path = instance:GetFullName()
		foundScripts[path] = (foundScripts[path] or 0) + 1
		if instance:IsA("LocalScript") then localScriptCount += 1 end
		assert(not instance.Source:find(":FindFirstChild%([^%)]-,%s*true"), "recursive module discovery found: " .. path)
		assert(not instance.Source:find("%.Touched"), "Touched-based gameplay collision found: " .. path)
	end
end
for path, className in expectedScripts do
	assert(foundScripts[path] == 1, "missing or duplicate canonical script: " .. path)
	local cursor = place
	for segment in path:gmatch("[^%.]+") do cursor = cursor[segment] end
	assert(cursor.ClassName == className, path .. " has wrong class")
end
assert(localScriptCount == 1, "ClientBootstrap must be the only LocalScript")
assert(place:GetService("ServerScriptService"):FindFirstChild("Server") == nil, "parallel server tree found")
assert(place:GetService("StarterPlayer").StarterPlayerScripts:FindFirstChild("Client") == nil, "parallel client tree found")

local replicated = place:GetService("ReplicatedStorage")
local expectedRemotes = {
	["ReplicatedStorage.Game.Remotes.Combat.ParryRequest"] = true,
	["ReplicatedStorage.Game.Remotes.Combat.BallSnapshot"] = true,
	["ReplicatedStorage.Game.Remotes.Combat.CombatEffect"] = true,
	["ReplicatedStorage.Game.Remotes.Round.RoundState"] = true,
}
local remoteCount = 0
for _, instance in replicated:GetDescendants() do
	if instance:IsA("RemoteEvent") then
		remoteCount += 1
		assert(expectedRemotes[instance:GetFullName()], "unexpected remote: " .. instance:GetFullName())
	end
end
assert(remoteCount == 4, "expected exactly four remotes")

local starter = place:GetService("StarterPlayer")
assert(starter.GameSettingsAvatar == roblox.Enum.GameAvatarType.R15, "place must enforce R15")
local starterGui = place:GetService("StarterGui")
assert(not starterGui.ResetPlayerGuiOnSpawn, "StarterGui must preserve the declarative interface across respawns")
for _, guiName in { "HUD", "RoundGui", "CombatGui" } do
	local gui = starterGui:FindFirstChild(guiName)
	assert(gui and gui:IsA("ScreenGui") and not gui.ResetOnSpawn, "invalid declarative GUI: " .. guiName)
end
local topStatus = starterGui.HUD:FindFirstChild("TopStatus")
local telemetry = starterGui.HUD:FindFirstChild("Telemetry")
local targetIndicator = starterGui.HUD:FindFirstChild("TargetIndicator")
assert(topStatus and topStatus.Round and topStatus.Alive, "HUD top status contract missing")
assert(telemetry and telemetry.Speed and telemetry.Rally, "HUD telemetry contract missing")
assert(targetIndicator and targetIndicator.State and targetIndicator.Time and targetIndicator.PulseScale and targetIndicator.ReticleStroke, "HUD target contract missing")
assert(starterGui.RoundGui.Countdown and starterGui.RoundGui.Countdown.Label and starterGui.RoundGui.Countdown.MotionScale, "RoundGui countdown contract missing")
assert(starterGui.CombatGui.ParryButton and starterGui.CombatGui.ParryButton.MotionScale, "mobile parry button contract missing")

local world = place:GetService("Workspace").Game
local gameplay = world.Arena.Gameplay
assert(gameplay.Floor and gameplay.Walls and gameplay.SpawnPoints and gameplay.KillBounds, "arena gameplay structure incomplete")
assert(world.Arena.Visual, "arena visual structure missing")
assert(#gameplay.SpawnPoints:GetChildren() == 2 and #gameplay.Walls:GetChildren() == 4, "Combat Lab arena contract invalid")
assert(#world.Arena.Visual:GetChildren() <= 4, "Combat Lab must not contain decorative geometry")
local savedBalls = 0
for _, instance in place:GetService("Workspace"):GetDescendants() do if instance:GetAttribute("FatalAuthoritativeBall") then savedBalls += 1 end end
assert(savedBalls == 0, "saved place contains an authoritative gameplay ball")
local weapon = replicated.Game.Assets.DefaultWeapon
assert(weapon:IsA("Model") and weapon.Handle and weapon.Guard and weapon.Blade and weapon.PrimaryPart == weapon.Handle, "DefaultWeapon silhouette contract invalid")
local ball = replicated.Game.Assets.FatalBall
assert(ball:IsA("BasePart") and ball:FindFirstChildOfClass("Trail") and ball:FindFirstChild("CoreLight"), "Combat Lab ball contract invalid")
assert((ball.Size - roblox.Vector3.one * 2.2).Magnitude < 1e-4, "Combat Lab ball visual must match the 1.1-stud authoritative radius")

print(string.format("PASS: canonical_scripts=%d remotes=%d saved_balls=%d", expectedScriptCount, remoteCount, savedBalls))
