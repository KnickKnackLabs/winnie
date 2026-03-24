#!/usr/bin/env bats

# Tests for disk:format architecture helpers in lib/common.sh:
# docker_platform, grub_packages, grub_targets

load test_helper

setup() {
  source "$MISE_CONFIG_ROOT/lib/common.sh"
}

# --- docker_platform ---

@test "docker_platform x86_64 returns linux/amd64" {
  run docker_platform x86_64
  [ "$output" = "linux/amd64" ]
}

@test "docker_platform aarch64 returns linux/arm64" {
  run docker_platform aarch64
  [ "$output" = "linux/arm64" ]
}

@test "docker_platform arm64 normalizes to linux/arm64" {
  run docker_platform arm64
  [ "$output" = "linux/arm64" ]
}

@test "docker_platform defaults to linux/amd64" {
  run docker_platform ""
  [ "$output" = "linux/amd64" ]
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
