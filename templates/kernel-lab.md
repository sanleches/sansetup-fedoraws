# Linux Kernel and Module Lab Template

Kernel, driver, module, tracing, and virtualized test lab profile.

```bash
sudo dnf install \
  git curl jq tmux tree \
  kernel-devel kernel-headers elfutils-libelf-devel \
  make gcc gcc-c++ bc bison flex dwarves openssl-devel ncurses-devel perl \
  gdb ccache clang lld llvm strace ltrace perf trace-cmd bpftrace bpftool \
  systemtap crash kdump-utils code vim-enhanced
```

Virtualized testing stack:

```bash
sudo dnf install \
  qemu-kvm qemu-img virt-install virt-manager libvirt-daemon gnome-boxes
```

Optional C/C++ user-space helper stack:

```bash
# sudo dnf install \
#   cmake ninja-build valgrind clang-tools-extra lldb bear cppcheck
```

```bash
code --install-extension ms-vscode.cpptools
code --install-extension ms-vscode.cmake-tools
```
