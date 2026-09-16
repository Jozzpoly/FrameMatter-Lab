param(
    [Parameter(Mandatory = $true)][string]$OutputDir,
    [Parameter(Mandatory = $true)][ValidateSet("base", "grid", "state", "grid_state")][string]$Variant
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
    $env:P1_PRESENTATION_STACK_EVIDENCE_DIR = $OutputDir
    $env:P1_PRESENTATION_STACK_VARIANT = $Variant

    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @(
            "--path", ".",
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--rendering-driver", "d3d12",
            "--script", "res://tests/p1_presentation_stack_forensics_capture.gd"
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
        Write-Error "Godot presentation-stack forensics exited with status $($process.ExitCode)"
        exit 1
    }
    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|P1_PRESENTATION_STACK_FORENSICS_FAIL') {
        Write-Error "Presentation-stack forensics emitted an engine/script/failure error despite process exit 0."
        exit 1
    }
    if (-not $content.Contains("P1_PRESENTATION_STACK_FORENSICS_PASS")) {
        Write-Error "Expected presentation-stack PASS marker missing."
        exit 1
    }
    if (-not $content.Contains("D3D12") -or -not $content.Contains("Forward+")) {
        Write-Error "Presentation-stack capture did not prove the expected D3D12 Forward+ path."
        exit 1
    }

    $required = @(
        "00_clean_mid.png",
        "01_clean_near.png",
        "02_chaos_near.png",
        "03_chaos_mid.png",
        "04_chaos_opposite.png"
    )
    foreach ($file in $required) {
        $path = Join-Path $OutputDir $file
        if (-not (Test-Path $path)) {
            Write-Error "Presentation-stack evidence file missing: $path"
            exit 1
        }
    }
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
