local fs = require("@lune/fs")
local luau = require("@lune/luau")

local files = {
	"src/shared/Config/CombatConfig.luau",
	"src/shared/Combat/CombatTypes.luau",
	"src/shared/Weapons/WeaponDefinitions.luau",
	"src/shared/Balls/BallDefinitions.luau",
	"src/shared/Profile/ProfileSchema.luau",
	"src/shared/Effects/ParryEffectDefinitions.luau",
	"src/shared/Animations/AnimationDefinitions.luau",
	"src/shared/Util/CharacterUtil.luau",
	"src/shared/Util/TrajectoryMath.luau",
	"src/server/CombatantRegistry.luau",
	"src/server/CombatCore.luau",
	"src/server/BallCore.luau",
	"src/server/TrainingOpponent.luau",
	"src/server/DuelService.luau",
	"src/server/ProfileService.luau",
	"src/server/TargetSelector.luau",
	"src/server/InventoryService.luau",
	"src/server/GameServer.server.luau",
	"src/client/ClientBootstrap.client.luau",
	"src/client/Input/CombatInputController.luau",
	"src/client/Weapons/WeaponPresentationController.luau",
	"src/client/InventoryController.luau",
	"src/client/ParryEffectController.luau",
	"src/client/Animations/CharacterAnimationController.luau",
	"src/client/Animations/WeaponAnimationController.luau",
}

for _, path in files do
	local chunk, failure = luau.compile(fs.readFile(path), { debugName = path })
	assert(chunk, failure)
end

print(string.format("PASS: compiled %d Luau files", #files))
