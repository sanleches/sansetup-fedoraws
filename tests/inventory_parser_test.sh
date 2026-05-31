#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later

set -euo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)"
export SANSETUP_ROOT="$ROOT_DIR"

# shellcheck source=../lib/sansetup/common.sh
. "$ROOT_DIR/lib/sansetup/common.sh"
# shellcheck source=../lib/sansetup/policy.sh
. "$ROOT_DIR/lib/sansetup/policy.sh"
# shellcheck source=../lib/sansetup/inventory.sh
. "$ROOT_DIR/lib/sansetup/inventory.sh"

assert_contains() {
  local needle="$1"
  shift
  local haystack=("$@")

  if ! list_contains "$needle" "${haystack[@]}"; then
    printf 'Assertion failed: missing expected value: %s\n' "$needle" >&2
    exit 1
  fi
}

assert_not_contains() {
  local needle="$1"
  shift
  local haystack=("$@")

  if list_contains "$needle" "${haystack[@]}"; then
    printf 'Assertion failed: unexpected value present: %s\n' "$needle" >&2
    exit 1
  fi
}

assert_equals() {
  local expected="$1"
  local actual="$2"
  local label="$3"

  if [ "$expected" != "$actual" ]; then
    printf 'Assertion failed: %s (expected=%s actual=%s)\n' "$label" "$expected" "$actual" >&2
    exit 1
  fi
}

tmp_guide="$(mktemp)"
trap 'rm -f "$tmp_guide"' EXIT

cat > "$tmp_guide" <<'EOF'
# Test Inventory

<!--
sudo dnf install should-not-parse
flatpak install flathub com.example.Commented
-->

```bash
sudo dnf install \
  git gcc \
  code

# sudo dnf install should-not-parse-from-shell-comment
```

```bash
sudo dnf install \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
```

```bash
flatpak install flathub \
  com.spotify.Client \
  net.nokyan.Resources
# flatpak install flathub com.example.DisabledByComment
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
```

```bash
pip3 install --user \
  pyserial \
  mpremote
# pip3 install --user disabled-pip-package
python3 -m pip install --user -U ruff
```

```bash
rustup component add rustfmt clippy rust-analyzer
# rustup component add disabled-component
```

```bash
nvm install --lts
# nvm install v20.0.0
```

```bash
code --install-extension \
  ms-python.python@2026.4.0
code --install-extension ms-vscode.cpptools # inline comment is ignored
# code --install-extension disabled.extension
```

Install
# Docker / Docker Compose
- Clang / Clang++

```text
sudo dnf install not-parsed-from-text-fence
```
EOF

GUIDE_FILE="$tmp_guide"
load_inventory

assert_contains git "${RPM_PACKAGES[@]}"
assert_contains code "${RPM_PACKAGES[@]}"
assert_contains clang "${RPM_PACKAGES[@]}"
assert_not_contains docker-ce "${RPM_PACKAGES[@]}"
assert_not_contains should-not-parse "${RPM_PACKAGES[@]}"
assert_not_contains not-parsed-from-text-fence "${RPM_PACKAGES[@]}"
assert_not_contains should-not-parse-from-shell-comment "${RPM_PACKAGES[@]}"

assert_contains com.spotify.Client "${FLATPAK_APPS[@]}"
assert_not_contains flathub "${FLATPAK_APPS[@]}"
assert_not_contains com.example.DisabledByComment "${FLATPAK_APPS[@]}"

assert_contains pyserial "${PYTHON_PACKAGES[@]}"
assert_contains ruff "${PYTHON_PACKAGES[@]}"
assert_not_contains disabled-pip-package "${PYTHON_PACKAGES[@]}"

assert_contains rustfmt "${RUST_COMPONENTS[@]}"
assert_contains clippy "${RUST_COMPONENTS[@]}"
assert_not_contains disabled-component "${RUST_COMPONENTS[@]}"

assert_contains ms-python.python@2026.4.0 "${VSCODE_EXTENSIONS[@]}"
assert_contains ms-vscode.cpptools "${VSCODE_EXTENSIONS[@]}"
assert_not_contains disabled.extension "${VSCODE_EXTENSIONS[@]}"

assert_equals "--lts" "$NODE_TARGET" "Node target parsing"

cat > "$tmp_guide" <<'EOF'
# No Node Inventory

```bash
sudo dnf install git
```
EOF

GUIDE_FILE="$tmp_guide"
load_inventory

assert_equals "" "$NODE_TARGET" "Node target is empty when not requested"

printf 'inventory_parser_test: PASS\n'
