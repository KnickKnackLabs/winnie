#!/usr/bin/env bash
# Shared setup for winnie BATS tests.
# Provides a winnie() function that calls tasks through mise,
# following the "call the tool, not the script" pattern.

if [ -z "${REPO_DIR:-}" ]; then
  case "$BATS_TEST_DIRNAME" in
    */integration) REPO_DIR="$(cd "$BATS_TEST_DIRNAME/../.." && pwd)" ;;
    *) REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)" ;;
  esac
  export REPO_DIR
  bats_path="$PATH"
  eval "$(cd "$REPO_DIR" && mise env)"
  export PATH="$PATH:$bats_path"
fi

winnie() {
  cd "$REPO_DIR" && mise run "$@"
}
export -f winnie
