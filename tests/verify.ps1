$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

$project = Get-Content -Raw default.project.json | ConvertFrom-Json
foreach ($managed in @(
    $project.tree.ReplicatedStorage,
    $project.tree.ServerScriptService,
    $project.tree.StarterPlayer.StarterPlayerScripts,
    $project.tree.StarterGui
)) {
    if ($managed.'$ignoreUnknownInstances' -ne $false) { throw "Managed root preserves unknown instances" }
}

$forbidden = @("ServerScriptService.Server", "StarterPlayerScripts.Client", "Game.Combat.GameServer", "Game.Combat.RoundService")
foreach ($term in $forbidden) {
    $matches = & rg -n -F -- $term src default.project.json
    if ($LASTEXITCODE -eq 0) { throw "Non-canonical path found: $matches" }
    if ($LASTEXITCODE -ne 1) { throw "rg failed for $term" }
}

$heartbeatOwners = @(& rg -l -F "Heartbeat:Connect" src/server)
if ($heartbeatOwners.Count -ne 1 -or $heartbeatOwners[0] -notmatch "GameServer") { throw "Server must have one central Heartbeat owner" }
$clientClones = @(& rg -n -F ":Clone()" src/client)
if ($clientClones.Count -ne 0) { throw "Client clone found: $clientClones" }
$ballClones = @(& rg -n -F "FatalBall:Clone()" src/server)
if ($ballClones.Count -ne 1) { throw "Expected exactly one authoritative ball clone site: $ballClones" }
$roundRegistration = @(& rg -n -e "RegisterPlayer" -e "Combatants:Clear" src/server/Rounds)
if ($roundRegistration.Count -ne 0) { throw "RoundService must prepare persistent Player identities, not register/clear them: $roundRegistration" }
$rootUICreation = @(& rg -n -e 'Instance\.new' -e 'WaitForChild' src/client/UI/RootUI.luau)
if ($rootUICreation.Count -ne 0) { throw "RootUI must only validate and expose the declarative hierarchy: $rootUICreation" }

& lune run tools/generate_assets.luau
if ($LASTEXITCODE -ne 0) { throw "Asset generation failed" }
& lune run tests/compile_all.luau
if ($LASTEXITCODE -ne 0) { throw "Luau compilation failed" }
& rojo build default.project.json -o Fatal.rbxlx
if ($LASTEXITCODE -ne 0) { throw "Rojo build failed" }
& rojo sourcemap default.project.json -o sourcemap.json
if ($LASTEXITCODE -ne 0) { throw "Sourcemap generation failed" }
& lune run tests/audit_place.luau
if ($LASTEXITCODE -ne 0) { throw "Place audit failed" }
& lune run tests/unit.luau
if ($LASTEXITCODE -ne 0) { throw "Static unit suite failed" }
