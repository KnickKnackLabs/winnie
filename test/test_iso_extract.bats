#!/usr/bin/env bats

# Tests for iso:extract — parse ISO grub.cfg, extract boot files, write manifest.

load test_helper


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

@test "7zz is available" {
  command -v 7zz
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

@test "iso:extract handles Fedora EFI grub and squashfs image layout" {
  local root="$TEST_DIR/iso_root"
  rm -rf "$root"
  mkdir -p "$root/EFI/BOOT" "$root/images/pxeboot" "$root/LiveOS"

  echo "fake-fedora-kernel" > "$root/images/pxeboot/vmlinuz"
  echo "fake-fedora-initrd" > "$root/images/pxeboot/initrd.img"
  echo "fake-fedora-squashfs" > "$root/LiveOS/squashfs.img"

  cat > "$root/EFI/BOOT/grub.cfg" << 'EOF'
menuentry 'Start Fedora-Workstation-Live 44' {
    linuxefi /images/pxeboot/vmlinuz root=live:CDLABEL=Fedora-WS-Live-44 rd.live.image quiet
    initrdefi /images/pxeboot/initrd.img
}
EOF

  make_mock_iso "$TEST_DIR/test.iso" "$root"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_DIR/vmlinuz" ]
  [ -f "$OUTPUT_DIR/initrd.img" ]
  [ -f "$OUTPUT_DIR/squashfs.img" ]
  [ "$(jq -r '.title' "$OUTPUT_DIR/manifest.json")" = "Start Fedora-Workstation-Live 44" ]
  [ "$(jq -r '.squashfs_path' "$OUTPUT_DIR/manifest.json")" = "LiveOS/squashfs.img" ]
}

@test "iso:extract preserves Fedora Server installer tree" {
  local root="$TEST_DIR/iso_root"
  rm -rf "$root"
  mkdir -p "$root/EFI/BOOT" "$root/images/pxeboot" "$root/images" "$root/repodata" "$root/Packages"

  echo "fake-server-kernel" > "$root/images/pxeboot/vmlinuz"
  echo "fake-server-initrd" > "$root/images/pxeboot/initrd.img"
  echo "fake-server-stage2" > "$root/images/install.img"
  echo "fake-treeinfo" > "$root/.treeinfo"
  echo "fake-media-repo" > "$root/media.repo"
  echo "fake-repodata" > "$root/repodata/repomd.xml"
  echo "fake-package" > "$root/Packages/example.rpm"

  cat > "$root/EFI/BOOT/grub.cfg" << 'EOF'
menuentry 'Install Fedora 42' {
    linuxefi /images/pxeboot/vmlinuz inst.stage2=hd:LABEL=Fedora-S-dvd-x86_64-42 quiet
    initrdefi /images/pxeboot/initrd.img
}
EOF

  make_mock_iso "$TEST_DIR/test.iso" "$root"
  run winnie iso:extract -- "$TEST_DIR/test.iso" --output "$OUTPUT_DIR"
  [ "$status" -eq 0 ]
  [ -f "$OUTPUT_DIR/images/pxeboot/vmlinuz" ]
  [ -f "$OUTPUT_DIR/images/pxeboot/initrd.img" ]
  [ -f "$OUTPUT_DIR/images/install.img" ]
  [ -f "$OUTPUT_DIR/.treeinfo" ]
  [ -f "$OUTPUT_DIR/media.repo" ]
  [ -f "$OUTPUT_DIR/repodata/repomd.xml" ]
  [ -f "$OUTPUT_DIR/Packages/example.rpm" ]
  [ "$(jq -r '.title' "$OUTPUT_DIR/manifest.json")" = "Install Fedora 42" ]
  [ "$(jq -r '.install_img_path' "$OUTPUT_DIR/manifest.json")" = "images/install.img" ]
  [ "$(jq -r '.extract_mode' "$OUTPUT_DIR/manifest.json")" = "tree" ]
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
