# checks.sh - Verification predicates and missing-item reporting.
#
# This module contains read-only checks. It does not modify the system and is
# safe to run repeatedly. Installers call collect_missing before install-missing
# flows, and users can call verify directly to understand what remains.

# Return success when a DNF repository is enabled.
repo_enabled() {
  local repo="$1"
  command -v dnf >/dev/null 2>&1 || return 1
  dnf repolist --enabled 2>/dev/null | awk 'NR > 1 { print $1 }' | grep -qx "$repo"
}

# Normalize extension IDs by removing optional pinned versions and lowercasing.
normalize_vscode_extension_id() {
  printf '%s\n' "${1%@*}" | tr '[:upper:]' '[:lower:]'
}

# Return success when an RPM package is installed.
rpm_installed() {
  command -v rpm >/dev/null 2>&1 || return 1
  rpm -q "$1" >/dev/null 2>&1
}

# Return success when a Flatpak app is installed.
flatpak_installed() {
  command -v flatpak >/dev/null 2>&1 || return 1
  flatpak info "$1" >/dev/null 2>&1
}

# Return success when a Python package is visible to the current user.
python_package_installed() {
  command -v python3 >/dev/null 2>&1 || return 1
  python3 -m pip show "$1" >/dev/null 2>&1
}

# Return success when a Rustup component is installed.
rust_component_installed() {
  command -v rustup >/dev/null 2>&1 && rustup component list --installed 2>/dev/null | grep -qx "$1"
}

# Return success when a VS Code extension is installed, ignoring pinned version.
vscode_extension_installed() {
  local extension_id="$1"
  extension_id="${extension_id%@*}"
  command -v code >/dev/null 2>&1 && code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]' | grep -qx "${extension_id,,}"
}

# Return success when a Node target is an explicit numeric version.
node_target_is_exact_version() {
  [[ "$1" =~ ^v?[0-9]+(\.[0-9]+){0,2}$ ]]
}

# Normalize a numeric Node version to node's v-prefixed display format.
normalize_node_version() {
  local target="$1"
  if [[ "$target" == v* ]]; then
    printf '%s\n' "$target"
  else
    printf 'v%s\n' "$target"
  fi
}

# Return success when a systemd service is enabled and currently active.
service_ready() {
  command -v systemctl >/dev/null 2>&1 || return 1
  systemctl is-enabled "$1" >/dev/null 2>&1 && systemctl is-active "$1" >/dev/null 2>&1
}

# Return success when the current user belongs to the named group.
user_in_group() {
  local current_user="${USER:-$(id -un)}"
  id -nG "$current_user" | tr ' ' '\n' | grep -qx "$1"
}

# Clear all missing-item arrays before a fresh verification pass.
reset_missing() {
  MISSING_REPOS=()
  MISSING_RPMS=()
  MISSING_FLATPAKS=()
  MISSING_PYTHON=()
  MISSING_RUST=()
  MISSING_VSCODE=()
  MISSING_SERVICES=()
  MISSING_GROUPS=()
  MISSING_USER_TOOLS=()
  WARNINGS=()
}

