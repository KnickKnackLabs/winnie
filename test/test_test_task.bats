#!/usr/bin/env bats

load test_helper
bats_require_minimum_version 1.5.0

setup() {
  export WINNIE_CALLER_PWD="$BATS_TEST_TMPDIR/caller"
  PHYSICAL_REPO_DIR="$(cd "$REPO_DIR" && pwd -P)"

  MOCK_DIR="$BATS_TEST_TMPDIR/test-runner-bin"
  BATS_LOG="$BATS_TEST_TMPDIR/bats.log"
  mkdir -p "$MOCK_DIR" "$WINNIE_CALLER_PWD"
  export BATS_LOG

  cat > "$MOCK_DIR/bats" <<'SH'
#!/usr/bin/env bash
set -euo pipefail
{
  printf 'jobs=%s\n' "${BATS_NUMBER_OF_PARALLEL_JOBS:-}"
  printf 'runner=%s\n' "${BATS_PARALLEL_BINARY_NAME:-}"
  for argument in "$@"; do
    printf 'arg=%s\n' "$argument"
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

@test "test defaults to four Rush jobs and only top-level fast suites" {
  run winnie test

  [ "$status" -eq 0 ]
  [[ "$output" == *"4 jobs via"* ]]
  [ "$(log_value jobs)" = "4" ]
  [ "$(log_value runner)" = "$MOCK_DIR/rush" ]
  [ "$(arg_count --no-parallelize-within-files)" -eq 0 ]
  [ "$(arg_count "$PHYSICAL_REPO_DIR/test/test_iso_get.bats")" -eq 1 ]
  [ "$(arg_count "$REPO_DIR/test/integration/test_vm_input.bats")" -eq 0 ]
}

@test "test resolves an existing top-level suite name and preserves BATS options" {
  run winnie test iso_get --filter 'checksum mismatch'

  [ "$status" -eq 0 ]
  [ "$(arg_count "$PHYSICAL_REPO_DIR/test/test_iso_get.bats")" -eq 1 ]
  [ "$(arg_count --filter)" -eq 1 ]
  [ "$(arg_count 'checksum mismatch')" -eq 1 ]
}

@test "test keeps explicit integration paths opt-in" {
  run winnie test test/integration/test_vm_input.bats --filter screenshot

  [ "$status" -eq 0 ]
  [ "$(arg_count test/integration/test_vm_input.bats)" -eq 1 ]
  [ "$(arg_count "$REPO_DIR/test/test_iso_get.bats")" -eq 0 ]
}

@test "option values cannot suppress the whitespace transport fallback" {
  target="$BATS_TEST_TMPDIR/parallel target/fixture file.bats"
  mkdir -p "$(dirname "$target")"
  printf '%s
' '#!/usr/bin/env bats' > "$target"

  run winnie test "$target" --filter --no-parallelize-across-files
  [ "$status" -eq 0 ]
  [ "$(arg_count --no-parallelize-across-files)" -eq 2 ]
  [ "$(arg_count --no-parallelize-within-files)" -eq 0 ]
  [ "$(arg_count "$target")" -eq 1 ]
}

@test "explicit serial execution does not require Rush" {
  export RUSH_COMMAND="$MOCK_DIR/missing-rush"

  run winnie test --jobs 1 iso_get

  [ "$status" -eq 0 ]
  [[ "$output" == *"BATS parallelism: serial"* ]]
  [ "$(arg_count --jobs)" -eq 1 ]
  [ "$(arg_count 1)" -eq 1 ]
}

@test "parallel execution fails clearly without the selected runner" {
  export RUSH_COMMAND="$MOCK_DIR/missing-rush"

  run -127 winnie test iso_get

  [ "$status" -eq 127 ]
  [[ "$output" == *"parallel runner '$MOCK_DIR/missing-rush' is unavailable for 4 jobs"* ]]
  [ ! -e "$BATS_LOG" ]
}

@test "public Winnie test path runs tests within one BATS file concurrently" {
  local probe_dir="$BATS_TEST_TMPDIR/within-file-probe"
  local probe_suite="$probe_dir/within-file.bats"
  export PROBE_DIR="$BATS_TEST_TMPDIR/within-file-barrier"
  mkdir -p "$probe_dir" "$PROBE_DIR"

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
  } > "$probe_suite"

  unset BATS_COMMAND RUSH_COMMAND
  unset BATS_NUMBER_OF_PARALLEL_JOBS BATS_PARALLEL_BINARY_NAME

  run winnie test "$probe_suite"

  [ "$status" -eq 0 ]
  [[ "$output" == *"4 jobs via"* ]]
  [[ "$output" == *"1..2"* ]]
}
