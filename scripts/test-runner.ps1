$ErrorActionPreference = 'Stop'

$projectDirectory = Split-Path -Parent $PSScriptRoot
$powerShell = (Get-Process -Id $PID).Path
$testDirectory = Join-Path ([IO.Path]::GetTempPath()) ('runner checks ' + [Guid]::NewGuid())
$originalEnvironment = @{}

foreach ($name in @('PATH', 'UP_EXIT', 'DOWN_EXIT', 'CALL_LOG')) {
    $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}

New-Item -ItemType Directory -Path $testDirectory | Out-Null

try {
    @'
@echo off
echo(%CD%^|%*>>"%CALL_LOG%"
if "%1 %2"=="compose up" exit /b %UP_EXIT%
if "%1 %2"=="compose down" exit /b %DOWN_EXIT%
exit /b 99
'@ | Set-Content -LiteralPath (Join-Path $testDirectory 'docker.cmd') -Encoding Ascii

    $env:PATH = $testDirectory + [IO.Path]::PathSeparator + $env:PATH
    $env:CALL_LOG = Join-Path $testDirectory 'calls'

    foreach ($case in @(
        @{ Up = 0; Down = 0; Expected = 0 },
        @{ Up = 7; Down = 0; Expected = 7 },
        @{ Up = 0; Down = 9; Expected = 9 },
        @{ Up = 7; Down = 9; Expected = 7 }
    )) {
        $env:UP_EXIT = [string]$case.Up
        $env:DOWN_EXIT = [string]$case.Down
        Set-Content -LiteralPath $env:CALL_LOG -Value '' -NoNewline

        Push-Location -LiteralPath $testDirectory
        try {
            & $powerShell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $projectDirectory 'scripts/run-tests.ps1')
            $actualExit = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        if ($actualExit -ne $case.Expected) {
            throw "up=$($case.Up) down=$($case.Down): expected exit $($case.Expected), got $actualExit"
        }

        $expectedCalls = @(
            "$projectDirectory|compose up --build --abort-on-container-exit --exit-code-from tests",
            "$projectDirectory|compose down --remove-orphans"
        )
        $actualCalls = @(Get-Content -LiteralPath $env:CALL_LOG)
        if (($actualCalls -join "`n") -cne ($expectedCalls -join "`n")) {
            throw "Unexpected Docker commands or working directory: $($actualCalls -join '; ')"
        }
    }

    Write-Output 'PowerShell runner exit codes, cleanup, and project directory checks passed.'
}
finally {
    foreach ($name in $originalEnvironment.Keys) {
        [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], 'Process')
    }
    foreach ($name in @('docker.cmd', 'calls')) {
        $path = Join-Path $testDirectory $name
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path
        }
    }
    Remove-Item -LiteralPath $testDirectory
}
