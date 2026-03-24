#!/usr/bin/env bats

# Tests for grub.cfg generation from distro manifests.

load test_helper

setup() {
  export TEST_DIR="$BATS_TEST_TMPDIR"
  source "$MISE_CONFIG_ROOT/lib/grub-gen.sh"
}

# Helper: create a fake distro with a manifest
make_distro() {
  local slug="$1" title="$2" kernel="$3" initrd="$4" params="${5:-}" squashfs="${6:-}"
  local dir="$TEST_DIR/distros/$slug"
  mkdir -p "$dir"
  jq -n \
    --arg title "$title" \
    --arg kernel_path "$kernel" \
    --arg initrd_path "$initrd" \
    --arg boot_params "$params" \
    --arg squashfs_path "$squashfs" \
    '{title: $title, kernel_path: $kernel_path, initrd_path: $initrd_path, boot_params: $boot_params, squashfs_path: $squashfs_path}' \
    > "$dir/manifest.json"
}

@test "grub_generate creates grub.cfg" {
  make_distro "test-linux" "Test Linux" "boot/vmlinuz" "boot/initrd" "quiet"
  grub_generate "$TEST_DIR"
  [ -f "$TEST_DIR/boot/grub/grub.cfg" ]
}

@test "grub_generate includes header with timeout" {
  make_distro "test-linux" "Test Linux" "boot/vmlinuz" "boot/initrd" "quiet"
  grub_generate "$TEST_DIR"
  grep -q 'set timeout=10' "$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'set default=0' "$TEST_DIR/boot/grub/grub.cfg"
}

@test "grub_generate creates menuentry from manifest" {
  make_distro "alpine-3.21" "Linux lts" "boot/vmlinuz-lts" "boot/initramfs-lts" "modules=loop,squashfs quiet"
  grub_generate "$TEST_DIR"
  grep -q 'menuentry "Linux lts (alpine-3.21)"' "$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'linux /distros/alpine-3.21/vmlinuz-lts' "$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'initrd /distros/alpine-3.21/initramfs-lts' "$TEST_DIR/boot/grub/grub.cfg"
}

@test "grub_generate includes boot params and strips quiet/splash" {
  make_distro "debian-live" "Debian Live" "live/vmlinuz" "live/initrd.img" "boot=live components quiet splash"
  grub_generate "$TEST_DIR"
  local cfg="$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'boot=live components' "$cfg"
  grep -q 'plymouth.enable=0' "$cfg"
  ! grep -q 'quiet' "$cfg"
  ! grep -q 'splash' "$cfg"
}

@test "grub_generate strips findiso param" {
  make_distro "debian-live" "Debian Live" "live/vmlinuz" "live/initrd.img" 'boot=live components quiet splash findiso=${iso_path}'
  grub_generate "$TEST_DIR"
  local cfg="$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'boot=live' "$cfg"
  ! grep -q 'findiso=' "$cfg"
}

@test "grub_generate strips iso-scan/filename param" {
  make_distro "ubuntu" "Ubuntu" "casper/vmlinuz" "casper/initrd" "boot=casper iso-scan/filename=/isos/ubuntu.iso quiet splash"
  grub_generate "$TEST_DIR"
  local cfg="$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'boot=casper' "$cfg"
  ! grep -q 'iso-scan/filename=' "$cfg"
}

@test "grub_generate rewrites live-media-path to extracted location" {
  make_distro "debian-live" "Debian Live" "live/vmlinuz" "live/initrd.img" "boot=live components live-media-path=/live quiet splash" "live/filesystem.squashfs"
  grub_generate "$TEST_DIR"
  local cfg="$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'live-media-path=/distros/debian-live' "$cfg"
  ! grep -q 'live-media-path=/live' "$cfg"
}

@test "grub_generate adds live-media-path when squashfs present but param missing" {
  make_distro "debian-std" "Debian Standard" "live/vmlinuz" "live/initrd.img" "boot=live components" "live/filesystem.squashfs"
  grub_generate "$TEST_DIR"
  local cfg="$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'live-media-path=/distros/debian-std' "$cfg"
}

@test "grub_generate does not add live-media-path when no squashfs" {
  make_distro "alpine" "Alpine" "boot/vmlinuz-lts" "boot/initramfs-lts" "modules=loop,squashfs quiet"
  grub_generate "$TEST_DIR"
  local cfg="$TEST_DIR/boot/grub/grub.cfg"
  ! grep -q 'live-media-path' "$cfg"
}

@test "grub_generate omits initrd line when initrd is empty" {
  make_distro "memdisk" "Memdisk Distro" "boot/vmlinuz" "" "quiet"
  grub_generate "$TEST_DIR"
  local cfg="$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'linux /distros/memdisk/vmlinuz' "$cfg"
  ! grep -q 'initrd /distros/memdisk/' "$cfg"
}

@test "grub_generate handles multiple distros" {
  make_distro "alpine" "Alpine" "boot/vmlinuz-lts" "boot/initramfs-lts" "quiet"
  make_distro "debian" "Debian" "live/vmlinuz" "live/initrd.img" "boot=live"
  grub_generate "$TEST_DIR"
  local cfg="$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'menuentry "Alpine (alpine)"' "$cfg"
  grep -q 'menuentry "Debian (debian)"' "$cfg"
}

@test "grub_generate is idempotent" {
  make_distro "test" "Test" "boot/vmlinuz" "boot/initrd" "quiet"
  grub_generate "$TEST_DIR"
  local first second
  first=$(cat "$TEST_DIR/boot/grub/grub.cfg")
  grub_generate "$TEST_DIR"
  second=$(cat "$TEST_DIR/boot/grub/grub.cfg")
  [ "$first" = "$second" ]
}

@test "grub_generate produces no distro entries with empty distros dir" {
  mkdir -p "$TEST_DIR/distros"
  grub_generate "$TEST_DIR"
  [ -f "$TEST_DIR/boot/grub/grub.cfg" ]
  # Should have utility entries (Reboot, Shutdown) but no distro entries
  ! grep -q 'linux /distros' "$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'menuentry "Reboot"' "$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'menuentry "Shutdown"' "$TEST_DIR/boot/grub/grub.cfg"
}

@test "grub_generate searches for WINNIE label" {
  make_distro "test" "Test" "boot/vmlinuz" "boot/initrd" "quiet"
  grub_generate "$TEST_DIR"
  grep -q 'search --no-floppy --label WINNIE --set=root' "$TEST_DIR/boot/grub/grub.cfg"
}

@test "grub_generate uses basename for kernel and initrd" {
  make_distro "test" "Test" "some/deep/path/vmlinuz" "some/deep/path/initrd.img" "quiet"
  grub_generate "$TEST_DIR"
  local cfg="$TEST_DIR/boot/grub/grub.cfg"
  grep -q 'linux /distros/test/vmlinuz' "$cfg"
  grep -q 'initrd /distros/test/initrd.img' "$cfg"
  # Should NOT have the full original path
  ! grep -q 'some/deep/path' "$cfg"
}
