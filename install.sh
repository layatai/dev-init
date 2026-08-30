#!/usr/bin/env bash

set -euo pipefail

DEV_INIT_REPO="${DEV_INIT_REPO:-layatai/dev-init}"
DEV_INIT_REF="${DEV_INIT_REF:-master}"
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""
if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
fi

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*" >&2; }

[[ "$(uname -s)" == Linux ]] || fail "install.sh is the Linux entry point; use install.zsh on macOS"
[[ "$DEV_INIT_REF" =~ ^[A-Za-z0-9._/-]+$ ]] || fail "invalid Git ref: $DEV_INIT_REF"

for arg in "$@"; do
  if [[ "$arg" == --dry-run ]]; then
    cat <<'PLAN'
Would configure this Linux machine with:
  - Linux bootstrap prerequisites from apt, dnf, pacman, or zypper when missing
  - Homebrew and the shared command-line development tools
  - mise with Node LTS, stable Python, and pnpm
  - a managed zsh initialization block
  - Neovim with the managed NvChad IDE config (unless --skip-nvim is used)
  - no macOS GUI casks
PLAN
    exit 0
  fi
done

install_prerequisites() {
  command -v sudo >/dev/null 2>&1 || [[ "$(id -u)" == 0 ]] ||
    fail "sudo is required to install Linux prerequisites"
  local sudo_cmd=()
  if [[ "$(id -u)" != 0 ]]; then
    if sudo -n true 2>/dev/null; then
      :
    elif { exec 3<>/dev/tty; } 2>/dev/null; then
      sudo -v <&3 >&3 2>&3 || fail "sudo authentication failed"
      exec 3>&-
    else
      fail "Linux prerequisites require sudo, but no terminal is attached. Run this from an interactive terminal or install curl, git, zsh, file, procps, and C build tools first."
    fi
    sudo_cmd=(sudo -n)
  fi

  if command -v apt-get >/dev/null 2>&1; then
    "${sudo_cmd[@]}" apt-get update
    "${sudo_cmd[@]}" apt-get install -y build-essential procps curl file git zsh
  elif command -v dnf >/dev/null 2>&1; then
    "${sudo_cmd[@]}" dnf group install -y "Development Tools"
    "${sudo_cmd[@]}" dnf install -y procps-ng curl file git zsh
  elif command -v pacman >/dev/null 2>&1; then
    "${sudo_cmd[@]}" pacman -Sy --needed --noconfirm base-devel procps-ng curl file git zsh
  elif command -v zypper >/dev/null 2>&1; then
    "${sudo_cmd[@]}" zypper --non-interactive install -t pattern devel_basis
    "${sudo_cmd[@]}" zypper --non-interactive install procps curl file git zsh
  else
    fail "unsupported package manager; install curl, git, zsh, procps, file, and C build tools, then retry"
  fi
}

if ! command -v curl >/dev/null 2>&1 || ! command -v git >/dev/null 2>&1 ||
  ! command -v zsh >/dev/null 2>&1 || ! command -v make >/dev/null 2>&1; then
  info "Installing Linux prerequisites"
  install_prerequisites
fi

if [[ -n "$SCRIPT_DIR" && -f "$SCRIPT_DIR/install.zsh" ]]; then
  exec zsh "$SCRIPT_DIR/install.zsh" "$@"
fi

installer_url="https://raw.githubusercontent.com/${DEV_INIT_REPO}/${DEV_INIT_REF}/install.zsh"
temp_installer="$(mktemp "${TMPDIR:-/tmp}/dev-init-install.XXXXXX")"
trap 'rm -f -- "$temp_installer"' EXIT
curl --fail --silent --show-error --location "$installer_url" --output "$temp_installer" ||
  fail "could not download $installer_url"
DEV_INIT_REPO="$DEV_INIT_REPO" DEV_INIT_REF="$DEV_INIT_REF" zsh "$temp_installer" "$@"
