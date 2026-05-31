# installers.sh - System and user-space installation operations.
# SPDX-License-Identifier: GPL-3.0-or-later
#
# This module performs all mutating work. It wraps DNF, Flatpak, Rustup, NVM,
# pip, VS Code, systemd, and local RPM installs with retry handling. Batch DNF
# installs intentionally use non-prompting retries first so the tool can fall
# back to per-package recovery before asking the user to decide.

# Install packages with DNF and prompt only if all retries fail.
dnf_install() {
  run_with_retries "dnf install ${*}" sudo dnf install -y --setopt=timeout=30 --setopt=retries=3 "$@"
}

# Install packages with DNF using metadata refresh and prompt on final failure.
dnf_install_refresh() {
  run_with_retries "dnf install ${*}" sudo dnf install -y --refresh --setopt=timeout=30 --setopt=retries=3 "$@"
}

# Install packages with DNF using metadata refresh and return failure silently.
dnf_install_refresh_no_prompt() {
  run_with_retries_no_prompt "dnf install ${*}" sudo dnf install -y --refresh --setopt=timeout=30 --setopt=retries=3 "$@"
}

# Upgrade packages with DNF and return failure to caller without prompting.
dnf_upgrade_no_prompt() {
  run_with_retries_no_prompt "dnf upgrade ${*}" sudo dnf upgrade -y --refresh --setopt=timeout=30 --setopt=retries=3 "$@"
}

# Enable an installed DNF repository definition, supporting both DNF5 and DNF4 syntax.
enable_dnf_repo() {
  local repo="$1"

  if repo_enabled "$repo"; then
    ok "$repo repository already enabled"
    return 0
  fi

  run_with_retries "enable $repo repository" sudo dnf config-manager setopt "$repo.enabled=1" || \
    run_with_retries "enable $repo repository" sudo dnf config-manager --set-enabled "$repo"
}

# Configure RPM Fusion, VS Code, Tailscale, and Docker repositories as needed.
install_repositories() {
  ensure_sudo

  dnf_install dnf-plugins-core distribution-gpg-keys || true

  if ! repo_enabled rpmfusion-free || ! repo_enabled rpmfusion-nonfree; then
    dnf_install \
      "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
      "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm" || true
  else
    ok "RPM Fusion repositories already enabled"
  fi

  if inventory_has_rpm steam; then
    enable_dnf_repo "$STEAM_REPO_NAME" || warn "Could not enable $STEAM_REPO_NAME; Steam install may fail."
  fi

  if ! repo_enabled code; then
    run_with_retries "import Microsoft RPM key" sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc || true
    local tmp_repo
    tmp_repo="$(mktemp)" || die "Failed to create temporary repo file"
    printf '%s\n' \
      '[code]' \
      'name=Visual Studio Code' \
      'baseurl=https://packages.microsoft.com/yumrepos/vscode' \
      'enabled=1' \
      'autorefresh=1' \
      'type=rpm-md' \
      'gpgcheck=1' \
      'gpgkey=https://packages.microsoft.com/keys/microsoft.asc' > "$tmp_repo"
    run_with_retries "install VS Code repo file" sudo install -m 0644 "$tmp_repo" /etc/yum.repos.d/vscode.repo || true
    rm -f "$tmp_repo"
  else
    ok "VS Code repository already enabled"
  fi

  if ! repo_enabled tailscale-stable; then
    run_with_retries "add Tailscale repository" sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo || true
  else
    ok "Tailscale repository already enabled"
  fi

  if inventory_has_rpm docker-ce && ! repo_enabled "$DOCKER_REPO_NAME"; then
    run_with_retries "add Docker repository" sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo || true
  elif inventory_has_rpm docker-ce; then
    ok "Docker repository already enabled"
  fi
}

# Sync all packages to repo versions to avoid i686/x86_64 version skew conflicts.
# Steam pulls in ~200+ i686 dependencies; if any x86_64 package has an old
# duplicate installed, the i686 version's files will collide with it.
repair_multilib_conflict() {
  log "Running distro-sync to resolve i686/x86_64 version skew before Steam install"
  run_with_retries_no_prompt "dnf distro-sync" sudo dnf distro-sync -y --refresh --setopt=timeout=30 --setopt=retries=3 || warn "distro-sync did not complete cleanly; continuing with normal install fallback."
}

# Install RPM packages in batch, then recover by installing individually.
install_rpm_packages() {
  local packages=("$@")
  [ "${#packages[@]}" -gt 0 ] || return 0
  ensure_sudo

  if list_contains steam "${packages[@]}"; then
    repair_multilib_conflict
  fi

  if dnf_install_refresh_no_prompt "${packages[@]}"; then
    return 0
  fi

  if list_contains steam "${packages[@]}"; then
    warn "Batch install failed with Steam selected. Running distro-sync once more and retrying."
    repair_multilib_conflict
    if dnf_install_refresh_no_prompt "${packages[@]}"; then
      return 0
    fi
  fi

  warn "Batch RPM install failed. Trying packages individually so one bad package does not block everything."
  local package
  for package in "${packages[@]}"; do
    if rpm_installed "$package"; then
      ok "rpm $package already installed"
    else
      if [ "$package" = "steam" ]; then
        repair_multilib_conflict
      fi
      dnf_install_refresh "$package" || true
    fi
  done
}

