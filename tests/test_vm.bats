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
