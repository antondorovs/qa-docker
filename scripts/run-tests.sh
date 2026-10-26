#!/usr/bin/env sh

set -eu

cd "$(dirname "$0")/.."

cleanup() {
  test_exit_code=$?
  trap - EXIT
  set +e
  docker compose down --remove-orphans
  cleanup_exit_code=$?

  if [ "$test_exit_code" -ne 0 ]; then
    exit "$test_exit_code"
  fi

  exit "$cleanup_exit_code"
}

trap cleanup EXIT

docker compose up --build --abort-on-container-exit --exit-code-from tests
