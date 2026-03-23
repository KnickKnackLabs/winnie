#!/usr/bin/env bats

# Validate grub.cfg syntax using grub-script-check.
# This test requires grub-common to be installed (provides grub-script-check).

load test_helper

@test "grub.cfg passes grub-script-check" {
  if ! command -v grub-script-check &>/dev/null && ! command -v grub2-script-check &>/dev/null; then
    skip "grub-script-check not installed (install grub-common)"
  fi

  checker="grub-script-check"
  command -v "$checker" &>/dev/null || checker="grub2-script-check"

  run "$checker" "$MISE_CONFIG_ROOT/grub/grub.cfg"
  echo "output: $output"
  [ "$status" -eq 0 ]
}

@test "grub.cfg contains ISO scan loop" {
  run grep -c 'for isofile in' "$MISE_CONFIG_ROOT/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects Ubuntu/Casper" {
  run grep -c 'casper/vmlinuz' "$MISE_CONFIG_ROOT/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects Debian Live" {
  run grep -c 'live/vmlinuz' "$MISE_CONFIG_ROOT/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects Arch Linux" {
  run grep -c 'arch/boot/x86_64/vmlinuz-linux' "$MISE_CONFIG_ROOT/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects Fedora" {
  run grep -c 'images/pxeboot/vmlinuz' "$MISE_CONFIG_ROOT/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects Alpine" {
  run grep -c 'boot/vmlinuz-lts' "$MISE_CONFIG_ROOT/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg detects NixOS" {
  run grep -c 'boot/bzImage' "$MISE_CONFIG_ROOT/grub/grub.cfg"
  [ "$output" -ge 1 ]
}

@test "grub.cfg checks for loopback.cfg first" {
  loopback_line=$(grep -n 'loopback.cfg' "$MISE_CONFIG_ROOT/grub/grub.cfg" | head -1 | cut -d: -f1)
  casper_line=$(grep -n 'casper/vmlinuz' "$MISE_CONFIG_ROOT/grub/grub.cfg" | head -1 | cut -d: -f1)
  [ "$loopback_line" -lt "$casper_line" ]
}

@test "grub.cfg uses WINNIE label" {
  run grep -c 'WINNIE' "$MISE_CONFIG_ROOT/grub/grub.cfg"
  [ "$output" -ge 1 ]
}
