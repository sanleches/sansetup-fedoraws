# Fedora 44 Install Inventory

<!--
SANSETUP INSTALL.MD STANDARD v1

Purpose
- install.md is both human documentation and the machine-readable inventory for sansetup.
- Authors may freely write normal Markdown around supported command blocks.
- sansetup strips standalone HTML comment blocks before parsing, so this standard and any commented examples are ignored at execution time.

Compatibility Contract
- Keep supported inventory commands inside fenced code blocks when possible.
- Use standard shell command shapes listed below; do not rely on prose lists being installed unless explicitly supported.
- Prefer one tool category per section: DNF/RPM, Flatpak, Rust, Node/NVM, Python, VS Code Extensions, Manual Items.
- Keep comments as standalone HTML comment blocks using the normal opening and closing HTML comment markers on their own lines or lines containing only comment text.
- Do not put real install commands inside HTML comments unless they are examples you want ignored.

Supported Inventory Patterns

1. DNF/RPM packages
- Parsed pattern: sudo dnf install [packages]
- Multi-line package blocks using backslash continuation are supported.
- Repo RPM URLs are ignored, so RPM Fusion setup commands do not become packages.
- Local RPM glob examples such as ./appimagelauncher*.rpm are ignored by the package parser.
- Example:
  ```bash
  sudo dnf install \
    git gcc make \
    code tailscale
  ```

2. Optional feature markers
- The phrase Docker / Docker Compose adds:
  docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
- The phrase Clang / Clang++ adds:
  clang clang-tools-extra lld lldb
- These markers exist for short human checklist items that map to standard package groups.

3. Flatpak apps
- Parsed pattern: flatpak install [remote] [app IDs]
- The remote name flathub or fedora is ignored; app IDs are collected.
- flatpak remote-add commands are ignored as setup commands, not apps.
- Example:
  ```bash
  flatpak install flathub com.spotify.Client net.nokyan.Resources
  ```

4. Python user packages
- Parsed patterns:
  pip3 install --user [packages]
  python3 -m pip install --user [packages]
- Options beginning with - are ignored.
- Example:
  ```bash
  pip3 install --user mpremote pyserial
  ```

5. Rust components
- Parsed pattern: rustup component add [components]
- rustup install itself is handled by the tool if rustup is missing.
- Example:
  ```bash
  rustup component add rustfmt clippy rust-analyzer
  ```

