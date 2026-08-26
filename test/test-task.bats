#!/usr/bin/env bats

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  MOCK_DIR="$BATS_TEST_TMPDIR/mock-bin"
  BATS_LOG="$BATS_TEST_TMPDIR/bats.log"
  mkdir -p "$MOCK_DIR"
  export BATS_LOG

  cat > "$MOCK_DIR/bats" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'jobs=%s\n' "${BATS_NUMBER_OF_PARALLEL_JOBS:-}"
  printf 'runner=%s\n' "${BATS_PARALLEL_BINARY_NAME:-}"
  for arg in "$@"; do
    printf 'arg=%s\n' "$arg"
  done
} > "$BATS_LOG"
SH

  cat > "$MOCK_DIR/rush" <<'SH'
#!/usr/bin/env bash
exit 0
SH

  chmod +x "$MOCK_DIR/bats" "$MOCK_DIR/rush"

  export BATS_COMMAND="$MOCK_DIR/bats"
  export RUSH_COMMAND="$MOCK_DIR/rush"
  unset BATS_NUMBER_OF_PARALLEL_JOBS BATS_PARALLEL_BINARY_NAME
}

log_value() {
  local key="$1"
  awk -F= -v key="$key" '$1 == key { print substr($0, length(key) + 2); exit }' "$BATS_LOG"
}

arg_count() {
  local expected="$1"
  awk -F= -v expected="$expected" '$1 == "arg" && substr($0, 5) == expected { count++ } END { print count + 0 }' "$BATS_LOG"
}

logged_arguments() {
  sed -n 's/^arg=//p' "$BATS_LOG"
}

@test "test task defaults to four Rush jobs without transport overrides" {
  run template test skeleton --filter doctor
  [ "$status" -eq 0 ]
  [[ "$output" == *"4 jobs via"* ]]
  [ "$(log_value jobs)" = "4" ]
  [ "$(log_value runner)" = "$MOCK_DIR/rush" ]
  [ "$(arg_count --no-parallelize-across-files)" -eq 0 ]
  [ "$(arg_count --no-parallelize-within-files)" -eq 0 ]
  [ "$(arg_count "$REPO_DIR/test/skeleton.bats")" -eq 1 ]
  [ "$(arg_count --filter)" -eq 1 ]
  [ "$(arg_count doctor)" -eq 1 ]
}

@test "explicit jobs override is forwarded once" {
  run template test --jobs 3 skeleton
  [ "$status" -eq 0 ]
  [[ "$output" == *"3 jobs via"* ]]
  [ "$(log_value jobs)" = "" ]
  [ "$(arg_count --jobs)" -eq 1 ]
  [ "$(arg_count 3)" -eq 1 ]
  [ "$(arg_count --no-parallelize-within-files)" -eq 0 ]
}

@test "environment jobs override the detected default" {
  export BATS_NUMBER_OF_PARALLEL_JOBS=2

  run template test skeleton
  [ "$status" -eq 0 ]
  [[ "$output" == *"2 jobs via"* ]]
  [ "$(log_value jobs)" = "2" ]
  [ "$(arg_count --jobs)" -eq 0 ]
}

@test "environment serial opt-out does not require Rush" {
  export BATS_NUMBER_OF_PARALLEL_JOBS=1
  export RUSH_COMMAND="$MOCK_DIR/missing-rush"

  run template test skeleton
  [ "$status" -eq 0 ]
  [[ "$output" == *"BATS parallelism: serial"* ]]
  [ "$(arg_count --no-parallelize-within-files)" -eq 0 ]
}

@test "option values that resemble parallel flags remain option values" {
  target="$BATS_TEST_TMPDIR/parallel target/fixture file.bats"
  mkdir -p "$(dirname "$target")"
  printf '%s
' '#!/usr/bin/env bats' > "$target"

  run template test "$target" --filter --no-parallelize-across-files
  [ "$status" -eq 0 ]
  [ "$(arg_count --no-parallelize-across-files)" -eq 1 ]
  [ "$(arg_count --no-parallelize-within-files)" -eq 0 ]
  [ "$(arg_count "$target")" -eq 1 ]
}

@test "CLI serial opt-out does not require Rush" {
  export RUSH_COMMAND="$MOCK_DIR/missing-rush"

  run template test --jobs 1 skeleton
  [ "$status" -eq 0 ]
  [[ "$output" == *"BATS parallelism: serial"* ]]
  [ "$(arg_count --no-parallelize-within-files)" -eq 0 ]
}

