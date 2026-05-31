# inventory.sh - Parse a Markdown guide into runtime inventory arrays.
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The active guide (install.sansetup.md by default, or --guide <file>) is the source of
# truth. This module extracts package, Flatpak, Rust, Python, VS Code, and Node
# targets from documented shell fences rather than duplicating inventory in Bash.
# The parser is deliberately conservative: it consumes recognized command shapes
# and ignores prose, text fences, repo URLs, local RPM examples, unrelated shell
# commands, disabled # comments, and standalone HTML comment blocks.

# Ensure the configured Markdown guide exists before parsing it.
require_guide() {
  if [ ! -f "$GUIDE_FILE" ]; then
    if [ "$GUIDE_FILE" = "$SANSETUP_ROOT/install.sansetup.md" ] && [ -f "$SANSETUP_ROOT/install.template.sansetup.md" ]; then
      die "Guide file not found: $GUIDE_FILE. First run: cp install.template.sansetup.md install.sansetup.md, then edit install.sansetup.md."
    fi
    die "Guide file not found: $GUIDE_FILE"
  fi
  [ -r "$GUIDE_FILE" ] || die "Guide file is not readable: $GUIDE_FILE"
}

# Print the guide with standalone HTML comment blocks removed.
#
# The project uses HTML comments in guide files to embed authoring rules beside
# the inventory. Those comments may contain command examples, so every parser
# consumes this filtered stream instead of the raw Markdown. Comments are expected
# to be standalone blocks that begin with <!-- and end with --> on their own
# lines or on lines containing only comment text.
strip_markdown_comments() {
  awk '
    /^[[:space:]]*<!--/ {
      in_comment = 1
      if ($0 ~ /-->/) in_comment = 0
      next
    }
    in_comment {
      if ($0 ~ /-->/) in_comment = 0
      next
    }
    { print }
  ' "$1"
}

# Emit guide contents after comment stripping.
inventory_stream() {
  strip_markdown_comments "$GUIDE_FILE"
}

# Emit active shell commands from Markdown shell fences as one logical command per
# line. This is the parser boundary for the sansetup Markdown DSL: prose and text
# fences are documentation, shell fences are parseable, and # comments inside
# shell fences are disabled inventory.
shell_logical_lines() {
  inventory_stream | awk '
    function trim(value) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", value)
      return value
    }
    function flush_pending() {
      if (pending != "") {
        print pending
        pending = ""
      }
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
      }
      next
    }
    !in_shell_code { next }
    /^[[:space:]]*#/ { next }
    {
      line = $0
      sub(/\r$/, "", line)
      sub(/[[:space:]]+#.*/, "", line)
      line = trim(line)
      if (line == "") next

      continues = (line ~ /\\[[:space:]]*$/)
      sub(/\\[[:space:]]*$/, "", line)
      line = trim(line)
      if (line == "") next

      if (pending == "") pending = line
      else pending = pending " " line

      if (!continues) flush_pending()
    }
    END { flush_pending() }
  '
}

# Return success when an un-commented marker phrase exists in guide text.
has_enabled_marker() {
  local marker="$1"
  inventory_stream | awk -v marker="$marker" '
    /^[[:space:]]*#/ { next }
    /^[[:space:]]*[-*][[:space:]]*#/ { next }
    index($0, marker) > 0 { found = 1; exit }
    END { exit(found ? 0 : 1) }
  '
}

# Parse DNF package tokens from supported command shapes.
parse_rpm_packages() {
  shell_logical_lines | awk '
    function emit(line, items, count, i, token) {
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line == "") return

      count = split(line, items, /[[:space:]]+/)
      for (i = 1; i <= count; i++) {
        token = items[i]
        if (token == "" || token == "sudo" || token == "dnf" || token == "dnf5" || token == "install") continue
        if (token ~ /^-/) continue
        if (token ~ /^https?:/) continue
        if (token ~ /^\.\//) continue
        if (token ~ /\.rpm$/) continue
        if (token ~ /^\$/) continue
        print token
      }
    }
    /(^|[;&|])[[:space:]]*(sudo[[:space:]]+)?dnf5?[[:space:]]+install[[:space:]]+/ {
      line = $0
      sub(/^.*(sudo[[:space:]]+)?dnf5?[[:space:]]+install[[:space:]]+/, "", line)
      emit(line)
    }
  '

  if has_enabled_marker 'Docker / Docker Compose'; then
    printf '%s\n' docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  if has_enabled_marker 'Clang / Clang++'; then
    printf '%s\n' clang clang-tools-extra lld lldb
  fi
}

