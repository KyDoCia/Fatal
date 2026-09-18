local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local function child(parent, name, className, timeout)
	local value = parent:WaitForChild(name, timeout or 10)
	assert(value and value:IsA(className), string.format("FATAL client startup missing %s.%s (%s)", parent:GetFullName(), name, className))
	return value
end

local root = script.Parent
local replicatedGame = child(ReplicatedStorage, "Game", "Folder")
local shared = child(replicatedGame, "Shared", "Folder")
local config = child(shared, "Config", "Folder")
for _, name in { "CombatConfig", "NPCConfig", "UIConfig", "UITheme" } do require(child(config, name, "ModuleScript")) end
local roundConfig = require(child(config, "RoundConfig", "ModuleScript"))

local playerGui = child(Players.LocalPlayer, "PlayerGui", "PlayerGui", roundConfig.StartupTimeout)
for _, guiName in { "HUD", "RoundGui", "CombatGui" } do child(playerGui, guiName, "ScreenGui", roundConfig.StartupTimeout) end

local state = require(child(root, "ClientState", "ModuleScript"))
local uiFolder = child(root, "UI", "Folder")
local ui = require(child(uiFolder, "RootUI", "ModuleScript")).Create(playerGui)
local hudController = require(child(uiFolder, "HUDController", "ModuleScript"))
local combatFolder = child(root, "Combat", "Folder")
local inputController = require(child(combatFolder, "InputController", "ModuleScript"))
local combatController = require(child(combatFolder, "CombatController", "ModuleScript"))
local effects = require(child(combatFolder, "CombatEffectsController", "ModuleScript"))
local camera = require(child(combatFolder, "CameraFeedbackController", "ModuleScript"))
local debugController = require(child(combatFolder, "CombatDebugController", "ModuleScript"))

local remotes = child(replicatedGame, "Remotes", "Folder")
local combatRemotes = child(remotes, "Combat", "Folder")
local roundRemotes = child(remotes, "Round", "Folder")
effects.Bind(ui)
local stopHUD = hudController.Start(state, ui, child(roundRemotes, "RoundState", "RemoteEvent"))
local attemptParry, stopCombat = combatController.Start(state, ui, {
	ParryRequest = child(combatRemotes, "ParryRequest", "RemoteEvent"),
	BallSnapshot = child(combatRemotes, "BallSnapshot", "RemoteEvent"),
	CombatEffect = child(combatRemotes, "CombatEffect", "RemoteEvent"),
}, effects)
local stopCamera = camera.Start(state)
local stopDebug = debugController.Start(state)
local stopInput = inputController.Start(ui.ParryButton, attemptParry)

script.Destroying:Connect(function()
	stopInput()
	stopCamera()
	stopDebug()
	stopCombat()
	stopHUD()
end)
