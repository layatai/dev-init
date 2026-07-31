#!/bin/zsh

set -eu
setopt PIPE_FAIL

readonly INSTALLER_SOURCE="${(%):-%N}"
readonly DEV_INIT_REPO="${DEV_INIT_REPO:-layatai/dev-init}"
DEV_INIT_REF="${DEV_INIT_REF:-master}"
readonly BLOCK_START="# >>> dev-init >>>"
readonly BLOCK_END="# <<< dev-init <<<"

DRY_RUN=0
CHECK_ONLY=0
NON_INTERACTIVE=0
SKIP_CASKS=0
TEMP_DIR=""

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
Usage: install.zsh [options]

Options:
  --dry-run          Show the planned setup without changing the machine
  --check            Verify the expected tools and configuration
  --non-interactive  Do not prompt, open applications, or start authentication
  --skip-casks       Skip OrbStack, Visual Studio Code, and iTerm2
  --ref REF          Download repository files from a specific Git ref
  -h, --help         Show this help
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
    --non-interactive)
      NON_INTERACTIVE=1
      ;;
    --skip-casks)
      SKIP_CASKS=1
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

if ! xcode-select -p >/dev/null 2>&1; then
  fail "Xcode Command Line Tools are required. Run: xcode-select --install"
fi

is_interactive() {
  (( NON_INTERACTIVE == 0 )) && [[ -r /dev/tty && -w /dev/tty ]]
}

confirm() {
  local prompt="$1"
  local default="${2:-y}"
  local answer

  is_interactive || return 1
  if [[ "$default" == "y" ]]; then
    print -n "$prompt [Y/n] " >/dev/tty
  else
    print -n "$prompt [y/N] " >/dev/tty
  fi
  IFS= read -r answer </dev/tty || return 1
  answer="${answer:l}"
  [[ -z "$answer" ]] && answer="$default"
  [[ "$answer" == "y" || "$answer" == "yes" ]]
}

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

script_brewfile() {
  local source_dir=""

  if [[ -f "$INSTALLER_SOURCE" ]]; then
    source_dir="${INSTALLER_SOURCE:A:h}"
    if [[ -f "$source_dir/Brewfile" ]]; then
      print "$source_dir/Brewfile"
      return
    fi
  fi

  TEMP_DIR="${TEMP_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/dev-init.XXXXXX")}"
  local destination="$TEMP_DIR/Brewfile"
  local url="https://raw.githubusercontent.com/${DEV_INIT_REPO}/${DEV_INIT_REF}/Brewfile"
  info "Downloading Brewfile from ${DEV_INIT_REPO}@${DEV_INIT_REF}"
  /usr/bin/curl --fail --silent --show-error --location "$url" --output "$destination" ||
    fail "could not download $url"
  print "$destination"
}

effective_brewfile() {
  local source_file="$1"
  if (( SKIP_CASKS == 0 )); then
    print "$source_file"
    return
  fi

  TEMP_DIR="${TEMP_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/dev-init.XXXXXX")}"
  local destination="$TEMP_DIR/Brewfile.no-casks"
  /usr/bin/awk '!/^cask /' "$source_file" >"$destination"
  print "$destination"
}

print_plan() {
  cat <<EOF
Would configure this Apple-silicon Mac with:
  - Homebrew
  - Git, Git LFS, GitHub CLI
  - ripgrep, fd, fzf, jq, yq, bat, eza, tree
  - cmake, ninja, pkgconf, shellcheck, shfmt, direnv, just
  - curl, wget, CA certificates, OpenSSL, sevenzip
  - mise, uv, Node LTS, stable Python, pnpm
  - a managed zsh initialization block
EOF
  if (( SKIP_CASKS == 0 )); then
    print "  - OrbStack, Visual Studio Code, iTerm2"
  else
    print "  - GUI casks skipped"
  fi
  if (( NON_INTERACTIVE == 0 )); then
    print "  - optional interactive SSH and GitHub authentication"
  fi
}

check_setup() {
  local failures=0
  local command_name
  local -a commands=(
    brew git git-lfs gh rg fd fzf jq yq bat eza tree
    cmake ninja pkgconf shellcheck shfmt direnv just
    curl wget 7zz mise uv node python pnpm
  )

  info "Checking command-line tools"
  for command_name in "${commands[@]}"; do
    if command -v "$command_name" >/dev/null 2>&1 ||
      { [[ "$command_name" == (node|python|pnpm) ]] &&
        command -v mise >/dev/null 2>&1 &&
        mise which "$command_name" >/dev/null 2>&1; }; then
      printf "  %-14s %s\n" "$command_name" "ok"
    else
      printf "  %-14s %s\n" "$command_name" "missing"
      failures=1
    fi
  done

  if ! grep -Fq "$BLOCK_START" "$HOME/.zshrc" 2>/dev/null ||
    ! grep -Fq "$BLOCK_END" "$HOME/.zshrc" 2>/dev/null; then
    warn "managed zsh block is missing"
    failures=1
  fi

  if (( SKIP_CASKS == 0 )); then
    local app
    for app in OrbStack "Visual Studio Code" iTerm; do
      if [[ -d "/Applications/${app}.app" || -d "$HOME/Applications/${app}.app" ]]; then
        printf "  %-14s %s\n" "$app" "ok"
      else
        printf "  %-14s %s\n" "$app" "missing"
        failures=1
      fi
    done
  fi

  if command -v gh >/dev/null 2>&1; then
    if gh auth status >/dev/null 2>&1; then
      printf "  %-14s %s\n" "GitHub auth" "ok"
    else
      warn "GitHub CLI is not authenticated"
    fi
  fi

  if command -v docker >/dev/null 2>&1; then
    if docker info >/dev/null 2>&1; then
      printf "  %-14s %s\n" "Docker" "ok"
    else
      warn "Docker CLI is installed, but the runtime is not ready"
    fi
  fi

  (( failures == 0 )) || fail "setup check found missing requirements"
  info "Setup check passed"
}

