#!/usr/bin/env sh

set -eu

project_dir=$(CDPATH= cd "$(dirname "$0")/.." && pwd)
test_dir=$(mktemp -d)

cleanup() {
  rm -f "$test_dir/docker" "$test_dir/calls" "$test_dir/expected"
  rmdir "$test_dir"
}

trap cleanup EXIT

cat > "$test_dir/docker" <<'EOF'
#!/usr/bin/env sh
printf '%s|%s\n' "$PWD" "$*" >> "$CALL_LOG"
case "$1 $2" in
  'compose up') sleep "${UP_WAIT:-0}"; exit "$UP_EXIT" ;;
  'compose down') exit "$DOWN_EXIT" ;;
  *) exit 99 ;;
esac
EOF
chmod +x "$test_dir/docker"

check_exit() {
  up_exit=$1
  down_exit=$2
  expected_exit=$3
  : > "$test_dir/calls"

  if (
    cd "$test_dir"
    PATH="$test_dir:$PATH" UP_EXIT="$up_exit" DOWN_EXIT="$down_exit" \
      CALL_LOG="$test_dir/calls" sh "$project_dir/scripts/run-tests.sh"
  ); then
    actual_exit=0
  else
    actual_exit=$?
  fi

  if [ "$actual_exit" -ne "$expected_exit" ]; then
    printf 'up=%s down=%s: expected exit %s, got %s\n' \
      "$up_exit" "$down_exit" "$expected_exit" "$actual_exit" >&2
    exit 1
  fi

  printf '%s|%s\n' \
    "$project_dir" 'compose up --build --abort-on-container-exit --exit-code-from tests' \
    "$project_dir" 'compose down --remove-orphans' > "$test_dir/expected"
  cmp "$test_dir/expected" "$test_dir/calls"
}

check_exit 0 0 0
check_exit 7 0 7
check_exit 0 9 9
check_exit 7 9 7

printf '%s\n' 'Runner exit codes, cleanup, and project directory checks passed.'

check_term() {
  : > "$test_dir/calls"
  PATH="$test_dir:$PATH" UP_EXIT=0 DOWN_EXIT="$1" UP_WAIT=3 \
    CALL_LOG="$test_dir/calls" sh "$project_dir/scripts/run-tests.sh" &
  runner_pid=$!

  attempts=0
  while [ ! -s "$test_dir/calls" ]; do
    attempts=$((attempts + 1))
    if [ "$attempts" -ge 10 ]; then
      kill -TERM "$runner_pid" 2>/dev/null || :
      wait "$runner_pid" 2>/dev/null || :
      printf '%s\n' 'Runner did not start its Docker command.' >&2
      exit 1
    fi
    sleep 1
  done

  kill -TERM "$runner_pid"
  if wait "$runner_pid"; then
    actual_exit=0
  else
    actual_exit=$?
  fi
  if [ "$actual_exit" -ne 143 ]; then
    printf 'SIGTERM: expected exit 143, got %s\n' "$actual_exit" >&2
    exit 1
  fi
  cmp "$test_dir/expected" "$test_dir/calls"
}

case "$(uname -s)" in
  Linux)
    check_term 0
    check_term 9
    printf '%s\n' 'SIGTERM cleanup and exit-code checks passed.'
    ;;
  *) printf '%s\n' 'SIGTERM checks require Linux; ordinary exit-code checks passed.' ;;
esac
