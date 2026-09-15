param(
    [Parameter(Mandatory=$true)]
    [string]$OutputDir
)

$ErrorActionPreference = "Stop"
New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
$env:P1_UI_EVIDENCE_DIR = $OutputDir
$logPath = Join-Path $env:RUNNER_TEMP "p1_ui_capture.log"

$godot = if ($env:GODOT) { $env:GODOT } else { "godot" }
& $godot --path . --audio-driver Dummy --rendering-method gl_compatibility --rendering-driver d3d12 --script res://tests/p1_ui_visual_capture.gd 2>&1 | Tee-Object -FilePath $logPath
$status = $LASTEXITCODE
if ($status -ne 0) {
    Write-Error "Godot UI capture exited with status $status"
}
$log = Get-Content -Raw -Path $logPath
if ($log -match "SCRIPT ERROR:|ERROR:") {
    Write-Error "Godot UI capture emitted engine/script ERROR output"
}
if ($log -notmatch "P1_UI_CAPTURE_PASS") {
    Write-Error "Godot UI capture did not emit expected PASS marker"
}
foreach ($required in @(
    "00_static.png",
    "01_released_zero_motion.png",
    "02_dynamic_motion.png",
    "03_split_successors.png"
)) {
    if (-not (Test-Path (Join-Path $OutputDir $required))) {
        Write-Error "Missing UI evidence frame $required"
    }
}
Write-Output "P1_UI_WINDOWS_CAPTURE_GATE_PASS"
