#!/usr/bin/env bats

# Tests for disk:format router validation.
# The actual formatting requires Docker (image) or root+Linux (device),
# so we only test the router logic here.

load test_helper

@test "disk:format requires --device or --image" {
  run winnie disk:format 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"specify --device"* ]]
}

@test "disk:format rejects both --device and --image" {
  run winnie disk:format -- --device /dev/sdb --image disk.img 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"not both"* ]]
}

@test "disk:format shows usage hints on error" {
  run winnie disk:format 2>&1
  [[ "$output" == *"disk:format --device"* ]]
  [[ "$output" == *"disk:format --image"* ]]
}
