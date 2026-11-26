param([ValidateSet("android-aab","android-apk","windows","all")][string]$Target = "all")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $root

$bad = 0
foreach ($f in (Get-ChildItem scripts -Filter *.gd -Recurse)) {
    $lines = Get-Content $f.FullName
    for ($i = 4; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*#') { $bad++ } }
}
if ($bad -ne 0) { throw "HYGIENE_COMMENTS=$bad" }
python tools/verify_assets.py --game | Out-Null
if ($LASTEXITCODE -ne 0) { throw "asset integrity gate failed" }
foreach ($test in @("parse_all", "scene_smoke", "determinism_harness", "campaign_balance_harness", "release_readiness_harness")) {
    $script = "res://tests/$test.gd"
    if ($test -in @("parse_all", "scene_smoke")) { $script = "res://tests/$test.tscn" }
    & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path . $script > "builds/$test.log" 2>&1
}
New-Item -ItemType Directory -Path builds -Force | Out-Null

function SigningVars {
    foreach ($name in @("TPS_KEYSTORE_PATH","TPS_KEYSTORE_USER","TPS_KEYSTORE_PASS","TPS_KEY_PASS")) {
        if (-not (Get-Item "env:$name" -ErrorAction SilentlyContinue)) { throw "Missing $name — see docs/RELEASE-SIGNING.md" }
    }
}

function Build($preset, $out) {
    & "C:\Godot\Godot_v4.0-stable_win64_console.exe" --headless --path . --export-release $preset $out
    if (-not (Test-Path $out)) { throw "build failed: $out" }
    $hash = (Get-FileHash $out -Algorithm SHA256).Hash
    Write-Output "$out $((Get-Item $out).Length) bytes SHA256=$hash"
}

if ($Target -in @("android-aab","android-apk","all")) {
    SigningVars
    if ($Target -in @("android-aab","all")) { Build "Android" "builds\TacPlan-1.0.0-release.aab" }
    if ($Target -in @("android-apk","all")) { Build "Android" "builds\TacPlan-1.0.0-release.apk" }
}
if ($Target -in @("windows","all")) { Build "Windows Desktop" "builds\TacPlan-1.0.0-release.exe" }