# Parse Flatpak app IDs from supported command shapes.
parse_flatpak_apps() {
  shell_logical_lines | awk '
    /flatpak[[:space:]]+install/ && $0 !~ /remote-add/ {
      line = $0
      sub(/^.*flatpak[[:space:]]+install[[:space:]]+/, "", line)
      count = split(line, items, /[[:space:]]+/)
      for (i = 1; i <= count; i++) {
        token = items[i]
        if (token == "" || token == "-y" || token == "--user" || token == "--system") continue
        if (token == "flathub" || token == "fedora") continue
        if (token ~ /^[A-Za-z0-9_]+(\.[A-Za-z0-9_+-]+)+$/) print token
      }
    }
  '
}

# Parse user-scoped Python packages from pip install commands.
parse_python_packages() {
  shell_logical_lines | awk '
    /pip3[[:space:]]+install/ || /python3[[:space:]]+-m[[:space:]]+pip[[:space:]]+install/ {
      line = $0
      sub(/^.*install[[:space:]]+/, "", line)
      count = split(line, items, /[[:space:]]+/)
      for (i = 1; i <= count; i++) {
        token = items[i]
        if (token == "" || token == "--user" || token ~ /^-/) continue
        print token
      }
    }
  '
}

# Parse rustup components from component add commands.
parse_rust_components() {
  shell_logical_lines | awk '
    /rustup[[:space:]]+component[[:space:]]+add/ {
      line = $0
      sub(/^.*rustup[[:space:]]+component[[:space:]]+add[[:space:]]+/, "", line)
      count = split(line, items, /[[:space:]]+/)
      for (i = 1; i <= count; i++) {
        if (items[i] != "") print items[i]
      }
    }
  '
}

# Parse VS Code extension IDs from code install commands.
parse_vscode_extensions() {
  shell_logical_lines | awk '
    /code[[:space:]]+--install-extension/ {
      for (i = 1; i <= NF; i++) {
        if ($i == "--install-extension" && (i + 1) <= NF) print $(i + 1)
      }
    }
  '
}

# Parse the preferred Node/NVM target from install commands.
parse_node_target() {
  shell_logical_lines | awk '
    {
      for (i = 1; i <= NF; i++) {
        if ($i == "nvm" && (i + 2) <= NF && $(i + 1) == "install") {
          print $(i + 2)
          exit
        }
      }
    }
  '
}

# Parse the active guide into global inventory arrays used by checks and installers.
load_inventory() {
  require_guide

  mapfile -t RPM_PACKAGES < <(parse_rpm_packages)
  mapfile -t RPM_PACKAGES < <(printf '%s\n' "${RPM_PACKAGES[@]}" | unique_lines)

  mapfile -t FLATPAK_APPS < <(parse_flatpak_apps | unique_lines)

  mapfile -t PYTHON_PACKAGES < <(parse_python_packages | unique_lines)

  mapfile -t RUST_COMPONENTS < <(parse_rust_components | unique_lines)

  mapfile -t VSCODE_EXTENSIONS < <(parse_vscode_extensions | unique_lines)

  NODE_TARGET="$(parse_node_target)"
  NODE_TARGET="${NODE_TARGET:-node}"
}

# Print a compact summary of what was parsed from the active guide.
show_inventory_summary() {
  log "Inventory from $GUIDE_FILE"
  printf 'RPM packages: %d\n' "${#RPM_PACKAGES[@]}"
  printf 'Flatpak apps: %d\n' "${#FLATPAK_APPS[@]}"
  printf 'Python user packages: %d\n' "${#PYTHON_PACKAGES[@]}"
  printf 'Rust components: %d\n' "${#RUST_COMPONENTS[@]}"
  printf 'VS Code extensions: %d\n' "${#VSCODE_EXTENSIONS[@]}"
  printf 'Node target: %s\n' "$NODE_TARGET"
}
