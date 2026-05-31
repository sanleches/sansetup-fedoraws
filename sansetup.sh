#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-3.0-or-later
# sansetup.sh - Fedora Workstation setup entrypoint.
#
# This file is intentionally small. It discovers the project root, loads the
# modular Bash implementation from lib/sansetup, parses a Markdown setup guide
# (`install.sansetup.md` by default), and dispatches the requested command. Keeping this
# file thin makes the command stable while allowing the implementation to be
# maintained in focused modules.
#
# Supported commands:
#   menu             Interactive menu, used when no command is provided.
#   install-all      Offer to install every item parsed from the active guide.
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
  printf 'Usage: %s [--guide <file>] [menu|install-all|install-missing|verify|inventory]\n' "$0"
}

# Parse CLI options and resolve the requested top-level command.
parse_args() {
  COMMAND="menu"

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --guide)
        [ "$#" -ge 2 ] || die "--guide requires a file path"
        GUIDE_FILE="$2"
        shift 2
        ;;
      -h|--help|help)
        COMMAND="help"
        shift
        ;;
      menu|install-all|install-missing|verify|inventory)
        COMMAND="$1"
        shift
        ;;
      *)
        die "Unknown argument: $1"
        ;;
    esac
  done
}

# Parse the inventory once, then dispatch the requested top-level command.
main() {
  parse_args "$@"

  if [ "$COMMAND" = "help" ]; then
    usage
    return 0
  fi

  load_inventory

  case "$COMMAND" in
    menu) main_menu ;;
    install-all) install_plan all ;;
    install-missing) install_plan missing ;;
    verify) verify_missing ;;
    inventory) show_inventory_summary ;;
    *) usage; exit 2 ;;
  esac
}

main "$@"
