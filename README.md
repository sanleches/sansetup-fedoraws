# sansetup-fedoraws

Menu-driven Fedora Workstation setup tool generated from `install.md`.

## Usage

```bash
cd ~/repos/sansetup-fedoraws
./sansetup.sh
```

Use a custom Markdown guide instead of `install.md`:

```bash
./sansetup.sh --guide templates/install.template.md inventory
./sansetup.sh --guide ~/my-dev-setup.md install-all
```

Non-interactive entry points:

```bash
./sansetup.sh inventory
./sansetup.sh verify
./sansetup.sh install-missing
./sansetup.sh install-all
```

## Repository Workflow

- Architecture details: `docs/ARCHITECTURE.md`
- Contribution guide: `CONTRIBUTING.md`
- One-command checks: `./tests/run.sh` or `make check`
- Reusable template: `templates/install.template.md`

## Design

`install.md` is the inventory source of truth. The tool parses package lists,
Flatpak app IDs, Python packages, Rust components, VS Code extensions, and the
NVM Node target from that file at runtime.

The top of `install.md` also contains the authoring standard inside an HTML
comment block. `sansetup` strips those comment blocks before parsing, so the
documentation can include examples without those examples becoming install work.

Project layout:

```text
sansetup.sh                  Thin entrypoint and command dispatcher
install.md                   Human-editable setup inventory
lib/sansetup/common.sh       Shared state, logging, prompts, sudo, retries
lib/sansetup/policy.sh       Central policy defaults for repos/services/groups/tools
lib/sansetup/inventory.sh    Markdown inventory parser
lib/sansetup/checks.sh       Read-only verification logic
lib/sansetup/installers.sh   Mutating install/service/group operations
lib/sansetup/ui.sh           Menu and install-plan orchestration
```

## install.md Standard

The `install.md` format is intentionally Markdown-first. Authors can write normal
prose, notes, links, and manual instructions. Only the command shapes below are
machine-readable.

Compatibility rules:

- Keep supported inventory commands inside fenced code blocks when possible.
- Use `#` to comment/uncomment commands inside shell fences; commented lines are ignored by the parser.
- Use one tool category per section: DNF/RPM, Flatpak, Rust, Node/NVM, Python, VS Code Extensions, Manual Items.
- Use standalone HTML comment blocks for embedded authoring notes; the parser removes those blocks before reading commands.
- Do not put real install commands inside comments unless they are examples that should be ignored.
- Run `./sansetup.sh inventory` after editing to confirm the parsed counts look right.
- Run `./sansetup.sh verify` before installing to review what is missing.

Supported DNF/RPM pattern:

```bash
sudo dnf install \
  git gcc make \
  code tailscale
```

DNF notes:

- Multi-line package blocks using backslash continuation are supported.
- Repo RPM URLs are ignored, so RPM Fusion setup commands do not become packages.
- Local RPM glob examples such as `./appimagelauncher*.rpm` are ignored by the package parser.

Supported optional feature markers:

- `Docker / Docker Compose` adds `docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`.
- `Clang / Clang++` adds `clang clang-tools-extra lld lldb`.

Supported Flatpak pattern:

```bash
flatpak install flathub com.spotify.Client net.nokyan.Resources
```

Flatpak notes:

- The remote name `flathub` or `fedora` is ignored.
- `flatpak remote-add` commands are ignored as setup commands, not apps.

Supported Python user package patterns:

```bash
pip3 install --user mpremote pyserial
python3 -m pip install --user mpremote pyserial
```

Python notes:

- Options beginning with `-` are ignored.
- Packages are installed into the current user's site-packages directory.

Supported Rust component pattern:

```bash
rustup component add rustfmt clippy rust-analyzer
```

Rust notes:

- Rustup itself is installed by the tool if it is missing.
- The tool selects the stable toolchain before adding components.

Supported Node/NVM pattern:

```bash
nvm install node
nvm alias default node
nvm use node
corepack enable
```

Node target notes:

- Supported targets include `node`, `--lts`, `lts/*`, `24`, `24.15`, `24.15.0`, and `v24.15.0`.
- If no target is found, `sansetup` defaults to `node`, the latest current release.
- During install, the tool still prompts for latest current, latest LTS, a specific version, or the `install.md` target.

Supported VS Code extension pattern:

```bash
code --install-extension ms-python.python@2026.4.0
code --install-extension ms-vscode.cpptools
```

VS Code notes:

- Version pins with `@version` are allowed for reproducibility.
- The tool installs latest extension versions by default and asks before using pinned versions.

Manual item notes:

- Anything not matching a supported command pattern is documentation only.
- Manual sections are useful for JetBrains Toolbox, AppImages, local RPM downloads, account logins, and post-install authentication.
- The tool only automates local AppImageLauncher and Velocity Bridge RPMs when matching files exist in the repo, `~/Downloads`, or `~/Documents`.

Authoring recommendations:

- Keep native development tools as DNF/RPM packages, not Flatpaks.
- Use Flatpak for self-contained desktop apps where sandboxing is acceptable.
- Prefer latest moving targets for user tools unless reproducibility requires pins.
- Keep hardware-specific drivers, firmware, kernel packages, and machine-specific secrets out of shared inventories.

## Failure Handling

DNF, Flatpak, curl-based installers, pip, Rustup, NVM, and VS Code extension
installs are wrapped in retry logic. Batch DNF installs use non-interactive
retries first, then fall back to per-package installs so one bad package does not
block the entire setup.

When stdin/stdout are not attached to a TTY, prompts automatically fall back to
safe defaults (for example, confirmation prompts use their documented default,
and item selectors choose all items). This allows scripted use without hanging
on interactive input.

Steam can pull `i686` multimedia dependencies. The tool runs a targeted
PipeWire/WirePlumber upgrade before Steam installs to reduce multilib conflicts
such as an installed `x86_64` PipeWire version being older than the incoming
`i686` package version.

## Version Policy

Node defaults to latest current through NVM (`nvm install node`). During install,
you can choose latest current, latest LTS, a specific version, or the target from
`install.md`.

VS Code extension versions remain recorded in `install.md` for reproducibility,
but the tool installs latest extension versions by default unless you choose the
pinned versions when prompted.

Selection prompts default to installing all listed items when you press Enter;
you can still choose `none` or numbered subsets.

## Manual Items

The tool intentionally does not fully automate every item. It reports manual
items such as JetBrains Toolbox, Arduino IDE AppImage, LM Studio AppImage, and
local AppImageLauncher/Velocity Bridge RPMs when those files are unavailable.

## Quality Gates

Run the repository checks before opening a change:

```bash
./tests/run.sh
```

This runs:

- Bash syntax validation for all runtime modules.
- Inventory parser behavior tests (including comment stripping and multiline
  command parsing).
# sansetup-fedoraws
