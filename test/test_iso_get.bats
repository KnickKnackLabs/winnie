#!/usr/bin/env bats

# Tests for iso:get — argument validation, dedup, checksum verification.
# Uses the mock-first overlay pattern for catalog mocks and env var injection for curl.

load test_helper

setup() {
  export ISO_DIR="$BATS_TEST_TMPDIR/isos"
  export WINNIE_ISO_DIR="$ISO_DIR"
  mkdir -p "$ISO_DIR"
}

# --- mock helpers ---

# Mock a catalog task to return canned JSON.
# Uses mise's task_config includes — later includes override earlier ones.
mock_catalog() {
  local distro="$1" json="$2"
  local mock_dir="$BATS_TEST_TMPDIR/mocks/.mise/tasks/catalog"
  mkdir -p "$mock_dir"
  cat > "$mock_dir/$distro" <<SCRIPT
#!/usr/bin/env bash
echo '$json'
SCRIPT
  chmod +x "$mock_dir/$distro"
}

# Build overlay mise.toml: real tasks first, then mocks
setup_overlay() {
  export OVERLAY="$BATS_TEST_TMPDIR/overlay"
  mkdir -p "$OVERLAY"
  cat > "$OVERLAY/mise.toml" <<EOF
[settings]
quiet = true

[tools]
usage = "latest"
gum = "latest"
jq = "latest"
coreutils = "latest"

[task_config]
includes = [
  "$REPO_DIR/.mise/tasks",
  "$BATS_TEST_TMPDIR/mocks/.mise/tasks",
]
EOF
  ln -sf "$REPO_DIR/lib" "$OVERLAY/lib"
  if ! git -C "$OVERLAY" init -q -b main 2>/dev/null; then :; fi
  mise trust "$OVERLAY/mise.toml" 2>/dev/null
}

# Mock curl via ${CURL:-curl} env var injection.
mock_curl() {
  local content="${1:-fake iso content}"
  local content_file="$BATS_TEST_TMPDIR/mock_curl_content"
  local mock_script="$BATS_TEST_TMPDIR/mock_curl"
  printf '%s' "$content" > "$content_file"
  cat > "$mock_script" <<'SCRIPT'
#!/usr/bin/env bash
CONTENT_FILE="${MOCK_CURL_CONTENT_FILE:?}"
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o) shift; cp "$CONTENT_FILE" "$1"; exit 0 ;;
    *) shift ;;
  esac
done
exit 1
SCRIPT
  chmod +x "$mock_script"
  export MOCK_CURL_CONTENT_FILE="$content_file"
  export CURL="$mock_script"
}

# Run iso:get through the overlay (needed for catalog mocking)
run_iso_get() {
  setup_overlay
  run env \
    WINNIE_ISO_DIR="$ISO_DIR" \
    WINNIE_TASK_ROOT="$OVERLAY" \
    CURL="${CURL:-curl}" \
    MOCK_CURL_CONTENT_FILE="${MOCK_CURL_CONTENT_FILE:-}" \
    mise -C "$OVERLAY" run -q iso:get -- "$@"
}

# --- argument validation ---

@test "iso:get rejects unsupported distro" {
  run_iso_get "arch"
  [ "$status" -ne 0 ]
  [[ "$output" == *"unsupported distro"* ]]
}

@test "iso:get requires --version in non-interactive mode" {
  mock_catalog "mint" '[{"version":"22","date":"2024-07-20","variants":["cinnamon","mate","xfce"]}]'
  run_iso_get "mint"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a terminal"* ]]
}

# --- dedup: skip if already downloaded and verified ---

@test "iso:get skips download if file exists with correct checksum" {
  local content="fake iso content"
  local sha256=$(printf '%s' "$content" | sha256sum | awk '{print $1}')

  printf '%s' "$content" > "$ISO_DIR/test.iso"

  mock_catalog "mint" "[{\"filename\":\"test.iso\",\"variant\":\"cinnamon\",\"url\":\"http://example.com/test.iso\",\"sha256\":\"$sha256\"}]"

  run_iso_get "mint" --version "22" --variant "cinnamon"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Already downloaded and verified"* ]]
}

@test "iso:get re-downloads if file exists with wrong checksum" {
  printf '%s' "corrupted content" > "$ISO_DIR/test.iso"

  local correct_content="correct iso content"
  local correct_sha=$(printf '%s' "$correct_content" | sha256sum | awk '{print $1}')

  mock_catalog "mint" "[{\"filename\":\"test.iso\",\"variant\":\"cinnamon\",\"url\":\"http://example.com/test.iso\",\"sha256\":\"$correct_sha\"}]"
  mock_curl "$correct_content"

  run_iso_get "mint" --version "22" --variant "cinnamon"
  [ "$status" -eq 0 ]
  [[ "$output" == *"wrong checksum"* ]]
  [[ "$output" == *"Verified"* ]]
}

