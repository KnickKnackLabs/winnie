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

# --- vm helpers ---

WINNIE_RUN_DIR="${TMPDIR:-/tmp}/winnie"

# Resolve a VM identifier to VM_ID and MONITOR_SOCK.
# Auto-detects if exactly one VM is running; errors on zero or ambiguity.
# Usage: resolve_vm [name]
# Sets: VM_ID, MONITOR_SOCK
resolve_vm() {
  local vm_name="${1:-}"

  if [[ -z "$vm_name" ]]; then
    shopt -s nullglob
    local socks=("$WINNIE_RUN_DIR"/*.sock)
    shopt -u nullglob
    local live=()
    for sock in "${socks[@]}"; do
      [[ -S "$sock" ]] || continue
      if printf '' | socat - "UNIX-CONNECT:$sock" >/dev/null 2>&1; then
        live+=("$(basename "$sock" .sock)")
      fi
    done
    if [[ ${#live[@]} -eq 0 ]]; then
      echo "Error: no running VMs found." >&2
      return 1
    elif [[ ${#live[@]} -gt 1 ]]; then
      echo "Error: multiple VMs running. Specify one with --vm:" >&2
      printf "  %s\n" "${live[@]}" >&2
      return 1
    fi
    vm_name="${live[0]}"
  fi

  VM_ID="$(basename "$vm_name")"
  VM_ID="${VM_ID%.img}"
  VM_ID="${VM_ID%.iso}"

  MONITOR_SOCK="$WINNIE_RUN_DIR/$VM_ID.sock"

  if [[ ! -S "$MONITOR_SOCK" ]]; then
    echo "Error: no running VM found for $VM_ID" >&2
    echo "Is it booted? Check: winnie vm:list" >&2
    return 1
  fi
}

# Find the PID of the QEMU process for a resolved VM.
# Usage: resolve_vm_pid
# Requires: MONITOR_SOCK to be set (via resolve_vm).
# Sets: QEMU_PID
resolve_vm_pid() {
  QEMU_PID="$(pgrep -f "unix:$MONITOR_SOCK" 2>/dev/null | head -1)" || true
  if [[ -z "$QEMU_PID" ]]; then
    echo "Error: could not find QEMU process for $VM_ID" >&2
    return 1
  fi
}

# Send a command to the QEMU monitor and return clean output.
# Usage: monitor_cmd <command>
# Requires: MONITOR_SOCK to be set (via resolve_vm).
monitor_cmd() {
  printf '%s\n' "$1" | socat -t 1 - "UNIX-CONNECT:$MONITOR_SOCK" 2>/dev/null \
    | tr -d '\r' \
    | sed 's/\x1b\[[0-9;]*[a-zA-Z]//g; s/\x1b\[[0-9]*[A-Z]//g' \
    | grep -v '^(qemu)' \
    | grep -v '^QEMU' \
    | grep -v '^$'
}

# --- formatting helpers ---

# Format bytes to human-readable.
# Usage: human_bytes <bytes>
human_bytes() {
  local bytes="$1"
  if [[ "$bytes" -ge 1073741824 ]]; then
    printf '%.1f GB' "$(echo "$bytes / 1073741824" | bc -l)"
  elif [[ "$bytes" -ge 1048576 ]]; then
    printf '%.1f MB' "$(echo "$bytes / 1048576" | bc -l)"
  elif [[ "$bytes" -ge 1024 ]]; then
    printf '%.1f KB' "$(echo "$bytes / 1024" | bc -l)"
  else
    printf '%d B' "$bytes"
  fi
}

# Format ps etime (DD-HH:MM:SS, HH:MM:SS, MM:SS, or SS) to human-readable.
# Usage: human_uptime <etime>
human_uptime() {
  local etime="$1"
  local days=0 hours=0 mins=0 secs=0

  # Strip leading whitespace
  etime="${etime#"${etime%%[![:space:]]*}"}"

  # Split off days if present (DD-...)
  if [[ "$etime" == *-* ]]; then
    days="${etime%%-*}"
    etime="${etime#*-}"
  fi

  # Remaining is HH:MM:SS, MM:SS, or SS
  IFS=: read -ra segments <<< "$etime"
  case ${#segments[@]} in
    3) hours="${segments[0]}" mins="${segments[1]}" secs="${segments[2]}" ;;
    2) mins="${segments[0]}" secs="${segments[1]}" ;;
    1) secs="${segments[0]}" ;;
  esac

  # Strip leading zeros for arithmetic
  days=$((10#$days)) hours=$((10#$hours)) mins=$((10#$mins)) secs=$((10#$secs))

  local out=()
  [[ $days -gt 0 ]] && out+=("${days}d")
  [[ $hours -gt 0 ]] && out+=("${hours}h")
  [[ $mins -gt 0 ]] && out+=("${mins}m")
  # Only show seconds if uptime < 1 minute
  if [[ ${#out[@]} -eq 0 ]]; then
    out+=("${secs}s")
  fi

  echo "${out[*]}"
}

# --- disk:format helpers ---

# All supported boot architectures.
ALL_ARCHES=(x86_64 aarch64)

# Parse variadic --arch flags into normalized arch names, one per line.
# If input is empty, outputs all supported arches.
# Usage: parse_arch_flags "$usage_arch"
# Uses the safe xargs pattern for mise var=#true strings.
parse_arch_flags() {
  local raw="${1:-}"
  if [[ -z "$raw" ]]; then
    printf '%s\n' "${ALL_ARCHES[@]}"
    return
  fi
  while IFS= read -r arch; do
    normalize_arch "$arch"
  done < <(printf '%s' "$raw" | xargs printf '%s\n')
}

# Map a normalized arch to the Debian dpkg architecture name.
# Usage: deb_arch <arch>
deb_arch() {
  case "$(normalize_arch "${1:-}")" in
    x86_64)  echo "amd64" ;;
    aarch64) echo "arm64" ;;
    *)       echo "$1" ;;
  esac
}

# Common packages needed for any disk:format operation (arch-independent).
GRUB_COMMON_PACKAGES="gdisk dosfstools e2fsprogs kpartx grub2-common jq"

# GRUB-specific apt packages for an architecture (without common tools).
# Usage: grub_only_packages <arch>
# Returns space-separated package list (grub bins only).
grub_only_packages() {
  local arch
  arch="$(normalize_arch "${1:-x86_64}")"

  case "$arch" in
    aarch64)
      echo "grub-efi-arm64-bin"
      ;;
    *)
      echo "grub-pc-bin grub-efi-amd64-bin"
      ;;
  esac
}

# GRUB apt packages needed for a given architecture.
# Usage: grub_packages <arch>
# Returns space-separated package list.
grub_packages() {
  local arch
  arch="$(normalize_arch "${1:-x86_64}")"

  echo "$GRUB_COMMON_PACKAGES $(grub_only_packages "$arch")"
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