# Populate missing-item arrays from the current system state.
collect_missing() {
  reset_missing

  local repo package app component extension service group tool
  local required_repos=("${REQUIRED_REPOS[@]}")
  local enabled_repos=()
  local installed_rust_components=()
  local installed_vscode_extensions=()

  if inventory_has_rpm docker-ce; then
    required_repos+=("$DOCKER_REPO_NAME")
  fi

  if command -v dnf >/dev/null 2>&1; then
    mapfile -t enabled_repos < <(dnf repolist --enabled 2>/dev/null | awk 'NR > 1 { print $1 }')
  else
    MISSING_USER_TOOLS+=(dnf)
  fi

  if command -v rustup >/dev/null 2>&1; then
    mapfile -t installed_rust_components < <(rustup component list --installed 2>/dev/null)
  fi

  if command -v code >/dev/null 2>&1; then
    mapfile -t installed_vscode_extensions < <(code --list-extensions 2>/dev/null | tr '[:upper:]' '[:lower:]')
  fi

  for repo in "${required_repos[@]}"; do
    if [ "${#enabled_repos[@]}" -eq 0 ]; then
      MISSING_REPOS+=("$repo")
    elif ! list_contains "$repo" "${enabled_repos[@]}"; then
      MISSING_REPOS+=("$repo")
    fi
  done

  for package in "${RPM_PACKAGES[@]}"; do
    rpm_installed "$package" || MISSING_RPMS+=("$package")
  done

  if command -v flatpak >/dev/null 2>&1; then
    if ! flatpak remotes --columns=name 2>/dev/null | grep -qx flathub; then
      MISSING_REPOS+=("flathub")
    fi
    for app in "${FLATPAK_APPS[@]}"; do
      flatpak_installed "$app" || MISSING_FLATPAKS+=("$app")
    done
    if flatpak info org.videolan.vlc >/dev/null 2>&1; then
      WARNINGS+=("Flatpak VLC is installed; this inventory uses native RPM VLC.")
    fi
  else
    MISSING_USER_TOOLS+=(flatpak)
    MISSING_FLATPAKS+=("${FLATPAK_APPS[@]}")
  fi

  for package in "${PYTHON_PACKAGES[@]}"; do
    python_package_installed "$package" || MISSING_PYTHON+=("$package")
  done

  if command -v rustup >/dev/null 2>&1; then
    for component in "${RUST_COMPONENTS[@]}"; do
      list_contains "$component" "${installed_rust_components[@]}" || MISSING_RUST+=("$component")
    done
  else
    MISSING_USER_TOOLS+=(rustup)
    MISSING_RUST+=("${RUST_COMPONENTS[@]}")
  fi

  if command -v node >/dev/null 2>&1; then
    if node_target_is_exact_version "$NODE_TARGET" && [ "$(node -v 2>/dev/null)" != "$(normalize_node_version "$NODE_TARGET")" ]; then
      WARNINGS+=("Node is $(node -v 2>/dev/null), expected $(normalize_node_version "$NODE_TARGET").")
    fi
  else
    MISSING_USER_TOOLS+=(node)
  fi

  for tool in "${REQUIRED_USER_TOOLS[@]}"; do
    command -v "$tool" >/dev/null 2>&1 || MISSING_USER_TOOLS+=("$tool")
  done

  if command -v code >/dev/null 2>&1; then
    for extension in "${VSCODE_EXTENSIONS[@]}"; do
      if ! list_contains "$(normalize_vscode_extension_id "$extension")" "${installed_vscode_extensions[@]}"; then
        MISSING_VSCODE+=("$extension")
      fi
    done
  else
    MISSING_VSCODE+=("${VSCODE_EXTENSIONS[@]}")
  fi

  for service in "${REQUIRED_SERVICES[@]}"; do
    service_ready "$service" || MISSING_SERVICES+=("$service")
  done

  for group in "${REQUIRED_GROUPS[@]}"; do
    user_in_group "$group" || MISSING_GROUPS+=("$group")
  done

  mapfile -t MISSING_REPOS < <(printf '%s\n' "${MISSING_REPOS[@]}" | unique_lines)
  mapfile -t MISSING_RPMS < <(printf '%s\n' "${MISSING_RPMS[@]}" | unique_lines)
  mapfile -t MISSING_FLATPAKS < <(printf '%s\n' "${MISSING_FLATPAKS[@]}" | unique_lines)
  mapfile -t MISSING_PYTHON < <(printf '%s\n' "${MISSING_PYTHON[@]}" | unique_lines)
  mapfile -t MISSING_RUST < <(printf '%s\n' "${MISSING_RUST[@]}" | unique_lines)
  mapfile -t MISSING_VSCODE < <(printf '%s\n' "${MISSING_VSCODE[@]}" | unique_lines)
  mapfile -t MISSING_SERVICES < <(printf '%s\n' "${MISSING_SERVICES[@]}" | unique_lines)
  mapfile -t MISSING_GROUPS < <(printf '%s\n' "${MISSING_GROUPS[@]}" | unique_lines)
  mapfile -t MISSING_USER_TOOLS < <(printf '%s\n' "${MISSING_USER_TOOLS[@]}" | unique_lines)
  mapfile -t WARNINGS < <(printf '%s\n' "${WARNINGS[@]}" | unique_lines)
}

# Print a verification report and return success only when required checks pass.
verify_missing() {
  collect_missing

  log "Missing items"
  print_list "Repositories/remotes" "${MISSING_REPOS[@]}"
  print_list "RPM packages" "${MISSING_RPMS[@]}"
  print_list "Flatpak apps" "${MISSING_FLATPAKS[@]}"
  print_list "Python user packages" "${MISSING_PYTHON[@]}"
  print_list "Rust components" "${MISSING_RUST[@]}"
  print_list "VS Code extensions" "${MISSING_VSCODE[@]}"
  print_list "Services" "${MISSING_SERVICES[@]}"
  print_list "Groups" "${MISSING_GROUPS[@]}"
  print_list "User tools" "${MISSING_USER_TOOLS[@]}"
  print_list "Warnings" "${WARNINGS[@]}"

  local total_missing=$((
    ${#MISSING_REPOS[@]} + ${#MISSING_RPMS[@]} + ${#MISSING_FLATPAKS[@]} +
    ${#MISSING_PYTHON[@]} + ${#MISSING_RUST[@]} + ${#MISSING_VSCODE[@]} +
    ${#MISSING_SERVICES[@]} + ${#MISSING_GROUPS[@]} + ${#MISSING_USER_TOOLS[@]}
  ))

  if [ "$total_missing" -eq 0 ]; then
    ok "Nothing required is missing"
    return 0
  fi

  missing "$total_missing required checks are missing"
  return 1
}