@test "parallel execution fails clearly when the selected runner is unavailable" {
  export RUSH_COMMAND="$MOCK_DIR/missing-rush"

  run -127 template test skeleton
  [ "$status" -eq 127 ]
  [[ "$output" == *"parallel runner '$MOCK_DIR/missing-rush' is unavailable for 4 jobs"* ]]
  [[ "$output" == *"run 'mise install' or use --jobs 1"* ]]
  [ ! -e "$BATS_LOG" ]
}

@test "environment runner override is preserved" {
  cp "$MOCK_DIR/rush" "$MOCK_DIR/alternate-runner"
  export BATS_PARALLEL_BINARY_NAME="$MOCK_DIR/alternate-runner"

  run template test skeleton
  [ "$status" -eq 0 ]
  [ "$(log_value runner)" = "$MOCK_DIR/alternate-runner" ]
}

@test "CLI runner override is preserved" {
  cp "$MOCK_DIR/rush" "$MOCK_DIR/alternate-runner"

  run template test --parallel-binary-name "$MOCK_DIR/alternate-runner" skeleton
  [ "$status" -eq 0 ]
  [ "$(arg_count --parallel-binary-name)" -eq 1 ]
  [ "$(arg_count "$MOCK_DIR/alternate-runner")" -eq 1 ]
}

@test "invalid job override fails before BATS" {
  export BATS_NUMBER_OF_PARALLEL_JOBS=lots

  run template test skeleton
  [ "$status" -eq 2 ]
  [[ "$output" == *"must be a positive integer"* ]]
  [ ! -e "$BATS_LOG" ]
}

@test "missing job override fails before BATS" {
  run template test --jobs
  [ "$status" -eq 2 ]
  [[ "$output" == *"--jobs requires a positive integer"* ]]
  [ ! -e "$BATS_LOG" ]
}

@test "filter values that resemble parallel flags remain filter values" {
  run template test --filter --jobs skeleton
  [ "$status" -eq 0 ]
  [[ "$output" == *"4 jobs via"* ]]
  [ "$(logged_arguments)" = "$(printf '%s\n' \
    --print-output-on-failure \
    --filter \
    --jobs \
    "$REPO_DIR/test/skeleton.bats")" ]
}

@test "filter values that match suite names are not resolved as targets" {
  run template test --filter skeleton test-task
  [ "$status" -eq 0 ]
  [ "$(logged_arguments)" = "$(printf '%s\n' \
    --print-output-on-failure \
    --filter \
    skeleton \
    "$REPO_DIR/test/test-task.bats")" ]
}

@test "canonical task runs separate BATS files concurrently" {
  probe_dir="$BATS_TEST_TMPDIR/parallel-probe"
  barrier_dir="$BATS_TEST_TMPDIR/barrier"
  mkdir -p "$probe_dir" "$barrier_dir"

  test_keyword='@test'
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"first worker observes second worker\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/one"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/two" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/one.bats"

  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"second worker observes first worker\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/two"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/one" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/two.bats"

  export PROBE_DIR="$barrier_dir"
  run template_isolated test "$probe_dir"

  [ "$status" -eq 0 ]
  [[ "$output" == *"jobs via"* ]]
}

@test "canonical task runs tests within one BATS file concurrently" {
  probe_dir="$BATS_TEST_TMPDIR/within-file-probe"
  barrier_dir="$BATS_TEST_TMPDIR/within-file-barrier"
  mkdir -p "$probe_dir" "$barrier_dir"

  test_keyword='@test'
  {
    printf '%s\n' '#!/usr/bin/env bats'
    printf '%s\n' "$test_keyword \"first test observes second test\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/one"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/two" ] || return 0
    sleep 0.05
  done
  false
}
BATS
    printf '%s\n' "$test_keyword \"second test observes first test\" {"
    cat <<'BATS'
  touch "$PROBE_DIR/two"
  for _ in {1..50}; do
    [ ! -e "$PROBE_DIR/one" ] || return 0
    sleep 0.05
  done
  false
}
BATS
  } > "$probe_dir/within-file.bats"

  export PROBE_DIR="$barrier_dir"
  run template_isolated test "$probe_dir"

  [ "$status" -eq 0 ]
  [[ "$output" == *"jobs via"* ]]
}
