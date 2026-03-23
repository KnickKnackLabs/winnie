#!/usr/bin/env bash
# Shared setup for winnie BATS tests.
# Provides a winnie() function that calls tasks through mise,
# following the "call the tool, not the script" pattern.

if [ -z "${MISE_CONFIG_ROOT:-}" ]; then
  echo "MISE_CONFIG_ROOT not set — run tests via: mise run test" >&2
  exit 1
fi

winnie() {
  cd "$MISE_CONFIG_ROOT" && mise run -q "$@"
}
export -f winnie
