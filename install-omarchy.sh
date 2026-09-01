#!/usr/bin/env bash

set -euo pipefail

DEV_INIT_REPO="${DEV_INIT_REPO:-layatai/dev-init}"
DEV_INIT_REF="${DEV_INIT_REF:-master}"
SCRIPT_PATH="${BASH_SOURCE[0]:-}"
SCRIPT_DIR=""
MODE="install"

if [[ -n "$SCRIPT_PATH" && -f "$SCRIPT_PATH" ]]; then
  SCRIPT_DIR="$(cd -- "$(dirname -- "$SCRIPT_PATH")" && pwd)"
fi

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*" >&2; }

usage() {
  cat <<'USAGE'
Usage: install-omarchy.sh [--dry-run | --check] [--ref REF]

Install tai's safe, user-level Omarchy overrides.

Options:
  --dry-run  Show the files that would be installed
  --check    Verify that the managed files match
  --ref REF  Download assets from a branch, tag, or commit
  -h, --help Show this help
USAGE
}

while (($#)); do
  case "$1" in
    --dry-run) MODE="dry-run" ;;
    --check) MODE="check" ;;
    --ref)
      (($# >= 2)) || fail "--ref requires a value"
      DEV_INIT_REF="$2"
      shift
      ;;
    -h|--help) usage; exit 0 ;;
    *) fail "unknown option: $1" ;;
  esac
  shift
done

[[ "$(uname -s)" == Linux ]] || fail "Omarchy requires Linux"
[[ "$DEV_INIT_REF" =~ ^[A-Za-z0-9._/-]+$ ]] || fail "invalid Git ref: $DEV_INIT_REF"
command -v omarchy >/dev/null 2>&1 || fail "Omarchy is not installed: https://omarchy.org"
CONFIG_HOME="${XDG_CONFIG_HOME:-${HOME}/.config}"

managed_files=(
  "hypr/input.lua"
  "hypr/monitors.lua"
)

temp_dir=""
cleanup() {
  [[ -z "$temp_dir" ]] || rm -rf -- "$temp_dir"
}
trap cleanup EXIT

source_file() {
  local relative_path="$1"
  local local_path="${SCRIPT_DIR}/omarchy/${relative_path}"

  if [[ -n "$SCRIPT_DIR" && -f "$local_path" ]]; then
    printf '%s\n' "$local_path"
    return
  fi

  command -v curl >/dev/null 2>&1 || fail "curl is required for a network installation"
  if [[ -z "$temp_dir" ]]; then
    temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/dev-init-omarchy.XXXXXX")"
  fi

  local downloaded="${temp_dir}/${relative_path}"
  mkdir -p -- "$(dirname -- "$downloaded")"
  local url="https://raw.githubusercontent.com/${DEV_INIT_REPO}/${DEV_INIT_REF}/omarchy/${relative_path}"
  curl --fail --silent --show-error --location "$url" --output "$downloaded" ||
    fail "could not download $url"
  printf '%s\n' "$downloaded"
}

check_files() {
  local failed=0 relative_path source_path target_path
  for relative_path in "${managed_files[@]}"; do
    source_path="$(source_file "$relative_path")"
    target_path="${CONFIG_HOME}/${relative_path}"
    if [[ -f "$target_path" ]] && cmp -s -- "$source_path" "$target_path"; then
      printf 'ok: %s\n' "$target_path"
    else
      printf 'mismatch: %s\n' "$target_path" >&2
      failed=1
    fi
  done
  return "$failed"
}

if [[ "$MODE" == "dry-run" ]]; then
  cat <<PLAN
Would install these user-level Omarchy overrides:
  - ${CONFIG_HOME}/hypr/input.lua (natural scrolling and three-finger workspace swipe)
  - ${CONFIG_HOME}/hypr/monitors.lua (1x display and GDK scale)
  - Telegram Desktop (telegram-desktop package, if missing)

Existing differing files would receive timestamped backups.
No files under /usr/share/omarchy would be changed.
PLAN
  exit 0
fi

if [[ "$MODE" == "check" ]]; then
  failed=0
  check_files || failed=1
  if command -v Telegram >/dev/null 2>&1; then
    printf 'ok: Telegram Desktop\n'
  else
    printf 'missing: Telegram Desktop\n' >&2
    failed=1
  fi
  exit "$failed"
fi

if command -v Telegram >/dev/null 2>&1; then
  info "Telegram Desktop is already installed"
else
  info "Installing Telegram Desktop"
  omarchy pkg add telegram-desktop
fi

timestamp="$(date +%Y%m%d-%H%M%S)"
for relative_path in "${managed_files[@]}"; do
  source_path="$(source_file "$relative_path")"
  target_path="${CONFIG_HOME}/${relative_path}"
  mkdir -p -- "$(dirname -- "$target_path")"

  if [[ -f "$target_path" ]] && cmp -s -- "$source_path" "$target_path"; then
    info "Already current: $target_path"
    continue
  fi

  if [[ -e "$target_path" ]]; then
    backup_path="${target_path}.bak.${timestamp}"
    cp -a -- "$target_path" "$backup_path"
    info "Backed up: $backup_path"
  fi

  install -m 0644 -- "$source_path" "$target_path"
  info "Installed: $target_path"
done

if command -v hyprctl >/dev/null 2>&1 && hyprctl instances 2>/dev/null | grep -q .; then
  info "Reloading Hyprland"
  hyprctl reload >/dev/null
  config_errors="$(hyprctl configerrors)"
  [[ -z "$config_errors" ]] || fail "Hyprland configuration errors:\n$config_errors"
fi

info "Omarchy setup complete"
