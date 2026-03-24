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
  local raw="${2:-$(uname -m)}"

  # Normalize: macOS says "arm64", Linux says "aarch64"
  case "$raw" in
    arm64|aarch64) raw="aarch64" ;;
    x86_64|amd64)  raw="x86_64" ;;
  esac

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
        x86_64) echo "amd64" ;;
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
