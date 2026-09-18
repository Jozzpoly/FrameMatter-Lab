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
    $env:P1_CROSS_LAYER_EVIDENCE_DIR = $OutputDir

    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @(
            "--path", ".",
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--rendering-driver", "d3d12",
            "--script", "res://tests/p1_cross_layer_rehearsal_capture.gd"
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
        Write-Error "Godot cross-layer rehearsal exited with status $($process.ExitCode)"
        exit 1
    }

    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|P1_CROSS_LAYER_REHEARSAL_FAIL') {
        Write-Error "Cross-layer rehearsal emitted an engine/script/failure error despite process exit 0."
        exit 1
    }

    if (-not $content.Contains("P1_CROSS_LAYER_REHEARSAL_PASS")) {
        Write-Error "Expected cross-layer PASS marker missing."
        exit 1
    }

    if (-not $content.Contains("D3D12") -or -not $content.Contains("Forward+")) {
        Write-Error "Cross-layer rehearsal did not prove the expected D3D12 Forward+ path."
        exit 1
    }

    $required = @(
        "00_default_static.png",
        "01_pointer_remove_target.png",
        "02_remove_success_feedback.png",
        "03_released_zero_motion.png",
        "04_dynamic_finite_motion.png",
        "05_moving_edit_before_rebase.png",
        "06_post_rebase_mapped_place.png",
        "07_split_immediate.png",
        "08_split_independent_sibling.png",
        "09_frozen_actor_successor_dynamic_sibling.png"
    )
    foreach ($file in $required) {
        $path = Join-Path $OutputDir $file
        if (-not (Test-Path $path)) {
            Write-Error "Cross-layer rendered evidence file missing: $path"
            exit 1
        }
    }
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
