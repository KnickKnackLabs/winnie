#!/usr/bin/env bats

# Tests for disk:add — router validation, size checks, image sub-task.
# Device sub-task requires root + real block devices, so only the router
# and image path are tested here.

load test_helper

setup() {
  export TEST_DIR="$BATS_TEST_TMPDIR"
}

# --- router validation ---

@test "disk:add requires --device or --image" {
  echo "fake" > "$TEST_DIR/test.iso"
  run winnie disk:add -- "$TEST_DIR/test.iso" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"specify --device"* ]]
}

@test "disk:add rejects both --device and --image" {
  echo "fake" > "$TEST_DIR/test.iso"
  run winnie disk:add -- "$TEST_DIR/test.iso" --device /dev/sdb --image disk.img 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"not both"* ]]
}

# --- image sub-task validation ---

@test "disk:add --image fails if ISO doesn't exist" {
  echo "fake image" > "$TEST_DIR/disk.img"
  run winnie disk:add -- "/nonexistent.iso" --image "$TEST_DIR/disk.img" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "disk:add --image fails if image doesn't exist" {
  echo "fake iso" > "$TEST_DIR/test.iso"
  run winnie disk:add -- "$TEST_DIR/test.iso" --image "/nonexistent/disk.img" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "disk:add copy paths preserve hidden installer tree files" {
  grep -Fq 'cp -R /extract/. "$DISTRO_DIR/"' "$REPO_DIR/.mise/tasks/disk/add/image"
  grep -Fq 'cp -R "$EXTRACT_DIR"/. "$DISTRO_DIR/"' "$REPO_DIR/.mise/tasks/disk/add/device"
}

@test "disk:add --image fails if ISO too large for image" {
  dd if=/dev/zero of="$TEST_DIR/tiny.img" bs=1024 count=1 2>/dev/null
  dd if=/dev/zero of="$TEST_DIR/big.iso" bs=1024 count=2 2>/dev/null

  run winnie disk:add -- "$TEST_DIR/big.iso" --image "$TEST_DIR/tiny.img" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"not enough space"* ]]
}
