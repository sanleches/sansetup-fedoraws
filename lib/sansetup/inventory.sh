# inventory.sh - Parse install.md into runtime inventory arrays.
#
# install.md is the source of truth for this project. This module extracts the
# package, Flatpak, Rust, Python, VS Code, and Node targets from documented code
# blocks rather than duplicating the inventory in Bash. The parser is deliberately
# conservative: it only consumes recognized command shapes and ignores repo URLs,
# local RPM glob examples, unrelated shell commands, and standalone HTML comment
# blocks used to document the install.md authoring standard.

# Ensure the configured Markdown guide exists before parsing it.
require_guide() {
  [ -f "$GUIDE_FILE" ] || die "Guide file not found: $GUIDE_FILE"
  [ -r "$GUIDE_FILE" ] || die "Guide file is not readable: $GUIDE_FILE"
}

# Print install.md with standalone HTML comment blocks removed.
#
# The project uses HTML comments in install.md to embed authoring rules beside
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

# Emit install.md contents after comment stripping.
inventory_stream() {
  strip_markdown_comments "$GUIDE_FILE"
}

# Parse DNF package tokens from supported command shapes.
parse_rpm_packages() {
  inventory_stream | awk '
    function emit(line, items, count, i, token) {
      gsub(/\\/, "", line)
      gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
      if (line == "") return

      count = split(line, items, /[[:space:]]+/)
      for (i = 1; i <= count; i++) {
        token = items[i]
        if (token == "" || token == "sudo" || token == "dnf" || token == "install") continue
        if (token ~ /^-/) continue
        if (token ~ /^https?:/) continue
        if (token ~ /^\.\//) continue
        if (token ~ /\.rpm$/) continue
        if (token ~ /^\$/) continue
        print token
      }
    }
    /^```/ {
      marker = $0
      sub(/^```[[:space:]]*/, "", marker)
      if (!in_fence) {
        in_fence = 1
        in_shell_code = (marker == "" || marker ~ /^(bash|sh|shell|zsh)$/)
      } else {
        in_fence = 0
        in_shell_code = 0
      }
      dnf_continues = 0
      next
    }
    !in_shell_code { next }
    /sudo[[:space:]]+dnf[[:space:]]+install/ {
      dnf_continues = ($0 ~ /\\[[:space:]]*$/)
      sub(/^.*sudo[[:space:]]+dnf[[:space:]]+install[[:space:]]+/, "")
      emit($0)
      next
    }
    dnf_continues {
      dnf_continues = ($0 ~ /\\[[:space:]]*$/)
      emit($0)
    }
  '

  if inventory_stream | grep -q 'Docker / Docker Compose'; then
    printf '%s\n' docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
  fi

  if inventory_stream | grep -q 'Clang / Clang++'; then
    printf '%s\n' clang clang-tools-extra lld lldb
  fi
}

# Parse Flatpak app IDs from supported command shapes.
parse_flatpak_apps() {
  inventory_stream | awk '
    /^```/ {
      marker = $0
      sub(/^```[[:space:]]*/, "", marker)
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
    /flatpak[[:space:]]+install/ && $0 !~ /remote-add/ {
      line = $0
      sub(/^.*flatpak[[:space:]]+install[[:space:]]+/, "", line)
      gsub(/\\/, "", line)
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
  inventory_stream | awk '
    /^```/ {
      marker = $0
      sub(/^```[[:space:]]*/, "", marker)
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
  inventory_stream | awk '
    /^```/ {
      marker = $0
      sub(/^```[[:space:]]*/, "", marker)
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
  inventory_stream | awk '
    /^```/ {
      marker = $0
      sub(/^```[[:space:]]*/, "", marker)
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
    /code[[:space:]]+--install-extension/ {
      for (i = 1; i <= NF; i++) {
        if ($i == "--install-extension" && (i + 1) <= NF) print $(i + 1)
      }
    }
  '
}

# Parse the preferred Node/NVM target from install commands.
parse_node_target() {
  inventory_stream | awk '
    /^```/ {
      marker = $0
      sub(/^```[[:space:]]*/, "", marker)
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

# Parse install.md into global inventory arrays used by checks and installers.
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

# Print a compact summary of what was parsed from install.md.
show_inventory_summary() {
  log "Inventory from $GUIDE_FILE"
  printf 'RPM packages: %d\n' "${#RPM_PACKAGES[@]}"
  printf 'Flatpak apps: %d\n' "${#FLATPAK_APPS[@]}"
  printf 'Python user packages: %d\n' "${#PYTHON_PACKAGES[@]}"
  printf 'Rust components: %d\n' "${#RUST_COMPONENTS[@]}"
  printf 'VS Code extensions: %d\n' "${#VSCODE_EXTENSIONS[@]}"
  printf 'Node target: %s\n' "$NODE_TARGET"
}
