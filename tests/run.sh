#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

bash -n \
  "$ROOT_DIR/sansetup.sh" \
  "$ROOT_DIR/lib/sansetup/common.sh" \
  "$ROOT_DIR/lib/sansetup/policy.sh" \
  "$ROOT_DIR/lib/sansetup/inventory.sh" \
  "$ROOT_DIR/lib/sansetup/checks.sh" \
  "$ROOT_DIR/lib/sansetup/installers.sh" \
  "$ROOT_DIR/lib/sansetup/ui.sh" \
  "$ROOT_DIR/tests/inventory_parser_test.sh" \
  "$ROOT_DIR/tests/run.sh"

"$ROOT_DIR/tests/inventory_parser_test.sh"
"$ROOT_DIR/sansetup.sh" inventory >/dev/null

printf 'All tests: PASS\n'