install_homebrew() {
  if activate_brew; then
    info "Homebrew is already installed"
    return
  fi

  info "Installing Homebrew"
  TEMP_DIR="${TEMP_DIR:-$(mktemp -d "${TMPDIR:-/tmp}/dev-init.XXXXXX")}"
  local installer="$TEMP_DIR/homebrew-install.sh"
  /usr/bin/curl --fail --silent --show-error --location \
    https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh \
    --output "$installer" || fail "could not download the Homebrew installer"
  if is_interactive; then
    /bin/bash "$installer" </dev/tty
  else
    NONINTERACTIVE=1 /bin/bash "$installer"
  fi
  activate_brew || fail "Homebrew installation completed but brew was not found"
}

install_packages() {
  local source_file="$1"
  local bundle_file
  bundle_file="$(effective_brewfile "$source_file")"

  info "Installing Homebrew dependencies"
  brew update
  brew bundle --file="$bundle_file"
  brew cleanup
}

update_zshrc() {
  local zshrc="$HOME/.zshrc"
  local temp_file
  local backup_file
  temp_file="$(mktemp "${TMPDIR:-/tmp}/dev-init-zshrc.XXXXXX")"

  if [[ -f "$zshrc" ]]; then
    if ! grep -Fq "$BLOCK_START" "$zshrc"; then
      backup_file="${zshrc}.backup.$(date +%Y%m%d%H%M%S)"
      cp "$zshrc" "$backup_file"
      info "Backed up .zshrc to $backup_file"
    fi
    /usr/bin/awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
      $0 == start { managed = 1; next }
      $0 == end { managed = 0; next }
      !managed { print }
    ' "$zshrc" >"$temp_file"
  else
    : >"$temp_file"
  fi

  while [[ -s "$temp_file" ]] && [[ "$(tail -c 1 "$temp_file" | wc -l | tr -d ' ')" == "0" ]]; do
    print >>"$temp_file"
  done

  cat >>"$temp_file" <<'ZSH'
# >>> dev-init >>>
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if command -v mise >/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

if command -v direnv >/dev/null 2>&1; then
  eval "$(direnv hook zsh)"
fi

if command -v brew >/dev/null 2>&1; then
  fpath=("$(brew --prefix)/share/zsh/site-functions" $fpath)
fi
autoload -Uz compinit && compinit

if [[ -o interactive ]] && command -v fzf >/dev/null 2>&1; then
  source <(fzf --zsh)
fi
# <<< dev-init <<<
ZSH

  mv "$temp_file" "$zshrc"
  info "Updated managed block in .zshrc"
}

install_runtimes() {
  info "Installing language runtimes with mise"
  eval "$(mise activate zsh)"
  mise use --global node@lts
  mise use --global python@latest
  mise use --global pnpm@latest
}

configure_git_lfs() {
  info "Configuring Git LFS"
  git lfs install
}

configure_github() {
  gh auth status >/dev/null 2>&1 && {
    info "GitHub CLI is already authenticated"
    return
  }

  confirm "Set up SSH and GitHub authentication now?" y || {
    warn "Skipping GitHub authentication"
    return
  }

  local -a public_keys
  public_keys=("$HOME"/.ssh/*.pub(N))
  if (( ${#public_keys} == 0 )); then
    local email
    email="$(git config --global user.email 2>/dev/null || true)"
    [[ -n "$email" ]] || fail "set git user.email before generating an SSH key"
    info "Creating an Ed25519 SSH key; choose a passphrase when prompted"
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$email" -f "$HOME/.ssh/id_ed25519"
    public_keys=("$HOME/.ssh/id_ed25519.pub")
  else
    info "Reusing an existing SSH public key"
  fi

  local private_key="${public_keys[1]%.pub}"
  if [[ -f "$private_key" ]]; then
    ssh-add --apple-use-keychain "$private_key" || ssh-add "$private_key"
  fi

  info "Starting GitHub browser authentication"
  gh auth login --hostname github.com --git-protocol ssh --web
  gh auth setup-git
}

initialize_orbstack() {
  (( SKIP_CASKS == 0 )) || return
  command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 && return

  if confirm "Open OrbStack to finish Docker setup?" y; then
    open -a OrbStack
    info "OrbStack opened; finish its first-run setup if prompted"
  else
    warn "Open OrbStack later to finish Docker setup"
  fi
}

if (( DRY_RUN == 1 )); then
  print_plan
  exit 0
fi

if (( CHECK_ONLY == 1 )); then
  activate_brew || true
  if command -v mise >/dev/null 2>&1; then
    eval "$(mise activate zsh)"
  fi
  check_setup
  exit 0
fi

TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dev-init.XXXXXX")"
brewfile="$(script_brewfile)"
install_homebrew
install_packages "$brewfile"
update_zshrc
install_runtimes
configure_git_lfs

if is_interactive; then
  configure_github
  initialize_orbstack
else
  warn "Non-interactive mode skipped GitHub authentication and OrbStack first-run setup"
fi

hash -r
check_setup
info "Developer setup complete. Open a new terminal to load the managed zsh configuration."
