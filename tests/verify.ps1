$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $root

& lune run tools/generate_assets.luau
if ($LASTEXITCODE -ne 0) { throw "asset generation failed" }
& lune run tests/compile_all.luau
if ($LASTEXITCODE -ne 0) { throw "Luau compilation failed" }
& rojo build default.project.json -o FatalV2.rbxlx
if ($LASTEXITCODE -ne 0) { throw "Rojo build failed" }
& rojo sourcemap default.project.json -o sourcemap.json
if ($LASTEXITCODE -ne 0) { throw "sourcemap failed" }
& lune run tests/audit_place.luau
if ($LASTEXITCODE -ne 0) { throw "place audit failed" }
& lune run tests/unit.luau
if ($LASTEXITCODE -ne 0) { throw "unit tests failed" }

$heartbeat = @(& rg -l -F "Heartbeat:Connect" src/server)
if ($heartbeat.Count -ne 1 -or $heartbeat[0] -notmatch "GameServer") { throw "expected one server heartbeat owner" }
$oldPhases = @(& rg -n -e "ActiveUntil" -e "ArmedRevision" -e "TryConfirm" src)
if ($oldPhases.Count -ne 0) { throw "rejected parry state machine found: $oldPhases" }
Write-Host "PASS: Combat Core V2 verification"
