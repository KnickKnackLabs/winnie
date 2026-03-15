#!/usr/bin/env bats

# Validate grub.cfg syntax using grub-script-check.
# This test requires grub-common to be installed (provides grub-script-check).

REPO_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "grub.cfg passes grub-script-check" {
  if ! command -v grub-script-check &>/dev/null && ! command -v grub2-script-check &>/dev/null; then
    skip "grub-script-check not installed (install grub-common)"
  fi

  checker="grub-script-check"
  command -v "$checker" &>/dev/null || checker="grub2-script-check"

  run "$checker" "$REPO_DIR/grub/grub.cfg"
  echo "output: $output"
  [ "$status" -eq 0 ]
}

@test "grub.cfg contains ISO scan loop" {
  run grep -c 'for isofile in' "$REPO_DIR/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects Ubuntu/Casper" {
  run grep -c 'casper/vmlinuz' "$REPO_DIR/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects Debian Live" {
  run grep -c 'live/vmlinuz' "$REPO_DIR/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects Arch Linux" {
  run grep -c 'arch/boot/x86_64/vmlinuz-linux' "$REPO_DIR/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects Fedora" {
  run grep -c 'images/pxeboot/vmlinuz' "$REPO_DIR/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects Alpine" {
  run grep -c 'boot/vmlinuz-lts' "$REPO_DIR/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects NixOS" {
  run grep -c 'boot/bzImage' "$REPO_DIR/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg checks for loopback.cfg first" {
  # loopback.cfg check must appear before distro-specific checks
  loopback_line=$(grep -n 'loopback.cfg' "$REPO_DIR/grub/grub.cfg" | head -1 | cut -d: -f1)
  casper_line=$(grep -n 'casper/vmlinuz' "$REPO_DIR/grub/grub.cfg" | head -1 | cut -d: -f1)
  [ "$loopback_line" -lt "$casper_line" ]
}

@test "grub.cfg uses WEINERTOY label" {
  run grep -c 'WEINERTOY' "$REPO_DIR/grub/grub.cfg"
  [ "$output" -ge 1 ]
}
