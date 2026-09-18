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
    $env:P1_CAMERA_EVIDENCE_DIR = $OutputDir

    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @(
            "--path", ".",
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--rendering-driver", "d3d12",
            "--script", "res://tests/p1_camera_visual_capture.gd"
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
        Write-Error "Godot G4 camera capture exited with status $($process.ExitCode)"
        exit 1
    }

    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|P1_CAMERA_CAPTURE_FAIL') {
        Write-Error "G4 camera capture emitted an engine/script/failure error despite process exit 0."
        exit 1
    }

    if (-not $content.Contains("P1_CAMERA_CAPTURE_PASS")) {
        Write-Error "Expected G4 camera PASS marker missing."
        exit 1
    }

    if (-not $content.Contains("D3D12") -or -not $content.Contains("Forward+")) {
        Write-Error "G4 Windows capture did not prove the expected D3D12 Forward+ path."
        exit 1
    }

    $required = @(
        "00_default_center.png",
        "01_actor_near_edge.png",
        "02_minimum_zoom_edge.png",
        "03_close_obstacle_compression.png",
        "04_far_airborne_context.png",
        "05_post_recovery.png",
        "06_dynamic_motion.png",
        "07_immediate_split.png",
        "08_post_split_context.png"
    )
    foreach ($file in $required) {
        $path = Join-Path $OutputDir $file
        if (-not (Test-Path $path)) {
            Write-Error "G4 rendered evidence file missing: $path"
            exit 1
        }
    }
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
