#!/usr/bin/env bats

# Integration tests for VM input tools (sendkey, type, click).
# Boots a minimal Alpine VM, sends input, verifies via screenshot comparison.
#
# These tests require QEMU and an Alpine ISO in the store.
# Run separately from the main test suite:
#   mise run test -- tests/test_vm_input.bats
#
# Skips gracefully if prerequisites are missing.

load test_helper

ALPINE_ISO=""
TEST_IMAGE=""
BOOT_TIMEOUT=20

setup_file() {
  # Detect QEMU binary for host arch
  local host_arch
  host_arch="$(uname -m)"
  case "$host_arch" in
    arm64|aarch64) QEMU_BIN="qemu-system-aarch64" ;;
    x86_64|amd64)  QEMU_BIN="qemu-system-x86_64" ;;
    *) skip "Unsupported host architecture: $host_arch" ;;
  esac
  if ! command -v "$QEMU_BIN" &>/dev/null; then
    skip "$QEMU_BIN not installed"
  fi

  # Find Alpine ISO in store
  local store="${XDG_DATA_HOME:-$HOME/.local/share}/winnie/isos"
  ALPINE_ISO=$(find "$store" -name "alpine-*.iso" 2>/dev/null | head -1)
  if [[ -z "$ALPINE_ISO" ]]; then
    skip "No Alpine ISO in store — run: winnie iso:get alpine"
  fi

  # Create a test image
  TEST_IMAGE="${TMPDIR:-/tmp}/winnie-test-$$.img"
  rm -f "$TEST_IMAGE"
  winnie disk:format --image "$TEST_IMAGE" --size 512 >/dev/null 2>&1

  # Add Alpine
  winnie disk:add "$ALPINE_ISO" --image "$TEST_IMAGE" >/dev/null 2>&1

  # Boot in headless mode
  winnie vm:boot --image "$TEST_IMAGE" --uefi --memory 512 --headless >/dev/null 2>&1 &
  BOOT_PID=$!

  # Wait for boot
  sleep "$BOOT_TIMEOUT"

  # Verify VM is running
  if ! kill -0 "$BOOT_PID" 2>/dev/null; then
    echo "VM failed to start" >&2
    return 1
  fi

  export ALPINE_ISO TEST_IMAGE BOOT_PID
}

teardown_file() {
  # Kill VM if running
  local vm_name
  vm_name="$(basename "${TEST_IMAGE:-}" .img)"
  if [[ -n "$vm_name" ]]; then
    winnie vm:kill --vm "$vm_name" 2>/dev/null || true
  fi

  # Clean up image
  rm -f "${TEST_IMAGE:-}" 2>/dev/null || true
}

# Helper: take a screenshot and return the path.
take_screenshot() {
  local vm_name output
  vm_name="$(basename "$TEST_IMAGE" .img)"
  output=$(mktemp "${TMPDIR:-/tmp}/winnie-screenshot-XXXXXX.ppm")
  winnie vm:screenshot --vm "$vm_name" -o "$output" >/dev/null 2>&1
  echo "$output"
}

# Helper: get file checksum.
file_checksum() {
  shasum -a 256 "$1" | awk '{print $1}'
}

# --- sendkey ---

@test "vm:sendkey sends a key without error" {
  local vm_name
  vm_name="$(basename "$TEST_IMAGE" .img)"
  run winnie vm:sendkey --vm "$vm_name" ret
  [ "$status" -eq 0 ]
}

@test "vm:sendkey changes screen content" {
  local before after before_sum after_sum
  before=$(take_screenshot)
  sleep 1

  # Send several keys to ensure visible change
  local vm_name
  vm_name="$(basename "$TEST_IMAGE" .img)"
  winnie vm:sendkey --vm "$vm_name" ret
  sleep 0.5
  winnie vm:sendkey --vm "$vm_name" ret
  sleep 0.5
  winnie vm:sendkey --vm "$vm_name" ret
  sleep 1

  after=$(take_screenshot)

  before_sum=$(file_checksum "$before")
  after_sum=$(file_checksum "$after")

  rm -f "$before" "$after"

  [ "$before_sum" != "$after_sum" ]
}

# --- type ---

@test "vm:type changes screen content" {
  local before after before_sum after_sum
  before=$(take_screenshot)
  sleep 1

  local vm_name
  vm_name="$(basename "$TEST_IMAGE" .img)"
  winnie vm:type --vm "$vm_name" "root"
  sleep 1

  after=$(take_screenshot)

  before_sum=$(file_checksum "$before")
  after_sum=$(file_checksum "$after")

  rm -f "$before" "$after"

  [ "$before_sum" != "$after_sum" ]
}

# --- click ---

@test "vm:click sends a click without error" {
  local vm_name
  vm_name="$(basename "$TEST_IMAGE" .img)"
  run winnie vm:click --vm "$vm_name" 100 100
  [ "$status" -eq 0 ]
}

@test "vm:click changes screen content (mouse cursor moves)" {
  local before after before_sum after_sum
  before=$(take_screenshot)
  sleep 1

  # Move mouse to a different position and click
  local vm_name
  vm_name="$(basename "$TEST_IMAGE" .img)"
  winnie vm:click --vm "$vm_name" 500 400
  sleep 1

  after=$(take_screenshot)

  before_sum=$(file_checksum "$before")
  after_sum=$(file_checksum "$after")

  rm -f "$before" "$after"

  [ "$before_sum" != "$after_sum" ]
}

# --- error cases (no VM needed) ---

@test "vm:sendkey fails for non-existent VM" {
  run winnie vm:sendkey --vm nonexistent-vm-12345 ret
  [ "$status" -ne 0 ]
}

@test "vm:type fails for non-existent VM" {
  run winnie vm:type --vm nonexistent-vm-12345 "hello"
  [ "$status" -ne 0 ]
}

@test "vm:click fails for non-existent VM" {
  run winnie vm:click --vm nonexistent-vm-12345 100 100
  [ "$status" -ne 0 ]
}
