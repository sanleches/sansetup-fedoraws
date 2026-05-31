# General Desktop Developer Template

Balanced developer workstation with common CLI tools, editors, browsers, media, and useful Flatpaks.

```bash
sudo dnf install \
  git gh curl wget2-wget jq bat ripgrep fd-find tmux tree rsync \
  zip unzip 7zip openssh-clients openssh-server \
  vim-enhanced neovim code ptyxis gedit gnome-text-editor \
  firefox libreoffice-writer libreoffice-calc libreoffice-impress \
  gnome-tweaks gparted mediawriter remmina rawtherapee \
  vlc vlc-plugins-freeworld ffmpeg tailscale
```

Optional communication and gaming:

```bash
# sudo dnf install \
#   discord steam
```

```bash
flatpak install flathub \
  com.spotify.Client net.nokyan.Resources com.github.tchx84.Flatseal
```

```bash
code --install-extension davidanson.vscode-markdownlint
code --install-extension ms-vscode-remote.remote-ssh
```
