# Contributing

Thanks for improving `sansetup-fedoraws`.

## Principles

- Keep `install.sansetup.md` as the local inventory source of truth.
- Keep `sansetup.sh` thin; place behavior in `lib/sansetup/*.sh` modules.
- Prefer deterministic and idempotent operations.
- Keep interactive prompts safe by default.
- Preserve backwards-compatible command entry points.

## Local Validation

Run before opening a pull request:

```bash
./tests/run.sh
```

This validates Bash syntax and parser behavior.

## Editing Standards

- Use Bash-compatible syntax (`#!/usr/bin/env bash`).
- Quote variables unless intentional word splitting is required.
- Avoid hidden side effects in check-only functions.
- Add comments only for non-obvious behavior.
- Keep module responsibilities clear:
  - `common.sh`: shared primitives
  - `policy.sh`: verification/install policy defaults
  - `inventory.sh`: parsing
  - `checks.sh`: read-only verification
  - `installers.sh`: mutating actions
  - `ui.sh`: interaction and orchestration

## Pull Request Checklist

- [ ] Changed behavior is documented in `README.md`.
- [ ] Parser-impacting changes include or update tests.
- [ ] No unrelated formatting-only churn.
- [ ] `./tests/run.sh` passes.