# Install Flatpak itself if needed, then add Flathub and install apps.
install_flatpak_apps() {
  local apps=("$@")
  [ "${#apps[@]}" -gt 0 ] || return 0

  if ! command -v flatpak >/dev/null 2>&1; then
    install_rpm_packages flatpak
  fi

  run_with_retries "add Flathub remote" flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo || true
  run_with_retries "install Flatpak apps" flatpak install -y flathub "${apps[@]}" || true
}

# Install Rustup if needed, select stable, and install requested components.
install_rust_toolchain() {
  local components=("$@")

  if ! command -v rustup >/dev/null 2>&1; then
    run_with_retries "install rustup" bash -c "curl --proto '=https' --tlsv1.2 -fsSL --retry 5 --retry-delay 3 https://sh.rustup.rs | sh -s -- -y" || return 1
    export PATH="$HOME/.cargo/bin:$PATH"
  fi

  run_with_retries "set Rust stable default" rustup default stable || true
  if [ "${#components[@]}" -gt 0 ]; then
    run_with_retries "install Rust components" rustup component add "${components[@]}" || true
  fi
}

# Install NVM if needed, then install and select a Node target.
install_nvm_node() {
  local target="${1:-$NODE_TARGET}"
  local alias_target="$target"
  export NVM_DIR="$HOME/.nvm"

  [ -n "$target" ] || return 0

  if [ ! -s "$NVM_DIR/nvm.sh" ]; then
    run_with_retries "install NVM" bash -c "curl -fsSL --retry 5 --retry-delay 3 https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash" || return 1
  fi

  # shellcheck source=/dev/null
  . "$NVM_DIR/nvm.sh"
  if [ "$target" = "--lts" ]; then
    alias_target="lts/*"
  fi
  run_with_retries "install Node $target" nvm install "$target" || true
  run_with_retries "set Node $alias_target default" nvm alias default "$alias_target" || true
  run_with_retries "use Node $target" nvm use "$target" || true
  run_with_retries "enable corepack" corepack enable || true
}

# Install Python packages into the current user's site-packages directory.
install_python_packages() {
  local packages=("$@")
  [ "${#packages[@]}" -gt 0 ] || return 0
  run_with_retries "install Python user packages" python3 -m pip install --user --retries 5 --timeout 30 "${packages[@]}" || true
}

# Install VS Code extensions, optionally preserving pinned versions from guide.
install_vscode_extensions() {
  local extensions=("$@")
  [ "${#extensions[@]}" -gt 0 ] || return 0

  if ! command -v code >/dev/null 2>&1; then
    warn "VS Code command is missing; installing code RPM first."
    install_repositories
    install_rpm_packages code
  fi

  if [ -z "$VSCODE_USE_PINNED" ]; then
    if confirm "Install VS Code extensions at versions pinned in the active guide? Choose no for latest." "n"; then
      VSCODE_USE_PINNED="yes"
    else
      VSCODE_USE_PINNED="no"
    fi
  fi

  local extension
  for extension in "${extensions[@]}"; do
    if [ "$VSCODE_USE_PINNED" != "yes" ]; then
      extension="${extension%@*}"
    fi
    run_with_retries "install VS Code extension $extension" code --install-extension "$extension" || true
  done
}

# Enable required services and add the user to required local groups.
enable_services_and_groups() {
  ensure_sudo
  local service group
  local current_user="${USER:-$(id -un)}"

  for service in "${REQUIRED_SERVICES[@]}"; do
    if service_ready "$service"; then
      ok "$service already enabled and active"
    else
      run_with_retries "enable $service" sudo systemctl enable --now "$service" || true
    fi
  done

  for group in "${REQUIRED_GROUPS[@]}"; do
    if user_in_group "$group"; then
      ok "$current_user is already in $group"
    else
      run_with_retries "add $current_user to $group" sudo usermod -aG "$group" "$current_user" || true
    fi
  done
}

# Search expected locations for manually downloaded local RPM releases.
find_local_rpms() {
  local pattern path
  LOCAL_RPMS=()
  shopt -s nullglob
  for pattern in "${LOCAL_RPM_PATTERNS[@]}"; do
    for path in \
      "$SANSETUP_ROOT"/${pattern}*.rpm \
      "$HOME/Downloads"/${pattern}*.rpm \
      "$HOME/Documents"/${pattern}*.rpm; do
      LOCAL_RPMS+=("$path")
    done
  done
  shopt -u nullglob
}

# Offer to install local RPMs if matching files are present.
install_local_rpms() {
  find_local_rpms
  if [ "${#LOCAL_RPMS[@]}" -eq 0 ]; then
    warn "No local AppImageLauncher or Velocity Bridge RPMs found in repo, Downloads, or Documents."
    return 0
  fi

  select_items "Local RPM files found. Which should be installed?" "${LOCAL_RPMS[@]}"
  if [ "${#SELECTED_ITEMS[@]}" -gt 0 ]; then
    install_rpm_packages "${SELECTED_ITEMS[@]}"
  fi
}