# --- checksum verification ---

@test "iso:get verifies sha256 after download" {
  local content="verified iso content"
  local sha256=$(printf '%s' "$content" | sha256sum | awk '{print $1}')

  mock_catalog "mint" "[{\"filename\":\"verified.iso\",\"variant\":\"cinnamon\",\"url\":\"http://example.com/verified.iso\",\"sha256\":\"$sha256\"}]"
  mock_curl "$content"

  run_iso_get "mint" --version "22" --variant "cinnamon"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Verified"* ]]
  [ -f "$ISO_DIR/verified.iso" ]
}

@test "iso:get deletes file on checksum mismatch" {
  mock_catalog "mint" "[{\"filename\":\"bad.iso\",\"variant\":\"cinnamon\",\"url\":\"http://example.com/bad.iso\",\"sha256\":\"0000000000000000000000000000000000000000000000000000000000000000\"}]"
  mock_curl "some content"

  run_iso_get "mint" --version "22" --variant "cinnamon"
  [ "$status" -ne 0 ]
  [[ "$output" == *"checksum mismatch"* ]]
  [ ! -f "$ISO_DIR/bad.iso" ]
}

# --- force re-download ---

@test "iso:get --force re-downloads even if file exists" {
  local content="fresh content"
  local sha256=$(printf '%s' "$content" | sha256sum | awk '{print $1}')

  printf '%s' "old content" > "$ISO_DIR/force.iso"

  mock_catalog "mint" "[{\"filename\":\"force.iso\",\"variant\":\"cinnamon\",\"url\":\"http://example.com/force.iso\",\"sha256\":\"$sha256\"}]"
  mock_curl "$content"

  run_iso_get "mint" --version "22" --variant "cinnamon" --force
  [ "$status" -eq 0 ]
  [[ "$output" == *"Downloading"* ]]
  [[ "$output" == *"Verified"* ]]
}

# --- iso store ---

@test "iso:get creates store directory if it doesn't exist" {
  rm -rf "$ISO_DIR"

  local content="new dir content"
  local sha256=$(printf '%s' "$content" | sha256sum | awk '{print $1}')

  mock_catalog "mint" "[{\"filename\":\"newdir.iso\",\"variant\":\"cinnamon\",\"url\":\"http://example.com/newdir.iso\",\"sha256\":\"$sha256\"}]"
  mock_curl "$content"

  run_iso_get "mint" --version "22" --variant "cinnamon"
  [ "$status" -eq 0 ]
  [ -d "$ISO_DIR" ]
  [ -f "$ISO_DIR/newdir.iso" ]
}

# --- single variant auto-select ---

@test "iso:get auto-selects when only one variant available" {
  local content="single variant"
  local sha256=$(printf '%s' "$content" | sha256sum | awk '{print $1}')

  mock_catalog "mint" "[{\"filename\":\"single.iso\",\"variant\":\"cinnamon\",\"url\":\"http://example.com/single.iso\",\"sha256\":\"$sha256\"}]"
  mock_curl "$content"

  # No --variant specified, but only one available — should auto-select
  run_iso_get "mint" --version "22"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Verified"* ]]
}

# --- pop-os (channel field instead of variant) ---

@test "iso:get works with pop-os channel field" {
  local content="pop os content"
  local sha256=$(printf '%s' "$content" | sha256sum | awk '{print $1}')

  mock_catalog "pop-os" "[{\"filename\":\"pop-os_22.04_amd64_intel.iso\",\"channel\":\"intel\",\"url\":\"http://example.com/pop.iso\",\"sha256\":\"$sha256\"}]"
  mock_curl "$content"

  run_iso_get "pop-os" --version "22.04" --variant "intel"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Verified"* ]]
  [ -f "$ISO_DIR/pop-os_22.04_amd64_intel.iso" ]
}

# --- no checksum ---

@test "iso:get skips verification when no checksum available" {
  mock_catalog "mint" "[{\"filename\":\"nosha.iso\",\"variant\":\"cinnamon\",\"url\":\"http://example.com/nosha.iso\",\"sha256\":\"\"}]"
  mock_curl "some content"

  run_iso_get "mint" --version "22" --variant "cinnamon"
  [ "$status" -eq 0 ]
  [[ "$output" == *"No checksum available"* ]]
  [ -f "$ISO_DIR/nosha.iso" ]
}

# --- multiple variants without --variant ---

@test "iso:get requires --variant when multiple available in non-interactive mode" {
  mock_catalog "mint" '[{"filename":"a.iso","variant":"cinnamon","url":"http://example.com/a.iso","sha256":"aaa"},{"filename":"b.iso","variant":"xfce","url":"http://example.com/b.iso","sha256":"bbb"}]'

  run_iso_get "mint" --version "22"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a terminal"* ]]
}
