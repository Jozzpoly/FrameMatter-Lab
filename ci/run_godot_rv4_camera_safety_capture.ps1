param(
    [Parameter(Mandatory = $true)][string]$OutputDir,
    [Parameter(Mandatory = $true)][ValidateSet("baseline", "near_hide", "overhead_escape", "production")][string]$Variant
)

$stdoutFile = [System.IO.Path]::GetTempFileName()
$stderrFile = [System.IO.Path]::GetTempFileName()

try {
    $godotCommand = Get-Command godot -ErrorAction Stop
    $godotExecutable = $godotCommand.Source
    if ([string]::IsNullOrWhiteSpace($godotExecutable)) {
        throw "Could not resolve Godot executable."
    }

    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    $env:P1_RV4_CAMERA_SAFETY_EVIDENCE_DIR = $OutputDir
    $env:P1_RV4_CAMERA_SAFETY_VARIANT = $Variant

    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @(
            "--path", ".",
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--rendering-driver", "d3d12",
            "--script", "res://tests/p1_rv4_camera_visual_safety_capture.gd"
        ) `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $stdoutFile `
        -RedirectStandardError $stderrFile

    $stdout = Get-Content -Path $stdoutFile -Raw -ErrorAction SilentlyContinue
    $stderr = Get-Content -Path $stderrFile -Raw -ErrorAction SilentlyContinue
    $content = ($stdout + [Environment]::NewLine + $stderr)
    Write-Host $content

    if ($process.ExitCode -ne 0) {
        Write-Error "Godot R-V4 camera-safety capture exited with status $($process.ExitCode)"
        exit 1
    }
    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|P1_RV4_CAMERA_SAFETY_FAIL') {
        Write-Error "R-V4 camera-safety capture emitted an engine/script/failure error despite process exit 0."
        exit 1
    }

    $expectedMarker = switch ($Variant) {
        "baseline" { "P1_RV4_BASELINE_REPRODUCED" }
        "near_hide" { "P1_RV4_NEAR_HIDE_CHALLENGER_PASS" }
        "overhead_escape" { "P1_RV4_OVERHEAD_ESCAPE_CHALLENGER_PASS" }
        "production" { "P1_RV4_PRODUCTION_POLICY_PASS" }
    }
    if (-not $content.Contains($expectedMarker)) {
        Write-Error "Expected R-V4 marker missing for variant $Variant`: $expectedMarker"
        exit 1
    }
    if (-not $content.Contains("D3D12") -or -not $content.Contains("Forward+")) {
        Write-Error "R-V4 capture did not prove the expected D3D12 Forward+ path."
        exit 1
    }

    $required = @("00_open_reference.png", "01_tight_matter_enclosure.png")
    if ($Variant -eq "production") {
        $required += "02_post_obstruction_recovery.png"
    }
    foreach ($file in $required) {
        $path = Join-Path $OutputDir $file
        if (-not (Test-Path $path)) {
            Write-Error "R-V4 rendered evidence file missing: $path"
            exit 1
        }
    }
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
