# policy.sh - Central policy defaults for verification and install operations.

# Repository and remote names expected on a fully provisioned workstation.
REQUIRED_REPOS=(
  fedora
  updates
  rpmfusion-free
  rpmfusion-nonfree
  code
  tailscale-stable
)

# Services that should be enabled and active.
REQUIRED_SERVICES=(
  tailscaled.service
  docker.service
  libvirtd.service
  sshd.service
)

# Groups the current user should belong to.
REQUIRED_GROUPS=(
  docker
  libvirt
)

# User tools expected to be available on PATH.
REQUIRED_USER_TOOLS=(
  npm
  code
  docker
  tailscale
)

# Optional repo required only when Docker packages are requested.
DOCKER_REPO_NAME="docker-ce-stable"

# Return success when the inventory includes a specific RPM package token.
inventory_has_rpm() {
  local package="$1"
  list_contains "$package" "${RPM_PACKAGES[@]}"
}
