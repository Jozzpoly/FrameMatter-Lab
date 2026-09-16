param(
    [Parameter(Mandatory = $true)][string]$OutputDir
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
    $env:P1_WORLD_CAUSALITY_EVIDENCE_DIR = $OutputDir

    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @(
            "--path", ".",
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--rendering-driver", "d3d12",
            "--script", "res://tests/p1_world_causality_visual_capture.gd"
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
        Write-Error "Godot G6 world-causality capture exited with status $($process.ExitCode)"
        exit 1
    }

    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|P1_WORLD_CAUSALITY_CAPTURE_FAIL') {
        Write-Error "G6 world-causality capture emitted an engine/script/failure error despite process exit 0."
        exit 1
    }

    if (-not $content.Contains("P1_WORLD_CAUSALITY_CAPTURE_PASS")) {
        Write-Error "Expected G6 world-causality PASS marker missing."
        exit 1
    }

    if (-not $content.Contains("D3D12") -or -not $content.Contains("Forward+")) {
        Write-Error "G6 Windows capture did not prove the expected D3D12 Forward+ path."
        exit 1
    }

    $required = @(
        "00_static.png",
        "01_released_zero_motion.png",
        "02_motion_start.png",
        "03_motion_mid.png",
        "04_motion_late.png",
        "05_split_immediate.png",
        "06_split_independent_motion.png",
        "07_pre_freeze_dynamic.png",
        "08_post_freeze_same_pose.png",
        "09_frozen_vs_dynamic_sibling.png"
    )
    foreach ($file in $required) {
        $path = Join-Path $OutputDir $file
        if (-not (Test-Path $path)) {
            Write-Error "G6 rendered evidence file missing: $path"
            exit 1
        }
    }
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
