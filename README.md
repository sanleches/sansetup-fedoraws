# sansetup-fedoraws

Menu-driven Fedora Workstation setup tool driven by a Markdown inventory file.

`sansetup` treats Markdown as a small pseudo-language: users copy a template,
uncomment the stacks/tools they want, and run the script. The active local file is
`install.md`, which is intentionally ignored by git so every developer can keep a
personal setup plan.

## First Use

```bash
cd ~/repos/sansetup-fedoraws
cp install.template.md install.md
```

Edit `install.md`, uncomment the sections you want, then verify what the parser
will install:

```bash
./sansetup.sh inventory
```

Run the interactive installer:

```bash
./sansetup.sh
```

At item prompts, pressing Enter selects all shown items. You can still choose
`none` or comma-separated numbers such as `1,3,8`.

## Commands

```bash
./sansetup.sh inventory
./sansetup.sh verify
./sansetup.sh install-missing
./sansetup.sh install-all
```

Use a specific Markdown guide instead of local `install.md`:

```bash
./sansetup.sh --guide templates/cpp-systems.md inventory
./sansetup.sh --guide ~/team-fedora-workstation.md install-all
```

## Templates

- `install.template.md`: canonical root starter template. Copy this to `install.md` before first use.
- `templates/general-desktop-dev.md`: general desktop developer workstation.
- `templates/cpp-systems.md`: C/C++ systems development.
- `templates/python-data.md`: Python data, automation, and API work.
- `templates/kernel-lab.md`: Linux kernel/module lab.
- `templates/fullstack-web.md`: Node/Python/container web development.

## Markdown Standard

The full pseudo-language specification is documented in `docs/MARKDOWN_STANDARD.md`.

Short version:

- Only fenced shell blocks are executable inventory.
- Lines starting with `#` inside shell blocks are disabled inventory.
- Uncommenting a line enables it.
- Prose, lists, links, and `text` code fences are documentation only.
- DNF/RPM, Flatpak, Python pip, Rustup components, NVM Node targets, and VS Code extensions are parsed.
- VS Code extension pins (`publisher.extension@version`) are supported, but install defaults to latest unless the user opts into pinned versions.

## Design

Project layout:

```text
sansetup.sh                    Thin entrypoint and command dispatcher
install.template.md            Canonical starter inventory template
install.md                     Local active inventory, gitignored
templates/*.md                 Prebuilt developer profile inventories
docs/ARCHITECTURE.md           Runtime architecture notes
docs/MARKDOWN_STANDARD.md      Markdown pseudo-language specification
lib/sansetup/common.sh         Shared state, logging, prompts, sudo, retries
lib/sansetup/policy.sh         Central policy defaults for repos/services/groups/tools
lib/sansetup/inventory.sh      Markdown inventory parser
lib/sansetup/checks.sh         Read-only verification logic
lib/sansetup/installers.sh     Mutating install/service/group operations
lib/sansetup/ui.sh             Menu and install-plan orchestration
```

## Failure Handling

DNF, Flatpak, curl-based installers, pip, Rustup, NVM, and VS Code extension
installs are wrapped in retry logic. Batch DNF installs use non-interactive
retries first, then fall back to per-package installs so one bad package does not
block the entire setup.

When stdin/stdout are not attached to a TTY, prompts fall back to deterministic
defaults so scripted use does not hang.

## Quality Gates

Run the repository checks before opening a change:

```bash
./tests/run.sh
```

This runs Bash syntax validation, parser behavior tests, and template inventory
smoke checks.
