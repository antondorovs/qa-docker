$ErrorActionPreference = "Stop"

Push-Location -LiteralPath (Split-Path -Parent $PSScriptRoot)

try {
    docker compose -f compose.yaml config --quiet
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    docker compose -f compose.yaml -f compose.debug.yaml config --quiet
    if ($LASTEXITCODE -ne 0) {
        exit $LASTEXITCODE
    }

    Write-Output "Compose configuration is valid."
}
finally {
    Pop-Location
}
