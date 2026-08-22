#!/bin/zsh

set -eu
setopt PIPE_FAIL

readonly INSTALLER_SOURCE="${(%):-%N}"
readonly DEV_INIT_REPO="${DEV_INIT_REPO:-layatai/dev-init}"
DEV_INIT_REF="${DEV_INIT_REF:-master}"

DRY_RUN=0
CHECK_ONLY=0
TEMP_DIR=""
REPO_ROOT="${DEV_INIT_ROOT:-}"

info() {
  print -P -u2 "%F{blue}==>%f $*"
}

warn() {
  print -P "%F{yellow}Warning:%f $*" >&2
}

fail() {
  print -P "%F{red}Error:%f $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Usage: install-nvim.zsh [options]

Install Neovim and the managed NvChad IDE config.

Options:
  --dry-run   Show the planned setup without changing the machine
  --check     Verify Neovim and the managed config
  --ref REF   Download repository files from a specific Git ref
  -h, --help  Show this help
USAGE
}

cleanup() {
  if [[ -n "$TEMP_DIR" && -d "$TEMP_DIR" ]]; then
    rm -rf -- "$TEMP_DIR"
  fi
}
trap cleanup EXIT INT TERM

while (( $# > 0 )); do
  case "$1" in
    --dry-run)
      DRY_RUN=1
      ;;
    --check)
      CHECK_ONLY=1
      ;;
    --ref)
      shift
      (( $# > 0 )) || fail "--ref requires a value"
      DEV_INIT_REF="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      fail "unknown option: $1"
      ;;
  esac
  shift
done

[[ "$DEV_INIT_REF" =~ '^[A-Za-z0-9._/-]+$' ]] ||
  fail "invalid Git ref: $DEV_INIT_REF"

[[ "$(uname -s)" == "Darwin" ]] || fail "this installer currently supports macOS only"
[[ "$(uname -m)" == "arm64" ]] || fail "this installer currently supports Apple silicon only"

locate_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    print /opt/homebrew/bin/brew
  else
    return 1
  fi
}

activate_brew() {
  local brew_bin
  brew_bin="$(locate_brew)" || return 1
  eval "$("$brew_bin" shellenv)"
}

ensure_repo() {
  if [[ -n "$REPO_ROOT" && -d "$REPO_ROOT/nvim" ]]; then
    return
  fi

  if [[ -f "$INSTALLER_SOURCE" ]]; then
    local source_dir="${INSTALLER_SOURCE:A:h}"
    if [[ -d "$source_dir/nvim" ]]; then
      REPO_ROOT="$source_dir"
      return
    fi
  fi

  TEMP_DIR="${TEMP_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/dev-init-nvim.XXXXXX")}"
  local archive="$TEMP_DIR/dev-init.tar.gz"
  local extracted="$TEMP_DIR/repo"
  local url="https://github.com/${DEV_INIT_REPO}/archive/${DEV_INIT_REF}.tar.gz"
  info "Downloading ${DEV_INIT_REPO}@${DEV_INIT_REF}"
  /usr/bin/curl --fail --silent --show-error --location "$url" --output "$archive" ||
    fail "could not download $url"
  mkdir -p "$extracted"
  /usr/bin/tar -xzf "$archive" -C "$extracted" --strip-components=1 ||
    fail "could not extract $url"
  [[ -d "$extracted/nvim" ]] || fail "archive is missing nvim/"
  REPO_ROOT="$extracted"
}

print_plan() {
  cat <<EOF
Would install:
  - Neovim via Homebrew
  - the managed NvChad IDE config into ~/.config/nvim
  - plugins from nvim/lazy-lock.json
EOF
}

check_setup() {
  local failures=0

  if command -v nvim >/dev/null 2>&1; then
    printf "  %-14s %s\n" "nvim" "ok"
  else
    printf "  %-14s %s\n" "nvim" "missing"
    failures=1
  fi

  if [[ -f "$HOME/.config/nvim/.dev-init" ]]; then
    printf "  %-14s %s\n" "nvim config" "ok"
  else
    printf "  %-14s %s\n" "nvim config" "missing"
    failures=1
  fi

  (( failures == 0 )) || fail "Neovim IDE check found missing requirements"
  info "Neovim IDE check passed"
}

install_neovim() {
  activate_brew || fail "Homebrew is required. Run install.zsh first, or install brew."
  if command -v nvim >/dev/null 2>&1; then
    info "Neovim is already installed"
    return
  fi
  info "Installing Neovim"
  brew install neovim
}

install_config() {
  ensure_repo
  local dest="$HOME/.config/nvim"
  local marker="$dest/.dev-init"

  if [[ -e "$dest" && ! -f "$marker" ]]; then
    local backup="${dest}.backup.$(date +%Y%m%d%H%M%S)"
    mv "$dest" "$backup"
    info "Backed up existing Neovim config to $backup"
  fi

  info "Installing managed Neovim IDE config"
  mkdir -p "$dest/lua/plugins" "$dest/lua/configs"
  local -a files=(
    .dev-init
    .stylua.toml
    init.lua
    lazy-lock.json
    lua/autocmds.lua
    lua/chadrc.lua
    lua/mappings.lua
    lua/options.lua
    lua/plugins/init.lua
    lua/configs/conform.lua
    lua/configs/lazy.lua
    lua/configs/lspconfig.lua
  )
  local file
  for file in "${files[@]}"; do
    [[ -f "$REPO_ROOT/nvim/$file" ]] || fail "missing nvim/$file"
    cp "$REPO_ROOT/nvim/$file" "$dest/$file"
  done
  print -r -- "${DEV_INIT_REPO}@${DEV_INIT_REF}" >"$marker"
}

sync_plugins() {
  command -v nvim >/dev/null 2>&1 || {
    warn "neovim is not on PATH yet; open nvim after this shell reloads"
    return
  }
  info "Syncing Neovim plugins from the lockfile"
  nvim --headless "+Lazy! restore" "+qa" ||
    warn "Neovim plugin restore failed; open nvim later to finish Lazy setup"
}

if (( DRY_RUN == 1 )); then
  print_plan
  exit 0
fi

if (( CHECK_ONLY == 1 )); then
  activate_brew || true
  check_setup
  exit 0
fi

TEMP_DIR="${TEMP_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/dev-init-nvim.XXXXXX")}"
install_neovim
install_config
sync_plugins
hash -r
check_setup
info "Neovim IDE setup complete. Open nvim to finish Mason language-server installs."
