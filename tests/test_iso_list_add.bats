#!/usr/bin/env bats

# Tests for iso:list and iso:add

WINNIE_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
  export ISO_DIR="$BATS_TEST_TMPDIR/isos"
  export WINNIE_ISO_DIR="$ISO_DIR"
  mkdir -p "$ISO_DIR"
}

# Run a winnie task
run_winnie() {
  WINNIE_ISO_DIR="$ISO_DIR" run mise -C "$WINNIE_DIR" run -q "$@" 2>&1
}

# --- iso:list ---

@test "iso:list shows empty store message" {
  rm -rf "$ISO_DIR"
  run_winnie iso:list
  [ "$status" -eq 0 ]
  [[ "$output" == *"No ISOs in store"* ]]
}

@test "iso:list --json returns empty array for empty store" {
  rm -rf "$ISO_DIR"
  run_winnie iso:list -- --json
  [ "$status" -eq 0 ]
  [ "$output" = "[]" ]
}

@test "iso:list shows ISO files" {
  echo "fake iso" > "$ISO_DIR/test.iso"

  run_winnie iso:list
  [ "$status" -eq 0 ]
  [[ "$output" == *"test.iso"* ]]
}

@test "iso:list --json includes filename and path" {
  echo "fake iso" > "$ISO_DIR/test.iso"

  run_winnie iso:list -- --json
  [ "$status" -eq 0 ]
  echo "$output" | jq -e '.[0].filename == "test.iso"'
  echo "$output" | jq -e '.[0].path | endswith("test.iso")'
}

@test "iso:list shows multiple ISOs" {
  echo "iso one" > "$ISO_DIR/alpha.iso"
  echo "iso two" > "$ISO_DIR/beta.iso"

  run_winnie iso:list -- --json
  [ "$status" -eq 0 ]
  count=$(echo "$output" | jq length)
  [ "$count" -eq 2 ]
}

# --- iso:add ---

@test "iso:add copies file to store" {
  local src="$BATS_TEST_TMPDIR/source.iso"
  echo "real iso content" > "$src"

  run_winnie iso:add "$src"
  [ "$status" -eq 0 ]
  [ -f "$ISO_DIR/source.iso" ]
  [[ "$output" == *"Added source.iso"* ]]
}

@test "iso:add --link creates symlink" {
  local src="$BATS_TEST_TMPDIR/linked.iso"
  echo "linked content" > "$src"

  run_winnie iso:add -- "$src" --link
  [ "$status" -eq 0 ]
  [ -L "$ISO_DIR/linked.iso" ]
  [[ "$output" == *"Linked"* ]]
}

@test "iso:add fails if file doesn't exist" {
  run_winnie iso:add "/nonexistent/file.iso"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "iso:add fails if file already in store" {
  local src="$BATS_TEST_TMPDIR/dupe.iso"
  echo "original" > "$src"
  echo "already there" > "$ISO_DIR/dupe.iso"

  run_winnie iso:add "$src"
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "iso:add creates store directory if missing" {
  rm -rf "$ISO_DIR"
  local src="$BATS_TEST_TMPDIR/newstore.iso"
  echo "content" > "$src"

  run_winnie iso:add "$src"
  [ "$status" -eq 0 ]
  [ -d "$ISO_DIR" ]
  [ -f "$ISO_DIR/newstore.iso" ]
}

@test "iso:add warns on non-iso extension" {
  local src="$BATS_TEST_TMPDIR/notaniso.img"
  echo "content" > "$src"

  run_winnie iso:add "$src"
  [ "$status" -eq 0 ]
  [[ "$output" == *"Warning"* ]]
}
