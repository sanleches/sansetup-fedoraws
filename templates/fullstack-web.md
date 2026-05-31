# Fullstack Web Developer Template

Node, Python API tooling, containers, databases, and common browser/editor utilities.

```bash
sudo dnf install \
  git gh curl jq ripgrep fd-find tmux tree \
  code firefox chromium \
  python3 python3-devel python3-pip python3-virtualenv \
  podman buildah skopeo toolbox podman-compose \
  sqlite postgresql mariadb redis
```

```bash
nvm install node
nvm alias default node
nvm use node
corepack enable
```

```bash
python3 -m pip install --user \
  ruff black pytest httpx fastapi uvicorn pydantic typer rich pre-commit
```

Optional Docker Engine stack:

```bash
# sudo dnf install \
#   docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

```bash
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo
flatpak install flathub \
  com.github.tchx84.Flatseal net.nokyan.Resources
```

```bash
code --install-extension dbaeumer.vscode-eslint
code --install-extension esbenp.prettier-vscode
code --install-extension ms-python.python
code --install-extension ms-vscode-remote.remote-ssh
```