6. Node/NVM
- Parsed pattern: nvm install [target]
- Supported targets include node, --lts, lts/*, 24, 24.15, 24.15.0, and v24.15.0.
- If no target is found, sansetup defaults to node, the latest current release.
- The installer still prompts for latest current, latest LTS, a specific version, or the install.md target.
- Example:
  ```bash
  nvm install node
  nvm alias default node
  nvm use node
  corepack enable
  ```

7. VS Code extensions
- Parsed pattern: code --install-extension [extension ID]
- Version pins using @version are allowed for reproducibility.
- sansetup installs latest extension versions by default and asks before using pinned versions.
- Example:
  ```bash
  code --install-extension ms-python.python@2026.4.0
  code --install-extension ms-vscode.cpptools
  ```

8. Manual items
- Anything not matching a supported command pattern is documentation only.
- Manual sections are still useful for reminders such as JetBrains Toolbox, AppImages, local RPM downloads, account logins, and post-install authentication.
- sansetup only automates local AppImageLauncher and Velocity Bridge RPMs when matching files exist in the repo, ~/Downloads, or ~/Documents.

Authoring Recommendations
- Keep native development tools as DNF/RPM packages, not Flatpaks.
- Use Flatpak for self-contained desktop apps where sandboxing is acceptable.
- Prefer latest moving targets for user tools unless reproducibility requires pins.
- Keep hardware-specific drivers, firmware, kernel packages, and machine-specific secrets out of shared inventories.
- Run ./sansetup.sh inventory after editing install.md to confirm the parser sees what you intended.
- Run ./sansetup.sh verify before installing to review missing items.
-->

Generated from the current machine. Hardware-specific drivers, NVIDIA packages, kernel packages, firmware, and Steam games are intentionally excluded. Steam itself is included.

## System

- Fedora Linux 44 Workstation
- Architecture: x86_64

## Important Sources

Enabled package sources found:

- Fedora repos
- RPM Fusion free/nonfree, including Steam
- VS Code repo
- Tailscale repo
- Google Chrome repo, but Chrome is not installed
- PyCharm COPR, but PyCharm itself is installed through JetBrains Toolbox
- Flatpak remotes: fedora, flathub
- Snap is not installed
- Apt/Debian packages are not used

## Repo Setup

Enable RPM Fusion:

```bash
sudo dnf install \
  https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
  https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm
```

Add VS Code repo:

```bash
sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
sudo sh -c 'printf "[code]\nname=Visual Studio Code\nbaseurl=https://packages.microsoft.com/yumrepos/vscode\nenabled=1\nautorefresh=1\ntype=rpm-md\ngpgcheck=1\ngpgkey=https://packages.microsoft.com/keys/microsoft.asc\n" > /etc/yum.repos.d/vscode.repo'
```

Add Tailscale repo:

```bash
sudo dnf config-manager addrepo --from-repofile=https://pkgs.tailscale.com/stable/fedora/tailscale.repo
sudo dnf install tailscale
sudo systemctl enable --now tailscaled
sudo tailscale up
```

## DNF/RPM Software

Main programming tools and desktop apps:

```bash
sudo dnf install \
  gcc gcc-c++ make cmake ninja-build gdb git gh code \
  python3 python3-devel python3-pip python-unversioned-command \
  rust cargo java-25-openjdk-headless \
  podman toolbox qemu-kvm libvirt-daemon gnome-boxes \
  httpd httpd-tools bear protobuf-compiler grpc grpc-cpp \
  minicom python3-hidapi usbutils usbmuxd libimobiledevice lrzsz \
  tmux vim-enhanced bat jq curl wget2-wget xclip xsel wl-clipboard \
  tree rsync zip unzip 7zip openssh-clients openssh-server \
  openvpn openconnect NetworkManager-openvpn-gnome \
  NetworkManager-openconnect-gnome NetworkManager-ssh-gnome \
  NetworkManager-vpnc-gnome \
  firefox libreoffice-writer libreoffice-calc libreoffice-impress \
  gnome-tweaks rawtherapee remmina mediawriter rpi-imager gparted \
  steam discord tailscale ptyxis gedit gnome-text-editor \
  ffmpeg vlc vlc-plugins-freeworld
```

AI/GPU/dev stack found:

```bash
sudo dnf install \
  llama-cpp hipcc rocm-clang rocm-clang-devel rocm-llvm rocm-llvm-devel \
  rocm-runtime rocm-runtime-devel rocm-hip rocblas rocsolver hipblas
```

Locally installed RPMs not from an enabled repo:

- appimagelauncher-3.0.0_beta_2_gha287~96cb937
- velocity-bridge-3.0.4

Install these from their RPM releases:

```bash
sudo dnf install ./appimagelauncher*.rpm
sudo dnf install ./velocity-bridge*.rpm
```

AppImageLauncher upstream:

```text
https://github.com/TheAssassin/AppImageLauncher
```

## Flatpak Apps

Installed Flatpak apps:

- com.bambulab.BambuStudio
- com.mastermindzh.tidal-hifi
- com.spotify.Client
- net.nokyan.Resources

Install:

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub com.bambulab.BambuStudio com.mastermindzh.tidal-hifi com.spotify.Client net.nokyan.Resources
```

## AppImages

Integrated AppImages in `~/Applications`:

- Arduino IDE 2.3.9
- LM Studio 0.4.12+1

Files found:

```text
~/Applications/arduino-ide_2.3.9_Linux_64bit_9df7b23e57dcc2219c4c8b05fa2223b6.AppImage
~/Applications/LM-Studio-0.4.12-1-x64_14cf9472facb4262132e41efe3a1ca22.AppImage
```

Downloaded but not necessarily integrated:

```text
~/Downloads/Bambu_Studio_linux_fedora-v02.06.01.55.AppImage
~/Downloads/imager_2.0.7_amd64.AppImage
```

LM Studio CLI found at:

```text
~/.lmstudio/bin/lms
```

## JetBrains

JetBrains Toolbox installed:

- Toolbox 3.4.3.81140
- CLion 2026.1.1
- PyCharm 2026.1.1
- Rider 2026.1.1

Install Toolbox from:

```text
https://www.jetbrains.com/toolbox-app/
```

Then install CLion, PyCharm, and Rider.

## Rust

Rustup is installed in `~/.cargo/bin`, with stable default.

Install:

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
rustup default stable
rustup component add rustfmt clippy rust-analyzer
```

Cargo-installed binaries: none found.

## Node/NVM

Node is installed through NVM:

- Latest current Node release
- npm from the selected Node release
- global npm packages: corepack, npm

Install:

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/master/install.sh | bash
nvm install node
nvm alias default node
nvm use node
corepack enable
```

## Python User Packages

User-installed Python packages:

- mpremote 1.28.0
- pyserial 3.5

Install:

```bash
pip3 install --user mpremote pyserial
```

## VS Code Extensions

Installed VS Code extensions. Versions are recorded for reproducibility, but `sansetup.sh` installs the latest extension versions by default unless you choose pinned versions when prompted:

```bash
code --install-extension davidanson.vscode-markdownlint@0.61.2
code --install-extension marus25.cortex-debug@1.12.1
code --install-extension mcu-debug.debug-tracker-vscode@0.0.15
code --install-extension mcu-debug.memory-view@0.0.29
code --install-extension mcu-debug.peripheral-viewer@1.6.1
code --install-extension mcu-debug.rtos-views@0.0.15
code --install-extension mechatroner.rainbow-csv@3.24.1
code --install-extension ms-python.debugpy@2026.6.0
code --install-extension ms-python.python@2026.4.0
code --install-extension ms-python.vscode-pylance@2026.2.1
code --install-extension ms-python.vscode-python-envs@1.30.0
code --install-extension ms-vscode-remote.remote-ssh@0.123.0
code --install-extension ms-vscode-remote.remote-ssh-edit@0.87.0
code --install-extension ms-vscode.cmake-tools@1.23.52
code --install-extension ms-vscode.cpp-devtools@0.5.13
code --install-extension ms-vscode.cpptools@1.32.2
code --install-extension ms-vscode.cpptools-extension-pack@1.5.1
code --install-extension ms-vscode.cpptools-themes@2.0.0
code --install-extension ms-vscode.makefile-tools@0.12.17
code --install-extension ms-vscode.remote-explorer@0.5.0
code --install-extension ms-vscode.vscode-serial-monitor@0.13.1
code --install-extension paulober.pico-w-go@4.3.4
code --install-extension raspberry-pi.raspberry-pi-pico@0.20.0
```


Install
- Docker / Docker Compose

- Clang / Clang++
