#!/usr/bin/env bats

# Tests for iso:extract — parse ISO grub.cfg, extract boot files, write manifest.

load test_helper

# Detect 7z binary (7zz on macOS/brew, 7z on Linux)
if command -v 7zz &>/dev/null; then
  SEVENZIP=7zz
elif command -v 7z &>/dev/null; then
  SEVENZIP=7z
else
  SEVENZIP=""
fi

setup() {
  export TEST_DIR="$BATS_TEST_TMPDIR"
  export OUTPUT_DIR="$TEST_DIR/output"
  mkdir -p "$OUTPUT_DIR"
}

# Helper: create a mock ISO with the given directory structure.
make_mock_iso() {
  local iso_path="$1" root_dir="$2"
  mkisofs -quiet -o "$iso_path" -R "$root_dir" 2>/dev/null
}

# Helper: create a standard casper-style mock ISO (Ubuntu/Pop!_OS/Mint)
make_casper_iso() {
  local iso_path="$1"
  local casper_dir="${2:-casper}"
  local root="$TEST_DIR/iso_root"
  rm -rf "$root"
  mkdir -p "$root/boot/grub" "$root/$casper_dir"

  echo "fake-kernel-data" > "$root/$casper_dir/vmlinuz"
  echo "fake-initrd-data" > "$root/$casper_dir/initrd"
  echo "fake-squashfs-data" > "$root/$casper_dir/filesystem.squashfs"

  cat > "$root/boot/grub/grub.cfg" << EOF
menuentry "Test Linux" {
    linux /$casper_dir/vmlinuz boot=casper live-media-path=/$casper_dir quiet splash ---
    initrd /$casper_dir/initrd
}
EOF

  make_mock_iso "$iso_path" "$root"
}

# --- prerequisites ---

@test "mkisofs is available" {
  command -v mkisofs
}

@test "7z or 7zz is available" {
  [[ -n "$SEVENZIP" ]]
}

# --- grub.cfg parsing ---

@test "iso:extract reads grub.cfg from ISO" {
  make_casper_iso "$TEST_DIR/test.iso"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_DIR/manifest.json" ]
  # manifest should contain the menu entry title
  grep -q "Test Linux" "$OUTPUT_DIR/manifest.json"
}

@test "iso:extract parses kernel path from grub.cfg" {
  make_casper_iso "$TEST_DIR/test.iso"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  # manifest should have the kernel path
  jq -e '.kernel_path' "$OUTPUT_DIR/manifest.json" | grep -q "casper/vmlinuz"
}

@test "iso:extract parses initrd path from grub.cfg" {
  make_casper_iso "$TEST_DIR/test.iso"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  jq -e '.initrd_path' "$OUTPUT_DIR/manifest.json" | grep -q "casper/initrd"
}

@test "iso:extract parses boot params from grub.cfg" {
  make_casper_iso "$TEST_DIR/test.iso"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  jq -e '.boot_params' "$OUTPUT_DIR/manifest.json" | grep -q "boot=casper"
  jq -e '.boot_params' "$OUTPUT_DIR/manifest.json" | grep -q "live-media-path="
}

# --- file extraction ---

@test "iso:extract extracts vmlinuz" {
  make_casper_iso "$TEST_DIR/test.iso"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_DIR/vmlinuz" ]
  grep -q "fake-kernel-data" "$OUTPUT_DIR/vmlinuz"
}

@test "iso:extract extracts initrd" {
  make_casper_iso "$TEST_DIR/test.iso"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_DIR/initrd" ]
  grep -q "fake-initrd-data" "$OUTPUT_DIR/initrd"
}

@test "iso:extract extracts squashfs" {
  make_casper_iso "$TEST_DIR/test.iso"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_DIR/filesystem.squashfs" ]
  grep -q "fake-squashfs-data" "$OUTPUT_DIR/filesystem.squashfs"
}

# --- manifest ---

@test "iso:extract writes valid JSON manifest" {
  make_casper_iso "$TEST_DIR/test.iso"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  jq empty "$OUTPUT_DIR/manifest.json"
}

@test "iso:extract manifest contains menu title" {
  make_casper_iso "$TEST_DIR/test.iso"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  [[ "$(jq -r '.title' "$OUTPUT_DIR/manifest.json")" == "Test Linux" ]]
}

# --- different distro layouts ---

@test "iso:extract handles Pop!_OS casper directory naming" {
  make_casper_iso "$TEST_DIR/test.iso" "casper_pop-os_24.04_amd64_generic_debug_481"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_DIR/vmlinuz" ]
  [ -f "$OUTPUT_DIR/initrd" ]
  [ -f "$OUTPUT_DIR/filesystem.squashfs" ]
}

@test "iso:extract handles Debian live directory layout" {
  local root="$TEST_DIR/iso_root"
  rm -rf "$root"
  mkdir -p "$root/boot/grub" "$root/live"

  echo "fake-kernel" > "$root/live/vmlinuz"
  echo "fake-initrd" > "$root/live/initrd.img"
  echo "fake-squashfs" > "$root/live/filesystem.squashfs"

  cat > "$root/boot/grub/grub.cfg" << 'EOF'
menuentry "Debian Live" {
    linux /live/vmlinuz boot=live quiet splash
    initrd /live/initrd.img
}
EOF

  make_mock_iso "$TEST_DIR/test.iso" "$root"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_DIR/vmlinuz" ]
  [ -f "$OUTPUT_DIR/initrd.img" ]
}

# --- error handling ---

@test "iso:extract fails if ISO doesn't exist" {
  run winnie iso:extract -- "/nonexistent.iso" --output "$OUTPUT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"does not exist"* ]]
}

@test "iso:extract fails if ISO has no grub.cfg" {
  local root="$TEST_DIR/iso_root"
  rm -rf "$root"
  mkdir -p "$root"
  echo "just a file" > "$root/readme.txt"
  make_mock_iso "$TEST_DIR/test.iso" "$root"

  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"grub.cfg"* ]]
}

@test "iso:extract fails if grub.cfg has no menuentry" {
  local root="$TEST_DIR/iso_root"
  rm -rf "$root"
  mkdir -p "$root/boot/grub"
  echo "set timeout=10" > "$root/boot/grub/grub.cfg"
  make_mock_iso "$TEST_DIR/test.iso" "$root"

  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -ne 0 ]
  [[ "$output" == *"menuentry"* ]]
}

@test "iso:extract creates output directory if it doesn't exist" {
  make_casper_iso "$TEST_DIR/test.iso"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$TEST_DIR/newdir/extract"
  [ "$status" -eq 0 ]
  [ -d "$TEST_DIR/newdir/extract" ]
  [ -f "$TEST_DIR/newdir/extract/manifest.json" ]
}
