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
    $output = (Resolve-Path -LiteralPath $OutputDir).Path
    $env:P1_RV5_EVIDENCE_DIR = $output
    $moviePath = Join-Path $output "p1-rv5-full-history-diagnostic.avi"

    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @(
            "--path", ".",
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--rendering-driver", "d3d12",
            "--write-movie", $moviePath,
            "--fixed-fps", "30",
            "--script", "res://tests/p1_rv5_full_history_diagnostic.gd"
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
        Write-Error "Godot R-V5 full-history diagnostic exited with status $($process.ExitCode)"
        exit 1
    }
    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|P1_RV5_CHAOTIC_OWNER_SURFACE_FAIL') {
        Write-Error "R-V5 full-history diagnostic emitted an engine/script/failure error despite process exit 0."
        exit 1
    }
    if (-not $content.Contains("P1_RV5_CHAOTIC_OWNER_SURFACE_PASS")) {
        Write-Error "Expected inherited R-V5 mechanical PASS marker missing."
        exit 1
    }
    foreach ($label in @("07_dynamic_irregular_motion", "08_dynamic_irregular_near", "09_refrozen_irregular_final")) {
        if (-not $content.Contains("P1_RV5_FULL_HISTORY_STATE label=$label")) {
            Write-Error "R-V5 full-history telemetry missing checkpoint: $label"
            exit 1
        }
    }
    if (-not $content.Contains("D3D12") -or -not $content.Contains("Forward+")) {
        Write-Error "R-V5 full-history diagnostic did not prove the expected D3D12 Forward+ path."
        exit 1
    }

    $required = @(
        "00_start_static.png",
        "01_chaos_after_08_removes.png",
        "02_chaos_after_16_edits.png",
        "03_chaos_26_near.png",
        "04_chaos_remove_target.png",
        "05_chaos_place_target.png",
        "06_chaos_mid_composed.png",
        "07_dynamic_irregular_motion.png",
        "08_dynamic_irregular_near.png",
        "09_refrozen_irregular_final.png"
    )
    foreach ($file in $required) {
        $path = Join-Path $output $file
        if (-not (Test-Path -LiteralPath $path)) {
            Write-Error "R-V5 full-history rendered evidence file missing: $path"
            exit 1
        }
    }

    if (-not (Test-Path -LiteralPath $moviePath)) {
        Write-Error "R-V5 full-history diagnostic movie missing: $moviePath"
        exit 1
    }
    Set-Content -Path (Join-Path $output "R-V5-FULL-HISTORY-DIAGNOSTIC-LOG.txt") -Value $content
    Write-Host "P1_RV5_FULL_HISTORY_DIAGNOSTIC_PASS path=$output movie=$moviePath"
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
