# Architecture

`sansetup-fedoraws` is a Bash application with strict module boundaries.

## Runtime Flow

1. `sansetup.sh` resolves project root and loads modules.
2. `inventory.sh` parses `install.md` into runtime arrays.
3. `checks.sh` verifies current system state.
4. `installers.sh` applies mutating operations.
5. `ui.sh` orchestrates menu and plan execution.

## Module Contracts

- `common.sh`
  - Owns logging, prompt behavior, retry primitives, and shared state arrays.
  - Must not embed inventory-specific parsing rules.

- `policy.sh`
  - Owns policy defaults for required repos, services, groups, and tools.
  - Keeps verification/install policy centralized and auditable.

- `inventory.sh`
  - Owns parsing of machine-readable patterns from `install.md`.
  - Must remain conservative and avoid parsing commands outside shell fences.

- `checks.sh`
  - Read-only checks only.
  - Must not mutate the system.

- `installers.sh`
  - Mutating install and system configuration logic.
  - Uses retry wrappers from `common.sh` and policy from `policy.sh`.

- `ui.sh`
  - Interactive and command-driven orchestration.
  - Must call lower-level modules; avoid duplicating install logic.

## Reliability Rules

- Idempotency first: repeated runs should converge.
- Non-interactive safety: prompts fall back to deterministic defaults.
- Failure isolation: batch DNF install falls back to per-package recovery.
- Post-action verification: `install_plan` always runs `verify_missing`.

## Testing Strategy

- `tests/inventory_parser_test.sh`: parser behavior and edge cases.
- `tests/run.sh`: syntax + parser tests + inventory smoke command.
- CI (`.github/workflows/ci.yml`) executes `tests/run.sh` on push/PR.
