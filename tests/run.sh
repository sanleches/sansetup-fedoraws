#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"

lint_guide() {
  local guide="$1"

  awk -v file="$guide" '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    function supported(command) {
      return \
        command ~ /^(sudo[[:space:]]+)?dnf5?[[:space:]]+install([[:space:]]|$)/ || \
        command ~ /^flatpak[[:space:]]+install([[:space:]]|$)/ || \
        command ~ /^python3?[[:space:]]+-m[[:space:]]+pip[[:space:]]+install([[:space:]]|$)/ || \
        command ~ /^pip3?[[:space:]]+install([[:space:]]|$)/ || \
        command ~ /^rustup[[:space:]]+component[[:space:]]+add([[:space:]]|$)/ || \
        command ~ /^code[[:space:]]+--install-extension([[:space:]]|$)/ || \
        command ~ /^nvm[[:space:]]+install([[:space:]]|$)/
    }
    function flush_pending() {
      if (pending == "") return
      if (!supported(pending)) {
        printf "%s:%d: unsupported active shell command in template: %s\n", file, pending_line, pending > "/dev/stderr"
        exit 1
      }
      pending = ""
      pending_line = 0
    }
    /^[[:space:]]*<!--/ {
      in_html_comment = 1
      if ($0 ~ /-->/) in_html_comment = 0
      next
    }
    in_html_comment {
      if ($0 ~ /-->/) in_html_comment = 0
      next
    }
    /^```/ {
      flush_pending()
      marker = $0
      sub(/^```[[:space:]]*/, "", marker)
      marker = trim(marker)
      if (!in_fence) {
        in_fence = 1
        in_shell_code = (marker == "" || marker ~ /^(bash|sh|shell|zsh)$/)
      } else {
        in_fence = 0
        in_shell_code = 0
        disabled_continuation = 0
      }
      next
    }
    !in_shell_code { next }
    {
      raw = $0
      sub(/\r$/, "", raw)
      commented = raw ~ /^[[:space:]]*#/
      line = raw
      if (commented) sub(/^[[:space:]]*#[[:space:]]?/, "", line)
      line = trim(line)
      if (line == "") next

      continues = line ~ /\\[[:space:]]*$/
      if (disabled_continuation && !commented) {
        printf "%s:%d: active line inside disabled multiline command: %s\n", file, NR, raw > "/dev/stderr"
        exit 1
      }
      if (commented) {
        disabled_continuation = continues
        next
      }
      disabled_continuation = 0

      sub(/[[:space:]]+#.*/, "", line)
      line = trim(line)
      if (line == "") next
      sub(/\\[[:space:]]*$/, "", line)
      line = trim(line)
      if (line == "") next

      if (pending == "") {
        pending = line
        pending_line = NR
      } else {
        pending = pending " " line
      }
      if (!continues) flush_pending()
    }
    END {
      if (in_fence) {
        printf "%s: unclosed fenced code block\n", file > "/dev/stderr"
        exit 1
      }
      flush_pending()
    }
  ' "$guide"
}

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
lint_guide "$ROOT_DIR/install.template.sansetup.md"
"$ROOT_DIR/sansetup.sh" --guide "$ROOT_DIR/install.template.sansetup.md" inventory >/dev/null

for guide in "$ROOT_DIR"/templates/*.sansetup.md; do
  lint_guide "$guide"
  "$ROOT_DIR/sansetup.sh" --guide "$guide" inventory >/dev/null
done

printf 'All tests: PASS\n'
