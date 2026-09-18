local fs = require("@lune/fs")
local luau = require("@lune/luau")

local files = {
	"src/shared/Config/CombatConfig.luau",
	"src/shared/Util/CharacterUtil.luau",
	"src/shared/Util/TrajectoryMath.luau",
	"src/server/CombatantRegistry.luau",
	"src/server/CombatCore.luau",
	"src/server/BallCore.luau",
	"src/server/TrainingOpponent.luau",
	"src/server/DuelService.luau",
	"src/server/GameServer.server.luau",
	"src/client/ClientBootstrap.client.luau",
}

for _, path in files do
	local chunk, failure = luau.compile(fs.readFile(path), { debugName = path })
	assert(chunk, failure)
end

print(string.format("PASS: compiled %d Luau files", #files))
