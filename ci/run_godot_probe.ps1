param(
    [Parameter(Mandatory = $true)][string]$ScriptPath,
    [Parameter(Mandatory = $true)][string]$PassMarker
)

$stdoutFile = [System.IO.Path]::GetTempFileName()
$stderrFile = [System.IO.Path]::GetTempFileName()

try {
    $godotCommand = Get-Command godot -ErrorAction Stop
    $godotExecutable = $godotCommand.Source
    if ([string]::IsNullOrWhiteSpace($godotExecutable)) {
        throw "Could not resolve Godot executable."
    }

    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @("--headless", "--path", ".", "--script", $ScriptPath) `
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
        Write-Error "Godot exited with status $($process.ExitCode)"
        exit 1
    }

    if ($content -match 'SCRIPT ERROR:|ERROR: Failed to load script|Parse Error:|Compile Error:|P1_[A-Z0-9_]+_(FAIL|TIMEOUT)') {
        Write-Error "Probe emitted a script/load/failure error despite process exit 0."
        exit 1
    }

    if (-not $content.Contains($PassMarker)) {
        Write-Error "Expected PASS marker missing: $PassMarker"
        exit 1
    }
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
