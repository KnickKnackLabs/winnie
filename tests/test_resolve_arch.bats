#!/usr/bin/env bats

# Tests for resolve_arch() in lib/common.sh

load test_helper

setup() {
  source "$MISE_CONFIG_ROOT/lib/common.sh"
}

# --- alpine ---

@test "resolve_arch alpine x86_64" {
  run resolve_arch alpine x86_64
  [ "$status" -eq 0 ]
  [ "$output" = "x86_64" ]
}

@test "resolve_arch alpine aarch64" {
  run resolve_arch alpine aarch64
  [ "$status" -eq 0 ]
  [ "$output" = "aarch64" ]
}

@test "resolve_arch alpine arm64 normalizes to aarch64" {
  run resolve_arch alpine arm64
  [ "$status" -eq 0 ]
  [ "$output" = "aarch64" ]
}

# --- debian ---

@test "resolve_arch debian x86_64 maps to amd64" {
  run resolve_arch debian x86_64
  [ "$status" -eq 0 ]
  [ "$output" = "amd64" ]
}

@test "resolve_arch debian amd64 maps to amd64" {
  run resolve_arch debian amd64
  [ "$status" -eq 0 ]
  [ "$output" = "amd64" ]
}

@test "resolve_arch debian aarch64 maps to arm64" {
  run resolve_arch debian aarch64
  [ "$status" -eq 0 ]
  [ "$output" = "arm64" ]
}

@test "resolve_arch debian arm64 maps to arm64" {
  run resolve_arch debian arm64
  [ "$status" -eq 0 ]
  [ "$output" = "arm64" ]
}

# --- pop-os (x86 only) ---

@test "resolve_arch pop-os x86_64 maps to amd64" {
  run resolve_arch pop-os x86_64
  [ "$status" -eq 0 ]
  [ "$output" = "amd64" ]
}

@test "resolve_arch pop-os aarch64 maps to arm64" {
  run resolve_arch pop-os aarch64
  [ "$status" -eq 0 ]
  [ "$output" = "arm64" ]
}

# --- mint (x86 only) ---

@test "resolve_arch mint x86_64 maps to 64bit" {
  run resolve_arch mint x86_64
  [ "$status" -eq 0 ]
  [ "$output" = "64bit" ]
}

@test "resolve_arch mint aarch64 fails" {
  run resolve_arch mint aarch64
  [ "$status" -ne 0 ]
}

# --- defaults to host arch when empty ---

@test "resolve_arch defaults to host when arch is empty" {
  run resolve_arch alpine ""
  [ "$status" -eq 0 ]
  [ -n "$output" ]
}

# --- unknown distro passes through ---

@test "resolve_arch unknown distro passes raw arch through" {
  run resolve_arch some-future-distro x86_64
  [ "$status" -eq 0 ]
  [ "$output" = "x86_64" ]
}
