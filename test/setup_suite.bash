#!/usr/bin/env bash

setup_suite() {
  REPO_DIR="$(cd "$BATS_TEST_DIRNAME/.." && pwd)"
  export REPO_DIR
  local bats_path="$PATH"
  eval "$(cd "$REPO_DIR" && mise env)"
  export PATH="$PATH:$bats_path"
}
