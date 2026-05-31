# Sansetup Developer Inventory Template

This is the canonical starter guide for `sansetup`.

First-use workflow:

1. Copy this file to `install.sansetup.md`.
2. Edit `install.sansetup.md` and uncomment only the stacks, apps, and tools you want.
3. Run `./sansetup.sh inventory` to verify the parsed plan.
4. Run `./sansetup.sh` and press Enter to install all parsed items, or choose numbered subsets.

Rules in short:

- `install.sansetup.md` is local and intentionally untracked.
- Keep executable inventory inside fenced `bash` code blocks.
- Lines beginning with `#` inside `bash` fences are disabled inventory.
- Uncomment the command starter and the continuation lines you want to enable.
- Comment every physical line to disable a multiline command.
- Prose, checklists, links, and `text` fences are documentation only.
- VS Code extension versions may be pinned with `@version`; install defaults to latest unless you choose pinned versions when prompted.

## Repository Setup

Repository/remotes are managed by `sansetup` during install flows. These commands
are reference only, so they live in a `text` fence and are not parsed as
inventory.

```text
sudo dnf install \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
sudo dnf config-manager addrepo --from-repofile=https://download.docker.com/linux/fedora/docker-ce.repo
```

## Core Workstation Tools

```bash
# sudo dnf install \
#   git gh curl wget2-wget jq bat tmux tree rsync ripgrep fd-find \
#   zip unzip 7zip openssh-clients openssh-server xclip xsel wl-clipboard \
#   vim-enhanced neovim code gnome-tweaks gparted mediawriter
```

## C Development

Base C toolchain:

```bash
# sudo dnf install \
#   gcc make cmake ninja-build gdb valgrind \
#   glibc-devel glibc-static pkgconf-pkg-config bear
```

Specialized C tooling:

```bash
# sudo dnf install \
#   ccache strace ltrace perf clang clang-tools-extra lld lldb \
#   cppcheck flawfinder
```

## C++ Development

Base C++ toolchain:

```bash
# sudo dnf install \
#   gcc-c++ libstdc++-devel cmake ninja-build gdb \
#   boost-devel fmt-devel spdlog-devel eigen3-devel
```

Specialized C++ tooling:

```bash
# sudo dnf install \
#   clang clang-tools-extra lld lldb ccache cppcheck \
#   include-what-you-use
```

## Python Development

Base Python stack:

```bash
# sudo dnf install \
#   python3 python3-devel python3-pip python3-virtualenv python-unversioned-command pipx

# python3 -m pip install --user \
#   ruff black isort mypy pytest pytest-cov ipython pre-commit
```

Data/science additions:

```bash
# sudo dnf install \
#   python3-numpy python3-scipy python3-matplotlib python3-pandas

# python3 -m pip install --user \
#   jupyterlab notebook polars duckdb httpx pydantic rich typer
```

## Java and JVM Development

Base Java stack:

```bash
# sudo dnf install \
#   java-21-openjdk java-21-openjdk-devel maven gradle
```

Compatibility/diagnostic additions:

```bash
# sudo dnf install \
#   java-17-openjdk java-17-openjdk-devel visualvm
```

## Go Development

```bash
# sudo dnf install \
#   golang delve
```

## Rust Development

Rustup installation and `stable` selection are handled by `sansetup` when Rust
components are selected.

```bash
# rustup component add rustfmt clippy rust-analyzer
```

## Node.js and Web Development

NVM installation, default aliasing, `nvm use`, and `corepack enable` are handled
by `sansetup` when Node is selected.

```bash
# nvm install node
```

Optional web tooling helpers:

```bash
# sudo dnf install \
#   nodejs npm

# python3 -m pip install --user \
#   nodeenv
```

## Linux Kernel and Module Development

Base kernel/module stack:

```bash
# sudo dnf install \
#   kernel-devel kernel-headers elfutils-libelf-devel \
#   make gcc gcc-c++ bc bison flex dwarves openssl-devel ncurses-devel perl
```

Tracing/debugging additions:

```bash
# sudo dnf install \
#   perf trace-cmd bpftrace bpftool systemtap crash kdump-utils
```

Virtualized kernel testing:

```bash
# sudo dnf install \
#   qemu-kvm qemu-img virt-install virt-manager libvirt-daemon gnome-boxes
```

## Containers, Virtualization, and Cloud

Rootless/container-native tooling:

```bash
# sudo dnf install \
#   podman buildah skopeo toolbox podman-compose
```

Docker Engine stack:

```bash
# sudo dnf install \
#   docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

Kubernetes/cloud CLIs:

```bash
# sudo dnf install \
#   kubernetes-client helm
```

## Embedded, Hardware, and Serial Tooling

```bash
# sudo dnf install \
#   minicom picocom openocd dfu-util usbutils hidapi \
#   python3-hidapi lrzsz protobuf-compiler grpc grpc-cpp

# python3 -m pip install --user \
#   mpremote pyserial
```

## Desktop Applications (RPM)

```bash
# sudo dnf install \
#   firefox libreoffice-writer libreoffice-calc libreoffice-impress \
#   rawtherapee remmina vlc vlc-plugins-freeworld ffmpeg \
#   tailscale discord steam ptyxis gedit gnome-text-editor
```

## Desktop Applications (Flatpak)

The Flathub remote is added automatically when Flatpak apps are selected.

```bash
# flatpak install flathub \
#   com.spotify.Client net.nokyan.Resources com.discordapp.Discord \
#   com.github.tchx84.Flatseal org.videolan.VLC \
#   org.mozilla.firefox com.visualstudio.code
```

## VS Code Extensions

Common developer extensions:

```bash
# code --install-extension ms-vscode.cpptools
# code --install-extension ms-vscode.cmake-tools
# code --install-extension ms-python.python
# code --install-extension ms-python.vscode-pylance
# code --install-extension rust-lang.rust-analyzer
# code --install-extension redhat.java
# code --install-extension golang.go
# code --install-extension ms-vscode-remote.remote-ssh
# code --install-extension davidanson.vscode-markdownlint
```

Pinned example. Leave commented unless you explicitly require this version:

```bash
# code --install-extension ms-python.vscode-pylance@2026.2.1
```

## Manual Reminders

- Authenticate Tailscale after install: `sudo tailscale up`.
- Log out and back in after docker/libvirt group changes.
- Keep hardware-specific drivers, secrets, and machine-only local files out of shared guides.
