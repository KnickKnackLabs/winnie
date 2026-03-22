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
