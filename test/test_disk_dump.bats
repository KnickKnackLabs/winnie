#!/usr/bin/env bats

# Tests for disk:dump validation logic.
# Actual dd requires sudo + a real device, so we test error paths only.

load test_helper

@test "disk:dump requires --device" {
  run winnie disk:dump -- --image /tmp/out.img 2>&1
  [ "$status" -ne 0 ]
}

@test "disk:dump requires --image" {
  run winnie disk:dump -- --device /dev/disk99 2>&1
  [ "$status" -ne 0 ]
}

@test "disk:dump rejects existing output file" {
  local tmpfile="$BATS_TEST_TMPDIR/exists.img"
  touch "$tmpfile"
  run winnie disk:dump -- --device /dev/disk99 --image "$tmpfile" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"already exists"* ]]
}

@test "disk:dump rejects invalid device" {
  run winnie disk:dump -- --device /dev/nonexistent99 --image "$BATS_TEST_TMPDIR/out.img" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"not a valid disk"* ]] || [[ "$output" == *"not a block device"* ]]
}

@test "disk:dump rejects boot disk" {
  if [[ "$(uname)" != "Darwin" ]]; then
    skip "boot disk check uses diskutil (macOS only)"
  fi
  boot_disk=$(diskutil info / | awk '/Part of Whole:/ {print $NF}')
  run winnie disk:dump -- --device "/dev/$boot_disk" --image "$BATS_TEST_TMPDIR/out.img" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"boot disk"* ]]
}

@test "disk:dump rejects boot disk partition" {
  if [[ "$(uname)" != "Darwin" ]]; then
    skip "boot disk check uses diskutil (macOS only)"
  fi
  boot_disk=$(diskutil info / | awk '/Part of Whole:/ {print $NF}')
  # Get first partition of boot disk
  first_part=$(diskutil list "/dev/$boot_disk" | awk '/^ *[0-9]+:/ && NR>1 {print $NF; exit}')
  [ -n "$first_part" ] || skip "could not determine boot disk partition"
  run winnie disk:dump -- --device "/dev/$first_part" --image "$BATS_TEST_TMPDIR/out.img" 2>&1
  [ "$status" -ne 0 ]
  [[ "$output" == *"boot disk"* ]]
}
