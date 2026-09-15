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
    $env:P1_INTERACTION_EVIDENCE_DIR = $OutputDir

    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @(
            "--path", ".",
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--rendering-driver", "d3d12",
            "--script", "res://tests/p1_interaction_visual_capture.gd"
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
        Write-Error "Godot G5 interaction capture exited with status $($process.ExitCode)"
        exit 1
    }

    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|P1_INTERACTION_CAPTURE_FAIL') {
        Write-Error "G5 interaction capture emitted an engine/script/failure error despite process exit 0."
        exit 1
    }

    if (-not $content.Contains("P1_INTERACTION_CAPTURE_PASS")) {
        Write-Error "Expected G5 interaction PASS marker missing."
        exit 1
    }

    if (-not $content.Contains("D3D12") -or -not $content.Contains("Forward+")) {
        Write-Error "G5 Windows capture did not prove the expected D3D12 Forward+ path."
        exit 1
    }

    $required = @(
        "00_remove_target.png",
        "01_place_target.png",
        "02_expand_center_reticle_miss.png",
        "03_expand_pointer_hit.png"
    )
    foreach ($file in $required) {
        $path = Join-Path $OutputDir $file
        if (-not (Test-Path $path)) {
            Write-Error "G5 rendered evidence file missing: $path"
            exit 1
        }
    }
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
