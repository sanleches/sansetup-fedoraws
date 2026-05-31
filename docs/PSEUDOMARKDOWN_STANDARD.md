# Sansetup Pseudo-Markdown Standard

This document defines the `sansetup` Markdown pseudo-language. The goal is to let
developers maintain setup inventories as readable Markdown while giving the tool
a deterministic, conservative parser.

## Mental Model

A guide file is both documentation and executable inventory.

- Markdown prose explains intent.
- Shell fenced code blocks contain parseable inventory commands.
- `#` comments inside shell fences disable inventory lines.
- Users enable work by uncommenting supported command lines.

The default active guide is `install.sansetup.md`. It is local-only and ignored
by git. Tracked starter material lives in `install.template.sansetup.md` and
`templates/*.sansetup.md`.

## File Roles

- `install.template.sansetup.md`: canonical starter template.
- `install.sansetup.md`: local active inventory, not tracked.
- `templates/*.sansetup.md`: prebuilt profile templates that may be copied or used with `--guide`.

## Parse Boundary

Only shell fences are parsed:

````markdown
```bash
sudo dnf install git gcc
```
````

Accepted shell fence labels:

- empty fence: ```
- `bash`
- `sh`
- `shell`
- `zsh`

Documentation-only fences such as `text`, `json`, `ini`, or `toml` are ignored.

## Comment Semantics

Inside shell fences, a line beginning with `#` is disabled inventory. There is
no Bash heredoc-style or block-comment syntax in the DSL; use one `#` per
disabled line.

```bash
# sudo dnf install git gcc
```

Uncommenting enables the command:

```bash
sudo dnf install git gcc
```

Inline comments are allowed after active tokens:

```bash
sudo dnf install git gcc  # base build tools
```

For active multiline commands, every active continuation line must be
uncommented:

```bash
sudo dnf install \
  git gcc make \
  cmake ninja-build
```

To disable an entire multiline command, comment every physical line in that
command:

```bash
# sudo dnf install \
#   git gcc make \
#   cmake ninja-build
```

If the command starter is commented, the whole command is disabled even if later
lines are uncommented incorrectly. Keep multiline blocks consistently
commented/uncommented.

Markdown HTML comments are stripped before parsing when they are standalone
blocks. This is useful for authoring notes that may contain command examples:

````markdown
<!--
This whole block is ignored by the parser.

```bash
sudo dnf install example-package
```
-->
````

HTML comments should start on a line beginning with `<!--` and end on a line
containing `-->`. Do not rely on inline HTML comments inside active shell fences.

Tracked ready-to-use templates must keep active shell fences limited to supported
command shapes. Manual/reference commands should be prose, `text` fences, or
commented lines.

## Supported Command Shapes

### DNF/RPM Packages

```bash
sudo dnf install git gcc make
```

Multiline:

```bash
sudo dnf install \
  git gcc make \
  cmake ninja-build
```

Rules:

- `sudo`, `dnf`, `dnf5`, `install`, and options beginning with `-` are ignored as package tokens.
- HTTP/HTTPS RPM repo URLs are ignored as packages.
- Local `./*.rpm` examples are ignored by the package parser.
- Tokens are deduplicated while preserving first-seen order.

### Flatpak Apps

```bash
flatpak install flathub com.spotify.Client net.nokyan.Resources
```

Multiline:

```bash
flatpak install flathub \
  com.spotify.Client \
  net.nokyan.Resources
```

Rules:

- `flathub` and `fedora` are treated as remotes and ignored as app IDs.
- `flatpak remote-add` is setup documentation and is ignored as an app install.
- App IDs must look like dotted reverse-DNS identifiers.

### Python User Packages

```bash
pip3 install --user ruff pytest
python3 -m pip install --user black isort mypy
```

Rules:

- Options beginning with `-` are ignored.
- Packages are installed with `python3 -m pip install --user` during execution.

### Rust Components

```bash
rustup component add rustfmt clippy rust-analyzer
```

Rules:

- Rustup installation/default stable selection is handled by installers.
- Components are deduplicated.

### Node/NVM Target

```bash
nvm install node
```

Supported targets include:

- `node`
- `--lts`
- `lts/*`
- numeric versions such as `24`, `24.15`, `24.15.0`, or `v24.15.0`

If no active `nvm install` command is found, the parser defaults to `node`.

### VS Code Extensions

```bash
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance@2026.2.1
```

Rules:

- Pins use `publisher.extension@version`.
- Verification ignores pin versions and checks the extension ID.
- Install defaults to latest extension versions unless the user chooses pinned versions when prompted.

## Legacy Markers

The parser still supports these un-commented prose markers for compatibility:

- `Docker / Docker Compose`
- `Clang / Clang++`

New templates should prefer explicit package commands instead of markers.

Commented marker lines are ignored:

```markdown
# Docker / Docker Compose
- # Docker / Docker Compose
```

## Non-Goals

The parser deliberately does not execute arbitrary shell. It extracts inventory
tokens from supported command shapes and then runs known installer functions.

Unsupported examples:

```bash
sudo dnf groupinstall "Development Tools"
sudo npm install -g pnpm
curl https://example.invalid/script.sh | bash
```

These may remain in the guide as manual notes, but they are not parsed unless a
supported command shape is added to the parser and tests.

## Validation Workflow

After editing a guide:

```bash
./sansetup.sh --guide path/to/guide.sansetup.md inventory
./sansetup.sh --guide path/to/guide.sansetup.md verify
```

For the default local guide:

```bash
./sansetup.sh inventory
./sansetup.sh verify
```

## Authoring Rules

- Keep hardware-specific drivers, firmware, secrets, and personal credentials out of shared templates.
- Prefer native RPMs for developer tools and libraries.
- Prefer Flatpak for self-contained GUI apps where sandboxing is acceptable.
- Put base language stacks before specialized/niche add-ons.
- Keep one package ecosystem per section when possible.
- Run `./tests/run.sh` after changing parser behavior or tracked templates.
