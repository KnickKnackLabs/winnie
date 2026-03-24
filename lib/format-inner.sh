#!/usr/bin/env bash
# Runs inside Docker container during disk:format.
# Partitions, formats, and installs GRUB for all requested architectures.
# Handles cross-arch GRUB via .deb extraction when the container arch
# doesn't match a target arch.
#
# Usage:
#   format-inner.sh image <image-file> <arch1> [arch2 ...]
#   format-inner.sh device <block-device> <arch1> [arch2 ...]
#
# In image mode, <image-file> is relative to /out (the mounted output directory).
# In device mode, <block-device> is the full device path (e.g., /dev/sdb).
set -euo pipefail

# shellcheck source=common.sh
source /repo/lib/common.sh

MODE="$1"; shift
TARGET="$1"; shift
ARCHES=("$@")

# --- Detect container architecture ---

NATIVE_DEB_ARCH="$(dpkg --print-architecture)"
NATIVE_ARCH="$(normalize_arch "$NATIVE_DEB_ARCH")"

echo "Container arch: $NATIVE_DEB_ARCH ($NATIVE_ARCH)"
echo "Target arches: ${ARCHES[*]}"

# --- Collect native packages and identify cross-arch targets ---

NATIVE_PACKAGES=""
CROSS_ARCHES=()

for arch in "${ARCHES[@]}"; do
  if [[ "$arch" == "$NATIVE_ARCH" ]]; then
    NATIVE_PACKAGES="$(grub_packages "$arch")"
  else
    CROSS_ARCHES+=("$arch")
  fi
done

# If no native arch requested, still need base tools
if [[ -z "$NATIVE_PACKAGES" ]]; then
  NATIVE_PACKAGES="gdisk dosfstools e2fsprogs kpartx grub2-common jq"
fi

# --- Add foreign dpkg architectures if needed ---

for cross in "${CROSS_ARCHES[@]+"${CROSS_ARCHES[@]}"}"; do
  dpkg --add-architecture "$(deb_arch "$cross")"
done

# --- Install native packages ---

echo 'Installing tools...'
apt-get update -qq
# shellcheck disable=SC2086
apt-get install -y -qq $NATIVE_PACKAGES

# --- Download and extract cross-arch GRUB modules ---

for cross in "${CROSS_ARCHES[@]+"${CROSS_ARCHES[@]}"}"; do
  echo "Extracting cross-arch GRUB modules for $cross..."
  cross_dir="/tmp/cross-$cross"
  mkdir -p "$cross_dir"

  # Build qualified package list (e.g., grub-efi-arm64-bin:arm64)
  local_deb_arch="$(deb_arch "$cross")"
  cross_pkgs=()
  for pkg in $(grub_only_packages "$cross"); do
    cross_pkgs+=("${pkg}:${local_deb_arch}")
  done

  # apt-get download always writes to cwd, ignoring Dir::Cache::Archives
  (cd "$cross_dir" && apt-get download "${cross_pkgs[@]}")

  mkdir -p "$cross_dir/extracted"
  for deb in "$cross_dir"/*.deb; do
    [[ -f "$deb" ]] || continue
    dpkg-deb -x "$deb" "$cross_dir/extracted/"
  done
done

# --- Set up the target disk ---

case "$MODE" in
  image)
    IMAGE="/out/$TARGET"
    echo 'Setting up loopback device...'
    DISK=$(losetup -f --show "$IMAGE")
    echo "  -> $DISK"
    USE_KPARTX=true
    ;;
  device)
    DISK="$TARGET"
    USE_KPARTX=false
    ;;
  *)
    echo "Error: unknown mode '$MODE' (expected 'image' or 'device')" >&2
    exit 1
    ;;
esac

# --- Partition ---

echo 'Creating GPT partition table...'
sgdisk --zap-all "$DISK"
sgdisk \
  --new=1:2048:+2M    --typecode=1:ef02 --change-name=1:'BIOS Boot' \
  --new=2:0:+256M     --typecode=2:ef00 --change-name=2:'EFI System' \
  --new=3:0:0          --typecode=3:8300 --change-name=3:'WINNIE' \
  "$DISK"

# --- Create partition device mappings ---

if $USE_KPARTX; then
  echo 'Creating partition mappings...'
  kpartx -av "$DISK"
  LOOPNAME=$(basename "$DISK")
  PART_EFI="/dev/mapper/${LOOPNAME}p2"
  PART_DATA="/dev/mapper/${LOOPNAME}p3"
else
  partprobe "$DISK"
  sleep 1
  if [[ "$DISK" =~ [0-9]$ ]]; then
    PART_PREFIX="${DISK}p"
  else
    PART_PREFIX="${DISK}"
  fi
  PART_EFI="${PART_PREFIX}2"
  PART_DATA="${PART_PREFIX}3"
fi

# --- Format ---

echo 'Formatting partitions...'
mkfs.fat -F 32 -n EFI "$PART_EFI"
mkfs.ext4 -L WINNIE -q "$PART_DATA"

MOUNT_DATA=$(mktemp -d)
MOUNT_EFI=$(mktemp -d)
mount "$PART_DATA" "$MOUNT_DATA"
mount "$PART_EFI" "$MOUNT_EFI"

# --- Install GRUB for each architecture ---

install_native_grub() {
  local target="$1"
  shift
  echo "  Installing GRUB ($target)..."
  grub-install "$@"
}

install_cross_grub() {
  local target="$1" cross_arch="$2"
  shift 2
  local module_dir="/tmp/cross-$cross_arch/extracted/usr/lib/grub/$target"
  echo "  Installing GRUB ($target) [cross]..."
  grub-install --directory="$module_dir" "$@"
}

for arch in "${ARCHES[@]}"; do
  echo "Installing GRUB for $arch..."
  is_native=$([[ "$arch" == "$NATIVE_ARCH" ]] && echo true || echo false)

  while IFS= read -r target; do
    args=(--target="$target" --boot-directory="$MOUNT_DATA/boot" --removable)

    if [[ "$target" == *-efi ]]; then
      args+=(--efi-directory="$MOUNT_EFI")
    else
      # BIOS targets need the disk device
      args+=("$DISK")
    fi

    if $is_native; then
      install_native_grub "$target" "${args[@]}"
    else
      install_cross_grub "$target" "$arch" "${args[@]}"
    fi
  done < <(grub_targets "$arch")
done

# --- Finalize ---

mkdir -p "$MOUNT_DATA/distros"

echo 'Generating initial grub.cfg...'
source /repo/lib/grub-gen.sh
grub_generate "$MOUNT_DATA"

sync
echo 'Cleaning up...'
umount "$MOUNT_EFI" "$MOUNT_DATA"

if $USE_KPARTX; then
  kpartx -dv "$DISK"
  losetup -d "$DISK"
fi

echo 'Done.'
