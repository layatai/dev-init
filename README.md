# dev-init

An idempotent, Codex-friendly developer bootstrap for Apple-silicon macOS,
Linux, and Windows.

## macOS

On an Apple-silicon Mac, review the installer, then run it:

```sh
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.zsh | less
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.zsh | zsh
```

The installer reads prompts from the terminal, so interactive setup still works
when the script is piped to `zsh`. Piped runs download the matching Git ref as
an archive so the Neovim config is installed alongside the Brewfile.

On Linux, do not use this command: a minimal Linux installation may not have
`zsh` yet. Use the Linux `install.sh | bash` command below, which installs zsh
and the other bootstrap prerequisites first.

## Neovim only

To install just Neovim and the IDE config:

```sh
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install-nvim.zsh | zsh
```

Requires Homebrew (`~/.homebrew`, `/opt/homebrew`, or Linuxbrew). The script installs
Neovim, `tree-sitter-cli`, and Node (`npm` is required for Mason
TypeScript/Prettier/ESLint packages), puts `nvim` on the login PATH, copies
the config, restores Lazy plugins, then blocks until Mason language
servers/formatters/CodeLLDB and Treesitter parsers are installed. If `rustup`
is on PATH it also adds `rust-analyzer` and `rustfmt`.

Use `--dry-run` or `--check` the same way as the main installer:

```sh
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install-nvim.zsh |
  zsh -s -- --dry-run
```

## Linux

On Debian/Ubuntu, Fedora, Arch, and openSUSE, use the Linux entry point:

```sh
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.sh | less
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.sh | bash
```

Run that command in an interactive terminal when prerequisites are missing so
`sudo` can request your password. In a terminal-less runner, install `curl`,
`git`, `zsh`, `file`, `procps`, and the distribution's C build tools first, or
provide passwordless sudo for the package-manager commands.

It installs missing bootstrap prerequisites with the system package manager,
then uses Homebrew on Linux for the shared command-line package set. GUI casks
are automatically skipped; Telegram Desktop is installed by the separate
Omarchy setup below. The same options are supported, including
`--dry-run`, `--check`, `--non-interactive`, and `--skip-nvim`.

From a checkout, run `./install.sh`. To install only Neovim after Homebrew and
zsh are available, run `zsh install-nvim.zsh`.

To pass options to the network installer:

```sh
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.sh |
  bash -s -- --dry-run

curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.sh |
  bash -s -- --non-interactive --skip-nvim
```

## Omarchy desktop setup

