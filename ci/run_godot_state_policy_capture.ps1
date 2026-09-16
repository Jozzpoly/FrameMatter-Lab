param(
    [Parameter(Mandatory = $true)][string]$OutputDir,
    [Parameter(Mandatory = $true)][ValidateSet("current_contour", "top_crown")][string]$Variant
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
    $env:P1_STATE_POLICY_EVIDENCE_DIR = $OutputDir
    $env:P1_STATE_POLICY_VARIANT = $Variant

    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @(
            "--path", ".",
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--rendering-driver", "d3d12",
            "--script", "res://tests/p1_state_policy_visual_capture.gd"
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
        Write-Error "Godot state-policy capture exited with status $($process.ExitCode)"
        exit 1
    }
    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|P1_STATE_POLICY_CAPTURE_FAIL') {
        Write-Error "State-policy capture emitted an engine/script/failure error despite process exit 0."
        exit 1
    }
    if (-not $content.Contains("P1_STATE_POLICY_CAPTURE_PASS")) {
        Write-Error "Expected state-policy PASS marker missing."
        exit 1
    }
    if (-not $content.Contains("D3D12") -or -not $content.Contains("Forward+")) {
        Write-Error "State-policy capture did not prove the expected D3D12 Forward+ path."
        exit 1
    }

    $required = @(
        "00_static_focused.png",
        "01_dynamic_focused.png",
        "02_split_two_dynamic.png",
        "03_mixed_static_dynamic.png",
        "04_mixed_low_angle.png"
    )
    foreach ($file in $required) {
        $path = Join-Path $OutputDir $file
        if (-not (Test-Path $path)) {
            Write-Error "State-policy evidence file missing: $path"
            exit 1
        }
    }
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
