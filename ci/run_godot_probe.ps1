param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][string]$PassMarker
)

$logFile = New-TemporaryFile
& godot --headless --path . --script $ScriptPath 2>&1 | Tee-Object -FilePath $logFile
$godotStatus = $LASTEXITCODE
$content = Get-Content -Path $logFile -Raw

if ($godotStatus -ne 0) {
    Write-Error "Godot exited with status $godotStatus"
    exit 1
}

if ($content -match 'SCRIPT ERROR:|ERROR: Failed to load script|P1_[A-Z0-9_]+_(FAIL|TIMEOUT)') {
    Write-Error "Probe emitted a script/load/failure error despite process exit 0."
    exit 1
}

if (-not $content.Contains($PassMarker)) {
    Write-Error "Expected PASS marker missing: $PassMarker"
    exit 1
}