On an existing [Omarchy](https://omarchy.org) installation, review and apply
the personal desktop overrides with:

```sh
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install-omarchy.sh | less
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install-omarchy.sh | bash
```

This installs Telegram Desktop through Omarchy's package manager and user-level
files under `~/.config/hypr/`. It enables natural touchpad scrolling,
three-finger horizontal workspace swipes, and native 1x display scaling.
Existing differing files receive timestamped backups. It does not modify
Omarchy's packaged files under `/usr/share/omarchy`.

The installer is safe to rerun. Its supported options are:

```text
--dry-run  Show the planned Omarchy changes
--check    Verify that the managed files match
--ref REF  Use a specific branch, tag, or commit
```

From a checkout, run `./install-omarchy.sh`.

## Options

```text
--dry-run          Show the planned setup without changing the machine
--check            Verify the expected tools and configuration
--non-interactive  Skip prompts, application launches, and authentication
--skip-casks       Skip OrbStack, Visual Studio Code, iTerm2, and Telegram Desktop
--skip-nvim        Skip Neovim and the managed IDE config
--ref REF          Use a specific branch, tag, or commit
```

Examples:

```sh
# macOS
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.zsh |
  zsh -s -- --dry-run

# Linux
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.sh |
  bash -s -- --dry-run

# macOS
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.zsh |
  zsh -s -- --non-interactive --skip-casks
```

## What it manages

- Homebrew packages declared in [`Brewfile`](Brewfile)
- Node LTS, stable Python, and pnpm through `mise`
- A marked block in `~/.zshrc` for Homebrew, `mise`, `direnv`, completion, and
  fzf integration
- Neovim plus the NvChad-based IDE config in [`nvim/`](nvim/)
- Git LFS initialization
- Optional SSH key and GitHub CLI authentication
- Optional OrbStack first-run startup
- Telegram Desktop on macOS, Windows, and Omarchy

The first shell edit creates a timestamped `.zshrc` backup. Reruns replace only
the managed block and leave the rest of the file intact. An unmanaged
`~/.config/nvim` is moved aside the same way; later runs update only the tracked
files.

## Neovim IDE

The managed config is NvChad 2.5 with:

- LSP for TypeScript, JSON, HTML/CSS, ESLint, Bash, TOML, and Markdown
- rustaceanvim for Rust (uses `rust-analyzer` from rustup if present)
- Format on save via rustfmt, prettier, stylua, and taplo
- Treesitter, diagnostics (Trouble), comments, TODOs, and DAP + CodeLLDB

Leader is `Space`. Useful keys:

| Key | Action |
|---|---|
| `<leader>e` | File tree |
| `<leader>ff` / `<leader>fw` | Files / grep |
| `gd` `gr` `K` | Definition / refs / hover |
| `<leader>ld` | Diagnostics |
| `<leader>h` / `<leader>v` | Terminal |
| `jk` | Leave insert mode |

Mason language servers install on first launch. For Rust work, install
`rust-analyzer` with rustup (`rustup component add rust-analyzer`).

## Windows

Windows 10/11 can be bootstrapped from the network with the PowerShell-native
installer. Open PowerShell and review the installer first:

```powershell
irm https://raw.githubusercontent.com/layatai/dev-init/master/install.ps1 | more
```

Then run it:

```powershell
irm https://raw.githubusercontent.com/layatai/dev-init/master/install.ps1 | iex
```

The streamed installer downloads the matching repository archive to a temporary
directory so its package manifest, Neovim installer, and configuration are
available. The temporary files are removed when setup finishes.

Alternatively, run it from a checkout:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install.ps1
```

To install just Neovim and the IDE config:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\install-nvim.ps1
```

To install just OpenSSH Server with public-key login:

```powershell
irm https://raw.githubusercontent.com/layatai/dev-init/master/install-ssh-server.ps1 | more
irm https://raw.githubusercontent.com/layatai/dev-init/master/install-ssh-server.ps1 | iex
```

The SSH installer requests administrator elevation when needed, installs and
starts OpenSSH Server, enables the firewall rule for TCP port 22, adds the
managed public key to the appropriate Windows OpenSSH authorized keys file, and
disables SSH password login by default. Administrator accounts use
`C:\ProgramData\ssh\administrators_authorized_keys`; standard accounts use
`~\.ssh\authorized_keys`.

PowerShell options:

```text
-DryRun          Show the plan without changing the machine
-Check           Verify tools and managed configuration
-NonInteractive  Skip prompts and GitHub browser authentication
-SkipApps        Skip VS Code, Docker Desktop, Windows Terminal, and Telegram Desktop
-SkipNvim        Skip Neovim and the managed IDE configuration
-Ref REF         Download repository files from a specific Git ref
```

SSH installer options:

```text
-DryRun                       Show the SSH server plan without changing the machine
-Check                        Verify OpenSSH Server and authentication settings
-AllowPasswordAuthentication  Leave SSH password login enabled
-AuthorizedKey KEY            Add one or more public keys to authorized_keys
-Ref REF                      Use a specific branch, tag, or commit for self-elevation
-Repository OWNER/REPO        Use a specific GitHub repository for self-elevation
```

Examples:

```powershell
.\install.ps1 -DryRun
.\install.ps1 -NonInteractive -SkipApps
.\install.ps1 -Check
.\install-nvim.ps1 -Check
.\install-ssh-server.ps1 -Check
```

To pass options to the network installer, compile the downloaded text as a
script block, following the same pattern as OpenClaw's Windows installer:

```powershell
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/layatai/dev-init/master/install.ps1))) -DryRun
& ([scriptblock]::Create((irm https://raw.githubusercontent.com/layatai/dev-init/master/install.ps1))) -NonInteractive -SkipApps
```

The Windows installer manages Git, Git LFS, GitHub CLI, common command-line
developer tools, Node LTS, current Python, pnpm, a marked PowerShell profile
block, and the existing Neovim configuration. Optional applications include VS
Code, Docker Desktop, Windows Terminal, and Telegram Desktop. WinGet mappings
are kept in
[`packages.psd1`](packages.psd1) for auditing.

Requirements are Windows 10 version 1809 or later (or Windows 11), Windows
PowerShell 5.1 or PowerShell 7+, WinGet, and internet access during package and
plugin installation. The installer is safe to rerun and backs up an unmanaged
Neovim configuration before installing its own.
