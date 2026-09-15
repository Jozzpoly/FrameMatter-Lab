param(
    [Parameter(Mandatory = $true)][string]$RuntimePath,
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

    $runtime = (Resolve-Path -LiteralPath $RuntimePath).Path
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    $output = (Resolve-Path -LiteralPath $OutputDir).Path
    $env:P1_G8_EVIDENCE_DIR = $output
    $moviePath = Join-Path $output "p1-g8-adversarial-rehearsal.avi"

    $process = Start-Process `
        -FilePath $godotExecutable `
        -WorkingDirectory $runtime `
        -ArgumentList @(
            "--path", $runtime,
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--rendering-driver", "d3d12",
            "--write-movie", $moviePath,
            "--fixed-fps", "60",
            "--script", "res://tests/p1_g8_adversarial_rehearsal_capture.gd"
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
        Write-Error "Godot G8 adversarial rehearsal exited with status $($process.ExitCode)"
        exit 1
    }

    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|P1_G8_ADVERSARIAL_REHEARSAL_FAIL') {
        Write-Error "G8 rehearsal emitted an engine/script/failure error despite process exit 0."
        exit 1
    }

    if (-not $content.Contains("P1_G8_ADVERSARIAL_REHEARSAL_PASS")) {
        Write-Error "Expected G8 PASS marker missing."
        exit 1
    }

    if (-not $content.Contains("D3D12") -or -not $content.Contains("Forward+")) {
        Write-Error "G8 rehearsal did not prove the expected D3D12 Forward+ path."
        exit 1
    }

    $required = @(
        "00_start_static.png",
        "01_close_matter_camera_stress.png",
        "02_close_camera_after_rapid_edit_burst.png",
        "03_zero_launch_release_after_stress.png",
        "04_finite_motion_after_camera_edit_stress.png",
        "05_moving_edge_edit_pressure.png",
        "06_post_rebase_under_motion.png",
        "07_immediate_split_after_rebase_motion.png",
        "08_independent_successors_under_motion.png",
        "09_frozen_actor_successor_dynamic_sibling.png",
        "10_far_airborne_before_automatic_recovery.png",
        "11_post_automatic_fall_recovery.png"
    )
    foreach ($file in $required) {
        $path = Join-Path $output $file
        if (-not (Test-Path -LiteralPath $path)) {
            Write-Error "G8 rendered evidence file missing: $path"
            exit 1
        }
    }

    if (-not (Test-Path -LiteralPath $moviePath)) {
        Write-Error "G8 continuous movie evidence missing: $moviePath"
        exit 1
    }
    $movie = Get-Item -LiteralPath $moviePath
    if ($movie.Length -lt 1024) {
        Write-Error "G8 continuous movie evidence is unexpectedly small: $($movie.Length) bytes"
        exit 1
    }
    Write-Host "P1_G8_MOVIE_PASS path=$moviePath bytes=$($movie.Length)"
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
