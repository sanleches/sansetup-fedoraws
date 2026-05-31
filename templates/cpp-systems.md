# C/C++ Systems Developer Template

Native systems development profile for C, C++, debugging, build systems, static analysis, and remote work.

```bash
sudo dnf install \
  git gh curl jq ripgrep fd-find tmux tree \
  gcc gcc-c++ make cmake ninja-build gdb valgrind ccache \
  glibc-devel glibc-static libstdc++-devel pkgconf-pkg-config \
  clang clang-tools-extra lld lldb bear cppcheck include-what-you-use \
  boost-devel fmt-devel spdlog-devel eigen3-devel \
  strace ltrace perf code vim-enhanced neovim
```

Optional documentation and profiling tools:

```bash
# sudo dnf install \
#   doxygen graphviz massif-visualizer hotspot
```

Optional containers and VMs for isolated builds:

```bash
# sudo dnf install \
#   podman buildah skopeo toolbox qemu-kvm virt-manager libvirt-daemon
```

```bash
code --install-extension ms-vscode.cpptools
code --install-extension ms-vscode.cmake-tools
code --install-extension ms-vscode.makefile-tools
code --install-extension llvm-vs-code-extensions.vscode-clangd
```
