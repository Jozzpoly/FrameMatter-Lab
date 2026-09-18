param(
    [Parameter(Mandatory = $true)][string]$OutputDir
)

$stdoutFile = [System.IO.Path]::GetTempFileName()
$stderrFile = [System.IO.Path]::GetTempFileName()

try {
    $godotExecutable = (Get-Command godot -ErrorAction Stop).Source
    New-Item -ItemType Directory -Force -Path $OutputDir | Out-Null
    $env:C6_INTERACTION_EVIDENCE_DIR = $OutputDir

    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @(
            "--path", ".",
            "--audio-driver", "Dummy",
            "--rendering-method", "forward_plus",
            "--rendering-driver", "d3d12",
            "--script", "res://tests/c6_pointer_input_capture.gd"
        ) `
        -NoNewWindow `
        -Wait `
        -PassThru `
        -RedirectStandardOutput $stdoutFile `
        -RedirectStandardError $stderrFile

    $stdout = Get-Content -Path $stdoutFile -Raw -ErrorAction SilentlyContinue
    $stderr = Get-Content -Path $stderrFile -Raw -ErrorAction SilentlyContinue
    $content = $stdout + [Environment]::NewLine + $stderr
    Write-Host $content

    if ($process.ExitCode -ne 0) { throw "C6 rendered pointer qualification exited with status $($process.ExitCode)" }
    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:|C6_POINTER_INPUT_FAIL') {
        throw "C6 rendered pointer qualification emitted an engine/script/failure error"
    }
    if (-not $content.Contains("C6_POINTER_INPUT_PASS")) { throw "C6 pointer PASS marker missing" }
    if (-not $content.Contains("D3D12") -or -not $content.Contains("Forward+")) {
        throw "C6 pointer qualification did not prove D3D12 Forward+ rendering"
    }
    foreach ($name in @("00_structural_seam_target.png", "01_structural_relation_live.png")) {
        if (-not (Test-Path (Join-Path $OutputDir $name))) {
            throw "C6 rendered evidence missing: $name"
        }
    }
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
