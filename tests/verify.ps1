$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

$canonicalBuild = Join-Path $root "Fatal.rbxlx"
$legacyBuild = Join-Path $root "FatalV2.rbxlx"
foreach ($build in @($canonicalBuild, $legacyBuild)) {
    if (Test-Path -LiteralPath $build) { Remove-Item -LiteralPath $build }
}

$legacySource = @(& rg -n -i -e "FIGHT" -e "CRITICAL" -e "TimeToImpact" -e "TargetIndicator" -e "CombatGui" -e "RoundGui" -e "FatalCombatDebug" -e "BallRadius" -e "HurtVolume" -e "ReticleStroke" -e "FatalImpact" -e "FatalParryRing" -e "ActiveUntil" -e "ArmedRevision" -e "TryConfirm" src tools default.project.json)
if ($legacySource.Count -ne 0) { throw "rejected legacy presentation source found: $legacySource" }
$ballCloneSites = @(& rg -n -F "CombatBall:Clone()" src/server)
if ($ballCloneSites.Count -ne 1) { throw "expected exactly one gameplay ball clone site: $ballCloneSites" }
$heartbeat = @(& rg -l -F "Heartbeat:Connect" src/server)
if ($heartbeat.Count -ne 1 -or $heartbeat[0] -notmatch "GameServer") { throw "expected one server heartbeat owner" }

& cmd.exe /d /c "lune run tools/generate_assets.luau"
if ($LASTEXITCODE -ne 0) { throw "asset generation failed" }
& cmd.exe /d /c "lune run tests/compile_all.luau"
if ($LASTEXITCODE -ne 0) { throw "Luau compilation failed" }
& cmd.exe /d /c "rojo build default.project.json -o Fatal.rbxlx"
if ($LASTEXITCODE -ne 0) { throw "Rojo build failed" }
if (Test-Path -LiteralPath $legacyBuild) { throw "legacy FatalV2.rbxlx must not be produced" }
& cmd.exe /d /c "rojo sourcemap default.project.json -o sourcemap.json"
if ($LASTEXITCODE -ne 0) { throw "sourcemap failed" }
& cmd.exe /d /c "lune run tests/audit_place.luau"
if ($LASTEXITCODE -ne 0) { throw "place audit failed" }
& cmd.exe /d /c "lune run tests/unit.luau"
if ($LASTEXITCODE -ne 0) { throw "unit tests failed" }

Write-Host "PASS: Combat Core V2 verification"
