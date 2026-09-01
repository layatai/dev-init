#!/usr/bin/env bash

set -euo pipefail

github_user="layatai"
target_user="${SUDO_USER:-${USER:-}}"
allow_password=false
dry_run=false
check_only=false

fail() { printf 'Error: %s\n' "$*" >&2; exit 1; }
info() { printf '==> %s\n' "$*" >&2; }

while (($#)); do
  case "$1" in
    --github-user) github_user="${2:?missing value for --github-user}"; shift 2 ;;
    --user) target_user="${2:?missing value for --user}"; shift 2 ;;
    --allow-password-authentication) allow_password=true; shift ;;
    --dry-run) dry_run=true; shift ;;
    --check) check_only=true; shift ;;
    -h|--help)
      printf '%s\n' 'Usage: install-ssh-server.sh [--github-user USER] [--user USER] [--allow-password-authentication] [--dry-run|--check]'
      exit 0
      ;;
    *) fail "unknown option: $1" ;;
  esac
done

[[ "$github_user" =~ ^[A-Za-z0-9-]+$ ]] || fail "invalid GitHub user: $github_user"
[[ -n "$target_user" ]] || fail "could not determine target user; pass --user USER"
getent passwd "$target_user" >/dev/null || fail "user does not exist: $target_user"
target_home="$(getent passwd "$target_user" | cut -d: -f6)"
[[ -n "$target_home" && "$target_home" != / ]] || fail "unsafe home directory for $target_user"

if $dry_run; then
  cat <<PLAN
Would configure this Linux machine with:
  - OpenSSH Server on TCP port 22 with automatic startup
  - public-key authentication for $target_user
  - keys published at https://github.com/$github_user.keys
  - password and keyboard-interactive SSH authentication disabled
PLAN
  exit 0
fi

if [[ "$(id -u)" != 0 ]]; then
  command -v sudo >/dev/null || fail "run as root or install sudo"
  [[ -f "${BASH_SOURCE[0]:-}" ]] ||
    fail "a streamed installer must be run with sudo (for example: curl ... | sudo bash -s -- --user $target_user)"
  elevated_args=(--github-user "$github_user" --user "$target_user")
  $allow_password && elevated_args+=(--allow-password-authentication)
  $check_only && elevated_args+=(--check)
  exec sudo "${BASH_SOURCE[0]}" "${elevated_args[@]}"
fi

install_server() {
  command -v sshd >/dev/null && return
  info 'Installing OpenSSH Server'
  if command -v apt-get >/dev/null; then
    apt-get update
    apt-get install -y openssh-server
  elif command -v dnf >/dev/null; then
    dnf install -y openssh-server
  elif command -v pacman >/dev/null; then
    pacman -S --needed --noconfirm openssh
  elif command -v zypper >/dev/null; then
    zypper --non-interactive install openssh
  else
    fail 'unsupported package manager; install OpenSSH Server and retry'
  fi
}

verify() {
  info 'Checking OpenSSH Server'
  systemctl is-active --quiet sshd.service || fail 'sshd is not running'
  systemctl is-enabled --quiet sshd.service || fail 'sshd is not enabled'
  sshd -t
  effective="$(sshd -T)"
  grep -qix 'pubkeyauthentication yes' <<<"$effective" || fail 'public-key authentication is not enabled'
  if ! $allow_password; then
    grep -qix 'passwordauthentication no' <<<"$effective" || fail 'password authentication is not disabled'
    grep -qix 'kbdinteractiveauthentication no' <<<"$effective" || fail 'keyboard-interactive authentication is not disabled'
  fi
  [[ -s "$target_home/.ssh/authorized_keys" ]] || fail 'authorized_keys is empty or missing'
  info 'SSH server check passed'
}

if $check_only; then
  verify
  exit 0
fi

install_server
command -v curl >/dev/null || fail 'curl is required to retrieve GitHub public keys'

keys_file="$(mktemp)"
merged_file="$(mktemp)"
trap 'rm -f -- "$keys_file" "$merged_file"' EXIT
curl --fail --silent --show-error --location "https://github.com/$github_user.keys" --output "$keys_file"
[[ -s "$keys_file" ]] || fail "GitHub returned no public keys for $github_user"
while IFS= read -r key; do
  [[ "$key" =~ ^(ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp(256|384|521))[[:space:]] ]] ||
    fail 'GitHub returned an invalid public key'
done <"$keys_file"

info "Authorizing $github_user's GitHub keys for $target_user"
install -d -m 700 -o "$target_user" -g "$(id -gn "$target_user")" "$target_home/.ssh"
touch "$target_home/.ssh/authorized_keys"
awk '!seen[$0]++' "$target_home/.ssh/authorized_keys" "$keys_file" >"$merged_file"
install -m 600 -o "$target_user" -g "$(id -gn "$target_user")" "$merged_file" "$target_home/.ssh/authorized_keys"

info 'Configuring key-only SSH authentication'
install -d -m 755 /etc/ssh/sshd_config.d
{
  printf '%s\n' 'PubkeyAuthentication yes'
  if $allow_password; then
    printf '%s\n' 'PasswordAuthentication yes'
  else
    printf '%s\n' 'PasswordAuthentication no' 'KbdInteractiveAuthentication no'
  fi
} >/etc/ssh/sshd_config.d/10-dev-init.conf
info 'Generating missing SSH host keys'
ssh-keygen -A
sshd -t
systemctl enable --now sshd.service
systemctl restart sshd.service
verify
