#!/usr/bin/env bash
# Shared test helper — single source of truth is ../test_helper.bash.
# This file delegates to avoid duplication.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../test_helper.bash
source "$SCRIPT_DIR/../test_helper.bash"
