#!/usr/bin/env bats

# Tests for disk:format router validation.
# The actual formatting requires Docker (image) or root+Linux (device),
# so we only test the router logic here.

WINNIE_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"

run_disk_format() {
  run mise -C "$WINNIE_DIR" run -q disk:format -- "$@" 2>&1
}

@test "disk:format requires --device or --image" {
  run_disk_format
  [ "$status" -ne 0 ]
  [[ "$output" == *"specify --device"* ]]
}

@test "disk:format rejects both --device and --image" {
  run_disk_format --device /dev/sdb --image disk.img
  [ "$status" -ne 0 ]
  [[ "$output" == *"not both"* ]]
}

@test "disk:format shows usage hints on error" {
  run_disk_format
  [[ "$output" == *"disk:format --device"* ]]
  [[ "$output" == *"disk:format --image"* ]]
}
