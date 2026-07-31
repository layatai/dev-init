# dev-init

An idempotent, Codex-friendly developer bootstrap for Apple-silicon macOS.

## Install

Review the installer, then run it:

```sh
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.zsh | less
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install.zsh | zsh
```

The installer reads prompts from the terminal, so interactive setup still works
when the script is piped to `zsh`.

## Options

```text
--dry-run          Show the planned setup without changing the machine
--check            Verify the expected tools and configuration
--non-interactive  Skip prompts, application launches, and authentication
--skip-casks       Skip OrbStack, Visual Studio Code, and iTerm2
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
- Git LFS initialization
- Optional SSH key and GitHub CLI authentication
- Optional OrbStack first-run startup

The first shell edit creates a timestamped `.zshrc` backup. Reruns replace only
the managed block and leave the rest of the file intact.
