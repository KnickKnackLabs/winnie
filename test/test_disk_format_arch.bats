#!/usr/bin/env bats

# Tests for disk:format architecture helpers in lib/common.sh:
# grub_packages, grub_only_packages, grub_targets, parse_arch_flags, deb_arch

load test_helper

setup() {
  source "$REPO_DIR/lib/common.sh"
}

# --- ALL_ARCHES ---

@test "ALL_ARCHES contains x86_64 and aarch64" {
  [[ " ${ALL_ARCHES[*]} " == *" x86_64 "* ]]
  [[ " ${ALL_ARCHES[*]} " == *" aarch64 "* ]]
}

@test "ALL_ARCHES has exactly 2 entries" {
  [ "${#ALL_ARCHES[@]}" -eq 2 ]
}

# --- parse_arch_flags ---

@test "parse_arch_flags with no args returns all arches" {
  run parse_arch_flags ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"x86_64"* ]]
  [[ "$output" == *"aarch64"* ]]
}

@test "parse_arch_flags with empty string returns all arches" {
  run parse_arch_flags
  [ "$status" -eq 0 ]
  [[ "$output" == *"x86_64"* ]]
  [[ "$output" == *"aarch64"* ]]
}

@test "parse_arch_flags with single arch returns just that arch" {
  run parse_arch_flags "aarch64"
  [ "$status" -eq 0 ]
  [ "$(echo "$output" | wc -l | tr -d ' ')" -eq 1 ]
  [ "$output" = "aarch64" ]
}

@test "parse_arch_flags normalizes arm64 to aarch64" {
  run parse_arch_flags "arm64"
  [ "$status" -eq 0 ]
  [ "$output" = "aarch64" ]
}

@test "parse_arch_flags normalizes amd64 to x86_64" {
  run parse_arch_flags "amd64"
  [ "$status" -eq 0 ]
  [ "$output" = "x86_64" ]
}

@test "parse_arch_flags handles multiple arches" {
  # Simulate mise var=#true format: space-separated shell-escaped string
  run parse_arch_flags "x86_64 aarch64"
  [ "$status" -eq 0 ]
  lines_count="$(echo "$output" | wc -l | tr -d ' ')"
  [ "$lines_count" -eq 2 ]
  [ "${lines[0]}" = "x86_64" ]
  [ "${lines[1]}" = "aarch64" ]
}

@test "parse_arch_flags normalizes multiple arches" {
  run parse_arch_flags "amd64 arm64"
  [ "$status" -eq 0 ]
  [ "${lines[0]}" = "x86_64" ]
  [ "${lines[1]}" = "aarch64" ]
}

# --- deb_arch ---

@test "deb_arch x86_64 returns amd64" {
  run deb_arch x86_64
  [ "$output" = "amd64" ]
}

@test "deb_arch aarch64 returns arm64" {
  run deb_arch aarch64
  [ "$output" = "arm64" ]
}

@test "deb_arch normalizes before mapping" {
  run deb_arch arm64
  [ "$output" = "arm64" ]
}

# --- grub_only_packages ---

@test "grub_only_packages x86_64 includes pc and efi-amd64" {
  run grub_only_packages x86_64
  [[ "$output" == *"grub-pc-bin"* ]]
  [[ "$output" == *"grub-efi-amd64-bin"* ]]
}

@test "grub_only_packages aarch64 is efi-arm64 only" {
  run grub_only_packages aarch64
  [ "$output" = "grub-efi-arm64-bin" ]
}

@test "grub_only_packages does not include common tools" {
  for arch in x86_64 aarch64; do
    run grub_only_packages "$arch"
    [[ "$output" != *"gdisk"* ]]
    [[ "$output" != *"kpartx"* ]]
    [[ "$output" != *"jq"* ]]
  done
}

# --- grub_packages ---

@test "grub_packages x86_64 includes pc and efi-amd64" {
  run grub_packages x86_64
  [[ "$output" == *"grub-pc-bin"* ]]
  [[ "$output" == *"grub-efi-amd64-bin"* ]]
}

@test "grub_packages x86_64 does not include arm64" {
  run grub_packages x86_64
  [[ "$output" != *"arm64"* ]]
}

@test "grub_packages aarch64 includes efi-arm64" {
  run grub_packages aarch64
  [[ "$output" == *"grub-efi-arm64-bin"* ]]
}

@test "grub_packages aarch64 does not include pc-bin" {
  run grub_packages aarch64
  [[ "$output" != *"grub-pc-bin"* ]]
}

@test "grub_packages aarch64 does not include efi-amd64" {
  run grub_packages aarch64
  [[ "$output" != *"grub-efi-amd64-bin"* ]]
}

@test "grub_packages always includes common tools" {
  for arch in x86_64 aarch64; do
    run grub_packages "$arch"
    [[ "$output" == *"gdisk"* ]]
    [[ "$output" == *"kpartx"* ]]
    [[ "$output" == *"jq"* ]]
  done
}

# --- grub_targets ---

@test "grub_targets x86_64 includes i386-pc and x86_64-efi" {
  run grub_targets x86_64
  [[ "$output" == *"i386-pc"* ]]
  [[ "$output" == *"x86_64-efi"* ]]
}

@test "grub_targets aarch64 is arm64-efi only" {
  run grub_targets aarch64
  [ "$output" = "arm64-efi" ]
}

@test "grub_targets aarch64 does not include i386-pc" {
  run grub_targets aarch64
  [[ "$output" != *"i386-pc"* ]]
}
