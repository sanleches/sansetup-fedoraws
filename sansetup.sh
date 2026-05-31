#!/usr/bin/env bash
# sansetup.sh - Fedora Workstation setup entrypoint.
#
# This file is intentionally small. It discovers the project root, loads the
# modular Bash implementation from lib/sansetup, parses install.md as the setup
# inventory, and dispatches the requested command. Keeping this file thin makes
# the command stable while allowing the implementation to be maintained in
# focused modules.
#
# Supported commands:
#   menu             Interactive menu, used when no command is provided.
#   install-all      Offer to install every item parsed from install.md.
#   install-missing  Verify the system, then offer to install missing items.
#   verify           Print missing items without changing the system.
#   inventory        Print the parsed inventory summary.

set -uo pipefail

SANSETUP_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export SANSETUP_ROOT

# Load modules in dependency order: shared state/helpers first, then inventory,
# checks, installers, and finally UI orchestration.
# shellcheck source=lib/sansetup/common.sh
. "$SANSETUP_ROOT/lib/sansetup/common.sh"
# shellcheck source=lib/sansetup/policy.sh
. "$SANSETUP_ROOT/lib/sansetup/policy.sh"
# shellcheck source=lib/sansetup/inventory.sh
. "$SANSETUP_ROOT/lib/sansetup/inventory.sh"
# shellcheck source=lib/sansetup/checks.sh
. "$SANSETUP_ROOT/lib/sansetup/checks.sh"
# shellcheck source=lib/sansetup/installers.sh
. "$SANSETUP_ROOT/lib/sansetup/installers.sh"
# shellcheck source=lib/sansetup/ui.sh
. "$SANSETUP_ROOT/lib/sansetup/ui.sh"

# Print command-line usage for non-interactive operation.
usage() {
  printf 'Usage: %s [menu|install-all|install-missing|verify|inventory]\n' "$0"
}

# Parse the inventory once, then dispatch the requested top-level command.
main() {
  load_inventory

  case "${1:-menu}" in
    menu) main_menu ;;
    install-all) install_plan all ;;
    install-missing) install_plan missing ;;
    verify) verify_missing ;;
    inventory) show_inventory_summary ;;
    -h|--help|help) usage ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"
