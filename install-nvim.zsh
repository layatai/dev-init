#!/bin/zsh

set -eu
setopt PIPE_FAIL

readonly INSTALLER_SOURCE="${(%):-%N}"
readonly DEV_INIT_REPO="${DEV_INIT_REPO:-layatai/dev-init}"
DEV_INIT_REF="${DEV_INIT_REF:-master}"
readonly OS_NAME="$(uname -s)"

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

[[ "$OS_NAME" == "Darwin" || "$OS_NAME" == "Linux" ]] ||
  fail "this installer supports macOS and Linux only"
if [[ "$OS_NAME" == "Darwin" && "$(uname -m)" != "arm64" ]]; then
  fail "this installer currently supports Apple silicon Macs only"
fi

locate_brew() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
  elif [[ -x "$HOME/.homebrew/bin/brew" ]]; then
    print "$HOME/.homebrew/bin/brew"
  elif [[ -x /opt/homebrew/bin/brew ]]; then
    print /opt/homebrew/bin/brew
  elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    print /home/linuxbrew/.linuxbrew/bin/brew
  else
    return 1
  fi
}

activate_brew() {
  local brew_bin
  brew_bin="$(locate_brew)" || return 1
  eval "$("$brew_bin" shellenv)"
}

login_has() {
  local name="$1"
  # A real login shell sources .zprofile. `ssh host 'cmd'` and `curl | zsh` do not.
  zsh -l -c "command -v ${(q)name}" >/dev/null 2>&1
}

ensure_login_path() {
  activate_brew || return 0
  if login_has nvim; then
    return
  fi

  local brew_bin brew_bin_dir
  brew_bin="$(locate_brew)" || return 0
  brew_bin_dir="${brew_bin:h}"
  mkdir -p "$HOME/.local/bin"
  local name
  for name in nvim tree-sitter; do
    if [[ -x "$brew_bin_dir/$name" ]]; then
      ln -sfn "$brew_bin_dir/$name" "$HOME/.local/bin/$name"
    fi
  done

  if login_has nvim; then
    info "Linked nvim onto the login PATH via ~/.local/bin"
    return
  fi

  local zprofile="$HOME/.zprofile"
  local start="# >>> dev-init-nvim >>>"
  local end="# <<< dev-init-nvim <<<"
  if [[ -f "$zprofile" ]] && grep -Fq "$start" "$zprofile"; then
    warn "nvim is installed at $brew_bin_dir/nvim but is still not on the login PATH"
    return
  fi

  info "Adding $brew_bin_dir to login PATH in .zprofile"
  if [[ -f "$zprofile" ]]; then
    cp "$zprofile" "$zprofile.backup.$(date +%Y%m%d%H%M%S)"
  fi
  {
    print
    print -- "$start"
    print -- "path+=(${(q)brew_bin_dir})"
    print -- "$end"
  } >>"$zprofile"
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
Would install and fully bootstrap the Neovim IDE:
  - Neovim, tree-sitter-cli, and Node (npm) via Homebrew
  - put nvim on the login PATH (Homebrew or ~/.local/bin)
  - rust-analyzer and rustfmt via rustup, when rustup is present
  - the managed NvChad IDE config into ~/.config/nvim
  - Lazy plugins from nvim/lazy-lock.json
  - Mason language servers, formatters, and CodeLLDB
  - Treesitter parsers for Rust, TypeScript, Lua, and related filetypes
EOF
}

check_setup() {
  local failures=0
  local name
  local -a mason_bins=(
    lua-language-server stylua typescript-language-server prettier
    vscode-json-language-server vscode-html-language-server
    vscode-css-language-server vscode-eslint-language-server
    taplo bash-language-server marksman codelldb
  )

  if login_has nvim; then
    printf "  %-14s %s\n" "nvim" "ok"
  else
    printf "  %-14s %s\n" "nvim" "missing"
    failures=1
  fi

  if login_has tree-sitter; then
    printf "  %-14s %s\n" "tree-sitter" "ok"
  else
    printf "  %-14s %s\n" "tree-sitter" "missing"
    failures=1
  fi

  if login_has npm; then
    printf "  %-14s %s\n" "npm" "ok"
  else
    printf "  %-14s %s\n" "npm" "missing"
    failures=1
  fi

  if [[ -f "$HOME/.config/nvim/.dev-init" ]]; then
    printf "  %-14s %s\n" "nvim config" "ok"
  else
    printf "  %-14s %s\n" "nvim config" "missing"
    failures=1
  fi

  if [[ -d "$HOME/.local/share/nvim/lazy/lazy.nvim" ]]; then
    printf "  %-14s %s\n" "lazy plugins" "ok"
  else
    printf "  %-14s %s\n" "lazy plugins" "missing"
    failures=1
  fi

  for name in "${mason_bins[@]}"; do
    if [[ -x "$HOME/.local/share/nvim/mason/bin/$name" ]]; then
      printf "  %-14s %s\n" "$name" "ok"
    else
      printf "  %-14s %s\n" "$name" "missing"
      failures=1
    fi
  done

  if command -v rustup >/dev/null 2>&1; then
    if command -v rust-analyzer >/dev/null 2>&1; then
      printf "  %-14s %s\n" "rust-analyzer" "ok"
    else
      printf "  %-14s %s\n" "rust-analyzer" "missing"
      failures=1
    fi
  fi

  (( failures == 0 )) || fail "Neovim IDE check found missing requirements"
  info "Neovim IDE check passed"
}

install_neovim() {
  activate_brew || fail "Homebrew is required. Run install.zsh first, or install brew."
  local -a formulas=()
  command -v nvim >/dev/null 2>&1 || formulas+=(neovim)
  command -v tree-sitter >/dev/null 2>&1 || formulas+=(tree-sitter-cli)
  command -v npm >/dev/null 2>&1 || formulas+=(node)
  if (( ${#formulas} == 0 )); then
    info "Neovim, tree-sitter-cli, and Node are already installed"
    return
  fi
  info "Installing ${formulas[*]}"
  brew install "${formulas[@]}"
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
    bootstrap.lua
  )
  local file
  for file in "${files[@]}"; do
    [[ -f "$REPO_ROOT/nvim/$file" ]] || fail "missing nvim/$file"
    cp "$REPO_ROOT/nvim/$file" "$dest/$file"
  done
  print -r -- "${DEV_INIT_REPO}@${DEV_INIT_REF}" >"$marker"
}

install_rust_tools() {
  if ! command -v rustup >/dev/null 2>&1; then
    warn "rustup is not installed; skip rust-analyzer/rustfmt (rustaceanvim needs rust-analyzer on PATH)"
    return
  fi
  info "Installing rust-analyzer and rustfmt"
  rustup component add rust-analyzer rustfmt
}

sync_ide() {
  activate_brew || true
  command -v nvim >/dev/null 2>&1 || fail "neovim is not on PATH"
  local dest="$HOME/.config/nvim"

  info "Syncing Neovim plugins from the lockfile"
  nvim --headless "+Lazy! restore" "+qa" ||
    fail "Neovim plugin restore failed"

  info "Installing Mason tools and Treesitter parsers"
  nvim --headless \
    "+luafile $dest/bootstrap.lua" \
    "+qa" ||
    fail "Neovim IDE bootstrap failed"
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
install_rust_tools
install_config
sync_ide
ensure_login_path
hash -r
check_setup
info "Neovim IDE setup complete. Open a new terminal if nvim is not on PATH yet."
