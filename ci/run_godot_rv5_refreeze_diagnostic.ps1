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
    $env:P1_RV5_REFREEZE_DIAG_DIR = $output

    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @(
            "--path", ".",
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--rendering-driver", "d3d12",
            "--fixed-fps", "30",
            "--script", "res://tests/p1_rv5_refreeze_continuity_diagnostic.gd"
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
        Write-Error "Godot R-V5 refreeze diagnostic exited with status $($process.ExitCode)"
        exit 1
    }
    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|P1_RV5_REFREEZE_DIAGNOSTIC_FAIL') {
        Write-Error "R-V5 refreeze diagnostic emitted an engine/script/failure error despite process exit 0."
        exit 1
    }
    if (-not $content.Contains("P1_RV5_REFREEZE_DIAGNOSTIC_PASS")) {
        Write-Error "Expected R-V5 refreeze diagnostic PASS marker missing."
        exit 1
    }
    if (-not $content.Contains("P1_RV5_REFREEZE_TRANSITION") -or -not $content.Contains("P1_RV5_REFREEZE_STATE")) {
        Write-Error "R-V5 refreeze diagnostic state/transition metrics missing."
        exit 1
    }
    if (-not $content.Contains("D3D12") -or -not $content.Contains("Forward+")) {
        Write-Error "R-V5 refreeze diagnostic did not prove the expected D3D12 Forward+ path."
        exit 1
    }

    $required = @(
        "00_pre_freeze_dynamic_near.png",
        "01_post_freeze_commit.png",
        "02_post_freeze_01f_no_reset.png",
        "03_post_freeze_08f_no_reset.png",
        "04_post_freeze_90f_no_reset.png",
        "05_post_reset_01f.png",
        "06_post_reset_60f.png"
    )
    foreach ($file in $required) {
        $path = Join-Path $output $file
        if (-not (Test-Path -LiteralPath $path)) {
            Write-Error "R-V5 refreeze diagnostic evidence file missing: $path"
            exit 1
        }
    }

    Set-Content -Path (Join-Path $output "R-V5-REFREEZE-DIAGNOSTIC-LOG.txt") -Value $content
    Write-Host "P1_RV5_REFREEZE_DIAGNOSTIC_EVIDENCE_PASS path=$output"
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
