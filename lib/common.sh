#!/usr/bin/env bash
# common.sh — shared helpers for winnie tasks

# Run a command with a gum spinner if stderr is a TTY, otherwise run directly.
spin() {
  local title="$1"; shift
  if [[ -t 2 ]]; then
    gum spin --show-output --title "$title" -- "$@"
  else
    "$@"
  fi
}

# Map host architecture to distro-specific arch string.
# Usage: resolve_arch <distro> [arch]
# If arch is omitted, detects from uname -m.
# Returns empty string (and exits 1) if the distro doesn't support the arch.
resolve_arch() {
  local distro="$1"
  local raw
  raw="$(normalize_arch "${2:-$(uname -m)}")"

  case "$distro" in
    alpine)
      case "$raw" in
        x86_64)  echo "x86_64" ;;
        aarch64) echo "aarch64" ;;
        *) return 1 ;;
      esac ;;
    debian)
      case "$raw" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *) return 1 ;;
      esac ;;
    pop-os)
      case "$raw" in
        x86_64)  echo "amd64" ;;
        aarch64) echo "arm64" ;;
        *) return 1 ;;
      esac ;;
    mint)
      case "$raw" in
        x86_64) echo "64bit" ;;
        *) return 1 ;;
      esac ;;
    *)
      echo "$raw" ;;
  esac
}

# Normalize an architecture name to QEMU's canonical form.
# Usage: normalize_arch <arch>
# Accepts: arm64, aarch64, amd64, x86_64
normalize_arch() {
  case "$1" in
    arm64|aarch64) echo "aarch64" ;;
    amd64|x86_64)  echo "x86_64" ;;
    *)             echo "$1" ;;
  esac
}

# --- vm:boot helpers ---

# Select QEMU accelerator based on host arch, guest arch, and OS.
# Usage: resolve_accel <host_arch> <guest_arch> <os>
# Outputs: "hvf", "kvm", or "tcg,thread=multi"
# host_arch and guest_arch should already be normalized.
# os should be "Darwin" or "Linux".
resolve_accel() {
  local host="$1" guest="$2" os="$3"

  if [[ "$host" == "$guest" ]]; then
    case "$os" in
      Darwin) echo "hvf"; return ;;
      Linux)
        if [[ -e /dev/kvm ]]; then
          echo "kvm"; return
        fi
        ;;
    esac
  fi
  echo "tcg,thread=multi"
}

# Select QEMU CPU model for a given guest architecture.
# Usage: resolve_cpu <guest_arch> <accel>
# For aarch64: "host" when using native accel, "cortex-a72" for emulation.
# For x86_64: empty (QEMU's default is fine).
resolve_cpu() {
  local guest="$1" accel="$2"

  case "$guest" in
    aarch64)
      if [[ "$accel" == "hvf" || "$accel" == "kvm" ]]; then
        echo "host"
      else
        echo "cortex-a72"
      fi
      ;;
  esac
}

# Select QEMU machine type for a given guest architecture.
# Usage: resolve_machine <guest_arch>
# aarch64 needs explicit "-machine virt". x86_64 uses QEMU's default.
resolve_machine() {
  case "$1" in
    aarch64) echo "virt" ;;
  esac
}

# --- disk:format helpers ---

# Docker platform for a given target architecture.
# Usage: docker_platform <arch>
docker_platform() {
  case "$(normalize_arch "${1:-x86_64}")" in
    aarch64) echo "linux/arm64" ;;
    *)       echo "linux/amd64" ;;
  esac
}

# GRUB apt packages needed for a given architecture.
# Usage: grub_packages <arch>
# Returns space-separated package list.
grub_packages() {
  local arch
  arch="$(normalize_arch "${1:-x86_64}")"

  # Common packages for all arches
  local common="gdisk dosfstools e2fsprogs kpartx grub2-common jq"

  case "$arch" in
    aarch64)
      # ARM64: UEFI only (no legacy BIOS on ARM)
      echo "$common grub-efi-arm64-bin"
      ;;
    *)
      # x86_64: both legacy BIOS and UEFI
      echo "$common grub-pc-bin grub-efi-amd64-bin"
      ;;
  esac
}

# GRUB install targets for a given architecture.
# Usage: grub_targets <arch>
# Returns newline-separated targets (for iteration).
grub_targets() {
  local arch
  arch="$(normalize_arch "${1:-x86_64}")"

  case "$arch" in
    aarch64)
      echo "arm64-efi"
      ;;
    *)
      echo "i386-pc"
      echo "x86_64-efi"
      ;;
  esac
}
