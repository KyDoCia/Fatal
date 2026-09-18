local fs = require("@lune/fs")
local luau = require("@lune/luau")

local files = {
	"src/shared/Config/CombatConfig.luau",
	"src/shared/Config/NPCConfig.luau",
	"src/shared/Config/RoundConfig.luau",
	"src/shared/Config/UIConfig.luau",
	"src/shared/Config/UITheme.luau",
	"src/shared/Types/CombatTypes.luau",
	"src/shared/Util/CharacterUtil.luau",
	"src/shared/Util/TrajectoryMath.luau",
	"src/server/GameServer.server.luau",
	"src/server/Combat/BallService.luau",
	"src/server/Combat/CombatantService.luau",
	"src/server/Combat/CombatService.luau",
	"src/server/Combat/WeaponService.luau",
	"src/server/NPC/NPCCombatController.luau",
	"src/server/NPC/NPCService.luau",
	"src/server/Rounds/RoundService.luau",
	"src/client/ClientBootstrap.client.luau",
	"src/client/ClientState.luau",
	"src/client/UI/HUDController.luau",
	"src/client/UI/RootUI.luau",
	"src/client/Combat/CameraFeedbackController.luau",
	"src/client/Combat/CombatController.luau",
	"src/client/Combat/CombatDebugController.luau",
	"src/client/Combat/CombatEffectsController.luau",
	"src/client/Combat/InputController.luau",
	"tools/generate_assets.luau",
	"tests/audit_place.luau",
	"tests/compile_all.luau",
	"tests/unit.luau",
}

for _, path in files do
	local chunk = luau.load(fs.readFile(path), { debugName = path })
	assert(type(chunk) == "function", "failed to compile " .. path)
end

print(string.format("PASS: compiled %d Luau files", #files))
