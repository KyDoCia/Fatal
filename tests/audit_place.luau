local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local place = roblox.deserializePlace(fs.readFile("Fatal.rbxlx"))

local expectedScripts = {
	["ReplicatedStorage.Game.Shared.Config.CombatConfig"] = "ModuleScript",
	["ReplicatedStorage.Game.Shared.Util.CharacterUtil"] = "ModuleScript",
	["ReplicatedStorage.Game.Shared.Util.TrajectoryMath"] = "ModuleScript",
	["ServerScriptService.Game.GameServer"] = "Script",
	["ServerScriptService.Game.CombatantRegistry"] = "ModuleScript",
	["ServerScriptService.Game.CombatCore"] = "ModuleScript",
	["ServerScriptService.Game.BallCore"] = "ModuleScript",
	["ServerScriptService.Game.TrainingOpponent"] = "ModuleScript",
	["ServerScriptService.Game.DuelService"] = "ModuleScript",
	["StarterPlayer.StarterPlayerScripts.Game.ClientBootstrap"] = "LocalScript",
}

local function resolve(path)
	local value = place
	for segment in string.gmatch(path, "[^%.]+") do
		value = value:FindFirstChild(segment)
		assert(value, "missing canonical runtime instance: " .. path)
	end
	return value
end

for path, className in expectedScripts do assert(resolve(path).ClassName == className, "wrong class for " .. path) end

local scriptCount = 0
for _, serviceName in { "ReplicatedStorage", "ServerScriptService", "StarterPlayer", "StarterGui", "Workspace" } do
	for _, value in place:GetService(serviceName):GetDescendants() do
		if value:IsA("LuaSourceContainer") then
			scriptCount += 1
			local path = value:GetFullName()
			assert(expectedScripts[path] == value.ClassName, "unexpected runtime script: " .. path)
		end
	end
end
assert(scriptCount == 10, "expected exactly 10 canonical V2 scripts")

local replicated = place:GetService("ReplicatedStorage").Game
for _, name in { "ParryIntent", "BallSnapshot", "CombatEvent" } do assert(replicated.Remotes[name]:IsA("RemoteEvent"), "missing remote " .. name) end
assert(#replicated.Assets:GetChildren() == 1, "V2 assets must contain only the gameplay ball source")
local ball = replicated.Assets.CombatBall
assert(ball:IsA("BasePart") and (ball.Size - roblox.Vector3.one * 2).Magnitude < 1e-4, "built ball must be 2 studs on every axis")
assert(ball:FindFirstChildOfClass("Trail"), "built ball must preserve the readable motion trail")
assert(ball:FindFirstChild("CoreLight") and ball.CoreLight:IsA("PointLight"), "built ball must expose the parry flash light")
assert(ball:FindFirstChild("ParrySound") and ball.ParrySound:IsA("Sound") and ball:FindFirstChild("HitSound") and ball.HitSound:IsA("Sound"), "built ball must expose empty sound hooks")

local starterGui = place:GetService("StarterGui")
local guiChildren = starterGui:GetChildren()
assert(#guiChildren == 1 and guiChildren[1].Name == "RallyGui" and guiChildren[1]:IsA("ScreenGui"), "normal runtime UI must contain only RallyGui")
local rallyChildren = guiChildren[1]:GetDescendants()
assert(#rallyChildren == 1 and rallyChildren[1].Name == "Rally" and rallyChildren[1]:IsA("TextLabel"), "RallyGui must contain only the small rally label")

local forbiddenTokens = {
	"FIGHT", "CRITICAL", "TIMETOIMPACT", "TARGETINDICATOR", "COMBATGUI", "ROUNDGUI",
	"FATALCOMBATDEBUG", "BALLRADIUS", "HURTVOLUME", "RETICLESTROKE", "FATALIMPACT", "FATALPARRYRING",
}
local forbiddenClasses = {
	BillboardGui = true, SurfaceGui = true, SelectionBox = true, BoxHandleAdornment = true,
	SphereHandleAdornment = true, CylinderHandleAdornment = true, ConeHandleAdornment = true, Highlight = true,
}
for _, serviceName in { "ReplicatedStorage", "ServerScriptService", "StarterPlayer", "StarterGui", "Workspace" } do
	for _, value in place:GetService(serviceName):GetDescendants() do
		local name = string.upper(value.Name)
		for _, token in forbiddenTokens do assert(not string.find(name, token, 1, true), "rejected legacy instance in build: " .. value:GetFullName()) end
		assert(not forbiddenClasses[value.ClassName], "rejected debug/marker class in build: " .. value:GetFullName())
		if value:IsA("TextLabel") or value:IsA("TextButton") or value:IsA("TextBox") then
			local text = string.upper(value.Text)
			assert(not string.find(text, "FIGHT", 1, true) and not string.find(text, "CRITICAL", 1, true), "rejected legacy text in build")
		end
		if value:IsA("LuaSourceContainer") then
			local source = string.upper(value.Source)
			for _, token in forbiddenTokens do assert(not string.find(source, token, 1, true), "rejected legacy producer in script: " .. value:GetFullName()) end
		end
	end
end

local world = place:GetService("Workspace").Game
assert(world:GetAttribute("FatalRuntimeContract") == "CombatCoreV2CleanRoom", "missing clean-room runtime provenance")
local gameplay = world.Arena.Gameplay
local spawns = gameplay.SpawnPoints:GetChildren()
table.sort(spawns, function(a, b) return a.Name < b.Name end)
assert(#spawns == 2, "clean duel requires exactly two spawn references")
assert(math.abs((spawns[2].CFrame.Position - spawns[1].CFrame.Position).Magnitude - 40) < 1e-4, "duel spawn separation must preserve the one-second opening read")
for _, spawn in spawns do assert(spawn.Transparency == 1 and not spawn.CanCollide and not spawn.CanTouch and not spawn.CanQuery, "spawn references must be invisible") end
local between = (spawns[2].CFrame.Position - spawns[1].CFrame.Position).Unit
assert(spawns[1].CFrame.LookVector:Dot(between) > 0.999 and spawns[2].CFrame.LookVector:Dot(-between) > 0.999, "duel spawns must face each other")

local savedBalls = 0
for _, value in place:GetService("Workspace"):GetDescendants() do if value:GetAttribute("FatalV2Ball") then savedBalls += 1 end end
assert(savedBalls == 0, "saved place contains an authoritative gameplay ball")

print("PASS: clean-room place has 10 scripts, RallyGui only, 2-stud readable ball, no legacy presentation")
