# sansetup-fedoraws

Menu-driven Fedora Workstation setup tool driven by a readable
Pseudo-Markdown inventory file.

## What This Is

`sansetup` turns a documented setup guide into an install plan for Fedora
Workstation. You describe the packages, Flatpaks, language tooling, and VS Code
extensions you want in a Markdown file, then run the script to verify or install
that inventory.

The guide is intentionally human-first. It can contain prose, sections, links,
notes, and examples. The script only parses a small set of supported shell-like
commands from fenced code blocks. It does not blindly execute arbitrary Markdown
or every shell command in the file.

## Pseudo-Markdown

The guide format is normal Markdown plus a small `sansetup` pseudo-language.
The `.sansetup.md` suffix means "this renders as Markdown, but some fenced shell
commands are machine-readable inventory."

This gives the project a practical balance:

- Markdown stays readable in editors and GitHub.
- Users customize setup by uncommenting lines instead of editing Bash arrays.
- The parser remains conservative and predictable.
- Unsupported or risky shell snippets can remain as documentation without being run.

The full language specification lives in `docs/PSEUDOMARKDOWN_STANDARD.md`.

## File Roles

- `install.sansetup.md`: your local active setup plan. It is ignored by git.
- `install.template.sansetup.md`: canonical starter template tracked by the repo.
- `templates/*.sansetup.md`: ready-to-use profile templates.
- `docs/PSEUDOMARKDOWN_STANDARD.md`: exact parser and authoring rules.

## First Use

```bash
cd ~/repos/sansetup-fedoraws
cp install.template.sansetup.md install.sansetup.md
```

Edit `install.sansetup.md`, uncomment the stacks/tools you want, then verify
what the parser sees:

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

Use a specific guide instead of local `install.sansetup.md`:

```bash
./sansetup.sh --guide templates/cpp-systems.sansetup.md inventory
./sansetup.sh --guide ~/team-fedora-workstation.sansetup.md install-all
```

## How Parsing Works

Only shell fences are parsed:

````markdown
```bash
sudo dnf install git gcc make
```
````

Accepted shell fence labels are empty fences, `bash`, `sh`, `shell`, and `zsh`.
Documentation-only fences such as `text`, `json`, `ini`, and `toml` are ignored.
Normal Markdown prose, links, checklists, tables, and headings are documentation.

The parser extracts known inventory tokens and then the installer runs known
implementation functions. For example, a `flatpak install` line contributes app
IDs to the Flatpak install list; it is not executed verbatim from the guide.

## Supported Inventory Commands

DNF/RPM packages:

```bash
sudo dnf install git gcc make
```

Flatpak apps:

```bash
flatpak install flathub com.spotify.Client net.nokyan.Resources
```

Python user packages:

```bash
python3 -m pip install --user ruff pytest
pip3 install --user mpremote pyserial
```

Rust components:

```bash
rustup component add rustfmt clippy rust-analyzer
```

Node/NVM target:

```bash
nvm install node
```

Node is only installed when an active `nvm install` command exists in the guide.
Use `nvm install node` for the latest current release, `nvm install --lts` for
latest LTS, or a numeric version such as `nvm install 24.15.0`. If the guide has
no active Node/NVM command, `sansetup` does not install Node and does not require
`npm`.

VS Code extensions:

```bash
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance@2026.2.1
```

VS Code extension pins use `publisher.extension@version`. Verification ignores
pin versions and install defaults to latest unless you choose pinned versions
when prompted.

## Comments And Multiline Rules

Inside shell fences, `#` disables one physical line:

```bash
# sudo dnf install git gcc
```

To disable a multiline command, comment every physical line:

```bash
# sudo dnf install \
#   git gcc make \
#   cmake ninja-build
```

Active multiline commands are supported when continuation lines use `\`:

```bash
sudo dnf install \
  git gcc make \
  cmake ninja-build
```

Standalone Markdown HTML comments are stripped before parsing:

````markdown
<!--
This entire block is ignored by the parser.

```bash
sudo dnf install example-package
```
-->
````

There is no custom Bash-style multiline comment syntax in the DSL.

## Templates

- `install.template.sansetup.md`: canonical root starter template.
- `templates/general-desktop-dev.sansetup.md`: general desktop developer workstation.
- `templates/cpp-systems.sansetup.md`: C/C++ systems development.
- `templates/python-data.sansetup.md`: Python data, automation, and API work.
- `templates/kernel-lab.sansetup.md`: Linux kernel/module lab.
- `templates/fullstack-web.sansetup.md`: Node/Python/container web development.

Use a profile directly:

```bash
./sansetup.sh --guide templates/fullstack-web.sansetup.md inventory
```

Or copy one into your local active guide:

```bash
cp templates/python-data.sansetup.md install.sansetup.md
```

## Safety Model

The guide is not a shell script. `sansetup` parses supported command shapes into
inventory arrays, deduplicates tokens, verifies current state, and runs installer
functions that are maintained in `lib/sansetup/installers.sh`.

Unsupported shell commands in active shell fences are ignored by the runtime
parser, but tracked templates are linted by `./tests/run.sh` so reusable profiles
stay strict and ready to use. Manual/reference commands should be prose, `text`
fences, or fully commented shell lines.

## Design

Project layout:

```text
sansetup.sh                         Thin entrypoint and command dispatcher
install.template.sansetup.md        Canonical starter inventory template
install.sansetup.md                 Local active inventory, gitignored
templates/*.sansetup.md             Prebuilt developer profile inventories
docs/ARCHITECTURE.md                Runtime architecture notes
docs/PSEUDOMARKDOWN_STANDARD.md     Pseudo-Markdown language specification
lib/sansetup/common.sh              Shared state, logging, prompts, sudo, retries
lib/sansetup/policy.sh              Central policy defaults for repos/services/groups/tools
lib/sansetup/inventory.sh           Pseudo-Markdown inventory parser
lib/sansetup/checks.sh              Read-only verification logic
lib/sansetup/installers.sh          Mutating install/service/group operations
lib/sansetup/ui.sh                  Menu and install-plan orchestration
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

This runs Bash syntax validation, parser behavior tests, template compliance
linting, and template inventory smoke checks.

## License

This project is licensed under the GNU General Public License v3.0 or later
(`GPL-3.0-or-later`). See `LICENSE` for the full license text.
