$stdoutFile = [System.IO.Path]::GetTempFileName()
$stderrFile = [System.IO.Path]::GetTempFileName()

try {
    $godotCommand = Get-Command godot -ErrorAction Stop
    $godotExecutable = $godotCommand.Source
    if ([string]::IsNullOrWhiteSpace($godotExecutable)) {
        throw "Could not resolve Godot executable."
    }

    # The Windows Godot editor binary is a GUI-subsystem executable. Running it
    # directly from PowerShell is not a reliable synchronization boundary for
    # the follow-up process. Explicitly wait until the editor/import process has
    # completed so global_script_class_cache.cfg is fully materialized.
    $process = Start-Process `
        -FilePath $godotExecutable `
        -ArgumentList @("--headless", "--path", ".", "--editor", "--quit") `
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
        Write-Error "Godot import exited with status $($process.ExitCode)"
        exit 1
    }

    if ($content -match '(?m)^ERROR:|SCRIPT ERROR:|Parse Error:|Compile Error:') {
        Write-Error "Godot import emitted an engine/script/compile error."
        exit 1
    }

    $classCache = Join-Path ".godot" "global_script_class_cache.cfg"
    if (-not (Test-Path -LiteralPath $classCache)) {
        Write-Error "Godot import completed without global script class cache: $classCache"
        exit 1
    }

    $cacheContent = Get-Content -LiteralPath $classCache -Raw
    foreach ($requiredClass in @("CellVolume", "LocalMatterSpace", "SpaceQueryCharacter", "P1CameraRig", "P1SpaceRegistry", "P1MatterInteractor", "P1SpaceControl")) {
        if (-not $cacheContent.Contains($requiredClass)) {
            Write-Error "Godot global class cache is incomplete; missing $requiredClass"
            exit 1
        }
    }

    Write-Host "GODOT_WINDOWS_IMPORT_GATE_PASS"
}
finally {
    Remove-Item -Path $stdoutFile, $stderrFile -Force -ErrorAction SilentlyContinue
}
