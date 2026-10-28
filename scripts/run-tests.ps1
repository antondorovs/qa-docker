$testExitCode = 0

# Handle Docker exit codes explicitly, including when the caller enables native errors.
$PSNativeCommandUseErrorActionPreference = $false

Push-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)

try {
    docker compose up --build --abort-on-container-exit --exit-code-from tests
    $testExitCode = $LASTEXITCODE
}
finally {
    try {
        docker compose down --remove-orphans

        if ($testExitCode -eq 0 -and $LASTEXITCODE -ne 0) {
            $testExitCode = $LASTEXITCODE
        }
    }
    finally {
        Pop-Location
    }
}

exit $testExitCode
