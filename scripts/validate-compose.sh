#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/.."

docker compose -f compose.yaml config --quiet
docker compose -f compose.yaml -f compose.debug.yaml config --quiet

printf '%s\n' 'Compose configuration is valid.'
