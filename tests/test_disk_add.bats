#!/usr/bin/env bats

# Tests for disk:add — router validation, size checks, image sub-task.
# Device sub-task requires root + real block devices, so only the router
# and image path are tested here.

WINNIE_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

setup() {
  export TEST_DIR="$BATS_TEST_TMPDIR"
}

# Run disk:add through mise
run_disk_add() {
  run mise -C "$WINNIE_DIR" run -q disk:add -- "$@" 2>&1
}

# --- router validation ---

@test "disk:add requires --device or --image" {
  echo "fake" > "$TEST_DIR/test.iso"
  run_disk_add "$TEST_DIR/test.iso"
  [ "$status" -ne 0 ]
  [[ "$output" == *"specify --device"* ]]
}

@test "disk:add rejects both --device and --image" {
  echo "fake" > "$TEST_DIR/test.iso"
  run_disk_add "$TEST_DIR/test.iso" --device /dev/sdb --image disk.img
  [ "$status" -ne 0 ]
  [[ "$output" == *"not both"* ]]
}

# --- image sub-task validation ---

@test "disk:add --image fails if ISO doesn't exist" {
  echo "fake image" > "$TEST_DIR/disk.img"
  run_disk_add "/nonexistent.iso" --image "$TEST_DIR/disk.img"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "disk:add --image fails if image doesn't exist" {
  echo "fake iso" > "$TEST_DIR/test.iso"
  run_disk_add "$TEST_DIR/test.iso" --image "/nonexistent/disk.img"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "disk:add --image fails if ISO too large for image" {
  # Create a small "image" (1KB) and a larger "ISO" (2KB)
  dd if=/dev/zero of="$TEST_DIR/tiny.img" bs=1024 count=1 2>/dev/null
  dd if=/dev/zero of="$TEST_DIR/big.iso" bs=1024 count=2 2>/dev/null

  run_disk_add "$TEST_DIR/big.iso" --image "$TEST_DIR/tiny.img"
  [ "$status" -ne 0 ]
  [[ "$output" == *"not enough space"* ]]
}
