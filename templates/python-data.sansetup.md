# Python Data and Automation Template

Python workstation profile for automation, APIs, notebooks, data analysis, and package quality tooling.

```bash
sudo dnf install \
  git gh curl jq ripgrep fd-find \
  python3 python3-devel python3-pip python3-virtualenv python-unversioned-command pipx \
  python3-numpy python3-scipy python3-matplotlib python3-pandas \
  gcc gcc-c++ make openssl-devel libffi-devel sqlite-devel code
```

```bash
python3 -m pip install --user \
  ruff black isort mypy pytest pytest-cov ipython jupyterlab notebook \
  pandas polars duckdb matplotlib seaborn scikit-learn \
  httpx requests pydantic typer rich pre-commit
```

Optional hardware/serial automation:

```bash
# sudo dnf install \
#   minicom picocom usbutils python3-hidapi

# python3 -m pip install --user \
#   mpremote pyserial
```

```bash
code --install-extension ms-python.python
code --install-extension ms-python.vscode-pylance
code --install-extension ms-toolsai.jupyter
```
