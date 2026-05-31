# common.sh - Shared state, logging, prompting, sudo, and retry primitives.
# SPDX-License-Identifier: GPL-3.0-or-later
#
# The rest of the project uses this module for all cross-cutting behavior. It
# centralizes mutable state, user-facing output helpers, retry policies, sudo
# credential refresh, and small array utilities. Keeping these concerns here
# prevents installer/check modules from each inventing their own error handling.

GUIDE_FILE="${GUIDE_FILE:-$SANSETUP_ROOT/install.sansetup.md}"
NODE_TARGET=""
SUDO_KEEPALIVE_PID=""
VSCODE_USE_PINNED=""

RPM_PACKAGES=()
FLATPAK_APPS=()
PYTHON_PACKAGES=()
RUST_COMPONENTS=()
VSCODE_EXTENSIONS=()
LOCAL_RPM_PATTERNS=(appimagelauncher velocity-bridge)
LOCAL_RPMS=()
FAILED_STEPS=()
SELECTED_ITEMS=()
SELECTED_NODE_TARGET=""

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

export PATH="$HOME/.cargo/bin:$PATH"
if [ -s "$HOME/.nvm/nvm.sh" ]; then
  # shellcheck source=/dev/null
  . "$HOME/.nvm/nvm.sh"
fi

# Return success when stdin/stdout are attached to a terminal.
is_interactive() {
  [ -t 0 ] && [ -t 1 ]
}

COLOR_RESET=""
COLOR_BOLD=""
COLOR_DIM=""
COLOR_BLUE=""
COLOR_CYAN=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_RED=""

# Enable color output when running in an interactive terminal.
setup_colors() {
  if ! is_interactive || [ -n "${NO_COLOR:-}" ] || [ "${TERM:-}" = "dumb" ]; then
    return 0
  fi

  COLOR_RESET=$'\033[0m'
  COLOR_BOLD=$'\033[1m'
  COLOR_DIM=$'\033[2m'
  COLOR_BLUE=$'\033[34m'
  COLOR_CYAN=$'\033[36m'
  COLOR_GREEN=$'\033[32m'
  COLOR_YELLOW=$'\033[33m'
  COLOR_RED=$'\033[31m'
}

setup_colors

# Print a high-level section header.
log() {
  printf '\n%s%s==>%s %s\n' "$COLOR_BOLD" "$COLOR_BLUE" "$COLOR_RESET" "$*"
}

# Print an informational line for work in progress.
info() {
  printf '%sINFO%s: %s\n' "$COLOR_CYAN" "$COLOR_RESET" "$*"
}

# Print a successful check or operation.
ok() {
  printf '%sOK%s: %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$*"
}

# Print a warning to stderr without aborting the workflow.
warn() {
  printf '%sWARN%s: %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*" >&2
}

# Print a missing-item line during verification.
missing() {
  printf '%sMISSING%s: %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*"
}

# Print a fatal error and exit the process.
die() {
  printf '%sERROR%s: %s\n' "$COLOR_RED" "$COLOR_RESET" "$*" >&2
  exit 1
}

# Print a visual separator line for easier scanning.
divider() {
  printf '%s------------------------------------------------------------%s\n' "$COLOR_DIM" "$COLOR_RESET"
}

# Ask a yes/no question with a default answer.
confirm() {
  local prompt="$1"
  local default="${2:-n}"
  local suffix answer

  if ! is_interactive; then
    info "Non-interactive mode: $prompt -> $default"
    [ "$default" = "y" ]
    return
  fi

  if [ "$default" = "y" ]; then
    suffix="Y/n"
  else
    suffix="y/N"
  fi

  while true; do
    read -r -p "$prompt [$suffix]: " answer
    answer="${answer:-$default}"
    case "${answer,,}" in
      y|yes) return 0 ;;
      n|no) return 1 ;;
      *) printf 'Please answer yes or no.\n' ;;
    esac
  done
}

# Pause an interactive menu screen until the user is ready.
pause() {
  if ! is_interactive; then
    return 0
  fi
  read -r -p "Press Enter to continue..." _
}

# Stop the sudo keepalive background job if one was started.
cleanup() {
  if [ -n "$SUDO_KEEPALIVE_PID" ]; then
    kill "$SUDO_KEEPALIVE_PID" >/dev/null 2>&1 || true
  fi
}
trap cleanup EXIT

# Validate sudo access and keep the timestamp fresh during long installs.
ensure_sudo() {
  command -v sudo >/dev/null 2>&1 || die "sudo is required"
  log "Refreshing sudo credentials"
  sudo -v || die "sudo authentication failed"

  if [ -z "$SUDO_KEEPALIVE_PID" ]; then
    while true; do
      sudo -n true >/dev/null 2>&1 || exit
      sleep 60
    done &
    SUDO_KEEPALIVE_PID="$!"
  fi
}

# Run a command with retry handling and ask what to do after final failure.
run_with_retries() {
  local label="$1"
  shift
  local max_attempts=3
  local attempt
  local code=0
  local action

  while true; do
    attempt=1
    while [ "$attempt" -le "$max_attempts" ]; do
      info "$label (attempt $attempt/$max_attempts)"
      "$@"
      code=$?
      if [ "$code" -eq 0 ]; then
        ok "$label"
        return 0
      fi

      warn "$label failed with exit code $code"
      if [ "$attempt" -lt "$max_attempts" ]; then
        warn "Retrying after a short delay. This often handles mirror/server/network errors."
        sleep $((attempt * 5))
      fi
      attempt=$((attempt + 1))
    done

    if ! is_interactive; then
      warn "$label failed after retries in non-interactive mode; skipping"
      FAILED_STEPS+=("$label")
      return 1
    fi

    while true; do
      read -r -p "$label failed. Retry, skip, or abort? [r/s/a]: " action
      case "${action,,}" in
        r|retry) break ;;
        s|skip) FAILED_STEPS+=("$label"); return 1 ;;
        a|abort) die "Aborted after failure: $label" ;;
        *) printf 'Choose r, s, or a.\n' ;;
      esac
    done
  done
}

# Run a command with retries but return failure without prompting.
run_with_retries_no_prompt() {
  local label="$1"
  shift
  local max_attempts=3
  local attempt=1
  local code=0

  while [ "$attempt" -le "$max_attempts" ]; do
    info "$label (attempt $attempt/$max_attempts)"
    "$@"
    code=$?
    if [ "$code" -eq 0 ]; then
      ok "$label"
      return 0
    fi

    warn "$label failed with exit code $code"
    if [ "$attempt" -lt "$max_attempts" ]; then
      warn "Retrying after a short delay. This often handles mirror/server/network errors."
      sleep $((attempt * 5))
    fi
    attempt=$((attempt + 1))
  done

  return "$code"
}

# Return success when an array contains the provided item.
list_contains() {
  local needle="$1"
  shift
  local item

  for item in "$@"; do
    [ "$item" = "$needle" ] && return 0
  done

  return 1
}

# Print non-empty lines once, preserving first-seen order.
unique_lines() {
  awk 'NF && !seen[$0]++'
}

# Print a titled list only when the list has items.
print_list() {
  local title="$1"
  shift
  local items=("$@")

  if [ "${#items[@]}" -eq 0 ]; then
    return 0
  fi

  printf '\n%s (%d):\n' "$title" "${#items[@]}"
  printf '  - %s\n' "${items[@]}"
}
