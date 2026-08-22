# dev-init

An idempotent, Codex-friendly developer bootstrap for Apple-silicon macOS.

## Install

Review the installer, then run it:

```sh
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.zsh | less
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.zsh | zsh
```

The installer reads prompts from the terminal, so interactive setup still works
when the script is piped to `zsh`. Piped runs download the matching Git ref as
an archive so the Neovim config is installed alongside the Brewfile.

## Options

```text
--dry-run          Show the planned setup without changing the machine
--check            Verify the expected tools and configuration
--non-interactive  Skip prompts, application launches, and authentication
--skip-casks       Skip OrbStack, Visual Studio Code, and iTerm2
--skip-nvim        Skip Neovim and the managed IDE config
--ref REF          Use a specific branch, tag, or commit
```

Examples:

```sh
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.zsh |
  zsh -s -- --dry-run

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
