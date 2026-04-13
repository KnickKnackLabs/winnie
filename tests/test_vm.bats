#!/usr/bin/env bats

# Tests for VM-related helpers in lib/common.sh:
# normalize_arch, resolve_accel, resolve_cpu, resolve_machine

load test_helper

setup() {
  source "$MISE_CONFIG_ROOT/lib/common.sh"
}

# --- normalize_arch ---

@test "normalize_arch arm64 → aarch64" {
  run normalize_arch arm64
  [ "$output" = "aarch64" ]
}

@test "normalize_arch aarch64 → aarch64" {
  run normalize_arch aarch64
  [ "$output" = "aarch64" ]
}

@test "normalize_arch amd64 → x86_64" {
  run normalize_arch amd64
  [ "$output" = "x86_64" ]
}

@test "normalize_arch x86_64 → x86_64" {
  run normalize_arch x86_64
  [ "$output" = "x86_64" ]
}

@test "normalize_arch unknown passes through" {
  run normalize_arch riscv64
  [ "$output" = "riscv64" ]
}

# --- resolve_accel ---

@test "resolve_accel native on macOS → hvf" {
  run resolve_accel aarch64 aarch64 Darwin
  [ "$output" = "hvf" ]
}

@test "resolve_accel cross-arch on macOS → tcg" {
  run resolve_accel aarch64 x86_64 Darwin
  [ "$output" = "tcg,thread=multi" ]
}

@test "resolve_accel cross-arch on Linux → tcg" {
  run resolve_accel x86_64 aarch64 Linux
  [ "$output" = "tcg,thread=multi" ]
}

@test "resolve_accel x86_64 native on macOS → hvf" {
  run resolve_accel x86_64 x86_64 Darwin
  [ "$output" = "hvf" ]
}

# Note: kvm test is tricky — depends on /dev/kvm existing.
# We test the fallback (no /dev/kvm) which is tcg.
@test "resolve_accel native on Linux without kvm → tcg" {
  # This test runs on macOS CI where /dev/kvm doesn't exist,
  # so even with matching arches it falls through to tcg.
  if [[ -e /dev/kvm ]]; then
    skip "kvm available — would return kvm, not tcg"
  fi
  run resolve_accel x86_64 x86_64 Linux
  [ "$output" = "tcg,thread=multi" ]
}

# --- resolve_cpu ---

@test "resolve_cpu aarch64 with hvf → host" {
  run resolve_cpu aarch64 hvf
  [ "$output" = "host" ]
}

@test "resolve_cpu aarch64 with kvm → host" {
  run resolve_cpu aarch64 kvm
  [ "$output" = "host" ]
}

@test "resolve_cpu aarch64 with tcg → cortex-a72" {
  run resolve_cpu aarch64 "tcg,thread=multi"
  [ "$output" = "cortex-a72" ]
}

@test "resolve_cpu x86_64 → empty (QEMU default)" {
  run resolve_cpu x86_64 hvf
  [ "$output" = "" ]
}

@test "resolve_cpu x86_64 with tcg → empty" {
  run resolve_cpu x86_64 "tcg,thread=multi"
  [ "$output" = "" ]
}

# --- resolve_machine ---

@test "resolve_machine aarch64 → virt" {
  run resolve_machine aarch64
  [ "$output" = "virt" ]
}

@test "resolve_machine x86_64 → empty (QEMU default)" {
  run resolve_machine x86_64
  [ "$output" = "" ]
}

# --- resolve_vm autodetect with sockets on disk ---
#
# Exercises resolve_vm's autodetect path against a fake WINNIE_RUN_DIR.
# Real unix-domain listening sockets are created with `socat` running in
# the background — socat handles accept/close cleanly (unlike a python
# listener that never accepts), so the `printf '' | socat -` probe inside
# resolve_vm returns promptly without hanging.
#
# The focus is the *.qmp.sock filter: vm:boot creates <vm>.sock and
# <vm>.qmp.sock side by side, and resolve_vm must ignore the latter or it
# reports "multiple VMs running" against a single VM.

_make_listening_sock() {
  # Create a background socat listener on path $1. The listener will
  # accept any incoming connection and immediately close it (sending to
  # /dev/null), which is enough for the probe in resolve_vm to consider
  # the socket "live". Returns the pid of the background socat.
  local path="$1"
  socat "UNIX-LISTEN:$path,fork" SYSTEM:"true" >/dev/null 2>&1 &
  local pid=$!
  # Wait briefly for socat to bind before returning.
  local i
  for i in 1 2 3 4 5 6 7 8 9 10; do
    [[ -S "$path" ]] && return 0
    sleep 0.05
  done
  echo "Error: socat did not create socket at $path" >&2
  kill "$pid" 2>/dev/null || true
  return 1
}

_resolve_vm_setup() {
  command -v socat >/dev/null 2>&1 || skip "socat not installed"
  RESOLVE_TMP="$(mktemp -d)"
  WINNIE_RUN_DIR="$RESOLVE_TMP"
}

_resolve_vm_make() {
  _make_listening_sock "$1" || return 1
}

_resolve_vm_teardown() {
  # Kill all socat listeners spawned during the test.
  pkill -P $$ -f "socat UNIX-LISTEN:$RESOLVE_TMP" 2>/dev/null || true
  rm -rf "$RESOLVE_TMP"
}

@test "resolve_vm autodetect skips .qmp.sock sibling" {
  _resolve_vm_setup
  _resolve_vm_make "$RESOLVE_TMP/vm1.sock"
  _resolve_vm_make "$RESOLVE_TMP/vm1.qmp.sock"
  resolve_vm ""
  local rc=$?
  local got_id="$VM_ID"
  local got_sock="$MONITOR_SOCK"
  _resolve_vm_teardown
  [ "$rc" -eq 0 ]
  [ "$got_id" = "vm1" ]
  [ "$got_sock" = "$WINNIE_RUN_DIR/vm1.sock" ]
}

@test "resolve_vm autodetect two VMs errors, excludes .qmp siblings from list" {
  _resolve_vm_setup
  _resolve_vm_make "$RESOLVE_TMP/vm1.sock"
  _resolve_vm_make "$RESOLVE_TMP/vm1.qmp.sock"
  _resolve_vm_make "$RESOLVE_TMP/vm2.sock"
  _resolve_vm_make "$RESOLVE_TMP/vm2.qmp.sock"
  run resolve_vm ""
  _resolve_vm_teardown
  [ "$status" -ne 0 ]
  [[ "$output" == *"multiple VMs running"* ]]
  [[ "$output" == *"vm1"* ]]
  [[ "$output" == *"vm2"* ]]
  # The error list must NOT contain the .qmp siblings
  [[ "$output" != *"vm1.qmp"* ]]
  [[ "$output" != *"vm2.qmp"* ]]
}

@test "resolve_vm autodetect with no sockets errors" {
  _resolve_vm_setup
  run resolve_vm ""
  _resolve_vm_teardown
  [ "$status" -ne 0 ]
  [[ "$output" == *"no running VMs"* ]]
}
