# ui.sh - Interactive menus and high-level setup orchestration.
#
# This module owns user interaction. It lets the lower-level installers and
# checks remain reusable from both interactive and command-oriented flows.

# Ask the user to select all, none, or specific numbered items from a list.
select_items() {
  local prompt="$1"
  shift
  local items=("$@")
  SELECTED_ITEMS=()

  if [ "${#items[@]}" -eq 0 ]; then
    return 0
  fi

  if ! is_interactive; then
    info "Non-interactive mode: selecting all items for '$prompt'"
    SELECTED_ITEMS=("${items[@]}")
    return 0
  fi

  printf '\n%s\n' "$prompt"
  local i
  for i in "${!items[@]}"; do
    printf '  %d. %s\n' "$((i + 1))" "${items[$i]}"
  done

  while true; do
    read -r -p "Choose all, none, or comma-separated numbers [a/n/1,3]: " answer
    case "${answer,,}" in
      a|all|"") SELECTED_ITEMS=("${items[@]}"); return 0 ;;
      n|none) SELECTED_ITEMS=(); return 0 ;;
      *)
        local cleaned number valid=1
        cleaned="${answer// /}"
        IFS=',' read -r -a numbers <<< "$cleaned"
        SELECTED_ITEMS=()
        for number in "${numbers[@]}"; do
          if [[ ! "$number" =~ ^[0-9]+$ ]] || [ "$number" -lt 1 ] || [ "$number" -gt "${#items[@]}" ]; then
            valid=0
            break
          fi
          SELECTED_ITEMS+=("${items[$((number - 1))]}")
        done
        if [ "$valid" -eq 1 ]; then
          mapfile -t SELECTED_ITEMS < <(printf '%s\n' "${SELECTED_ITEMS[@]}" | unique_lines)
          return 0
        fi
        printf 'Invalid selection.\n'
        ;;
    esac
  done
}

# Ask which Node target should be installed through NVM.
choose_node_target() {
  local answer specific

  if ! is_interactive; then
    SELECTED_NODE_TARGET="$NODE_TARGET"
    info "Non-interactive mode: Node target set to '$SELECTED_NODE_TARGET'"
    return 0
  fi

  printf '\nNode install target\n'
  printf '1. Latest current release (node)\n'
  printf '2. Latest LTS release (--lts)\n'
  printf '3. Specific version\n'
  printf '4. install.md target (%s)\n' "$NODE_TARGET"

  while true; do
    read -r -p "Choose Node target [1-4]: " answer
    case "${answer:-1}" in
      1) SELECTED_NODE_TARGET="node"; return 0 ;;
      2) SELECTED_NODE_TARGET="--lts"; return 0 ;;
      3)
        read -r -p "Enter Node version, for example 24, 24.15, 24.15.0, or v24.15.0: " specific
        if node_target_is_exact_version "$specific"; then
          SELECTED_NODE_TARGET="$specific"
          return 0
        fi
        printf 'Invalid Node version.\n'
        ;;
      4) SELECTED_NODE_TARGET="$NODE_TARGET"; return 0 ;;
      *) printf 'Invalid option.\n' ;;
    esac
  done
}

# Execute either a full install plan or a missing-only install plan.
install_plan() {
  local mode="$1"
  local rpms=()
  local flatpaks=()
  local pythons=()
  local rust_components=()
  local vscode_extensions=()

  if [ "$mode" = "all" ]; then
    rpms=("${RPM_PACKAGES[@]}")
    flatpaks=("${FLATPAK_APPS[@]}")
    pythons=("${PYTHON_PACKAGES[@]}")
    rust_components=("${RUST_COMPONENTS[@]}")
    vscode_extensions=("${VSCODE_EXTENSIONS[@]}")
  else
    collect_missing
    rpms=("${MISSING_RPMS[@]}")
    flatpaks=("${MISSING_FLATPAKS[@]}")
    pythons=("${MISSING_PYTHON[@]}")
    rust_components=("${MISSING_RUST[@]}")
    vscode_extensions=("${MISSING_VSCODE[@]}")
  fi

  show_inventory_summary

  if confirm "Install or refresh required repositories/remotes?" "y"; then
    install_repositories
  fi

  select_items "RPM packages to install" "${rpms[@]}"
  if [ "${#SELECTED_ITEMS[@]}" -gt 0 ]; then
    install_rpm_packages "${SELECTED_ITEMS[@]}"
  fi

  select_items "Flatpak apps to install" "${flatpaks[@]}"
  if [ "${#SELECTED_ITEMS[@]}" -gt 0 ]; then
    install_flatpak_apps "${SELECTED_ITEMS[@]}"
  fi

  if confirm "Install or update Rustup stable and selected components?" "y"; then
    select_items "Rust components to install" "${rust_components[@]}"
    install_rust_toolchain "${SELECTED_ITEMS[@]}"
  fi

  if confirm "Install or update NVM and Node?" "y"; then
    choose_node_target
    install_nvm_node "$SELECTED_NODE_TARGET"
  fi

  select_items "Python user packages to install" "${pythons[@]}"
  if [ "${#SELECTED_ITEMS[@]}" -gt 0 ]; then
    install_python_packages "${SELECTED_ITEMS[@]}"
  fi

  select_items "VS Code extensions to install" "${vscode_extensions[@]}"
  if [ "${#SELECTED_ITEMS[@]}" -gt 0 ]; then
    install_vscode_extensions "${SELECTED_ITEMS[@]}"
  fi

  if confirm "Enable services and add user to docker/libvirt groups?" "y"; then
    enable_services_and_groups
  fi

  if confirm "Check for local AppImageLauncher/Velocity Bridge RPMs?" "y"; then
    install_local_rpms
  fi

  log "Post-install verification"
  verify_missing || true

  if [ "${#FAILED_STEPS[@]}" -gt 0 ]; then
    print_list "Steps skipped or failed" "${FAILED_STEPS[@]}"
  fi

  printf '\nNotes:\n'
  printf '  - Run sudo tailscale up when ready to authenticate Tailscale.\n'
  printf '  - Log out and back in, or run newgrp docker, for group changes to affect your current session.\n'
  printf '  - Manual installs still expected: JetBrains Toolbox, Arduino IDE AppImage, LM Studio AppImage.\n'
}

# Show the interactive top-level menu and dispatch the selected action.
main_menu() {
  while true; do
    printf '\nFedora Workstation Setup\n'
    printf '1. Install all from install.md\n'
    printf '2. Install missing only\n'
    printf '3. Verify missing\n'
    printf '4. Show parsed inventory\n'
    printf '5. Quit\n'
    read -r -p "Choose an option [1-5]: " choice

    case "$choice" in
      1) install_plan all; pause ;;
      2) install_plan missing; pause ;;
      3)
        verify_missing || true
        if confirm "Install missing items now?" "n"; then
          install_plan missing
        fi
        pause
        ;;
      4) show_inventory_summary; pause ;;
      5|q|quit|exit) exit 0 ;;
      *) printf 'Invalid option.\n' ;;
    esac
  done
}
