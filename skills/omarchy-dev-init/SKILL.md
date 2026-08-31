---
name: omarchy-dev-init
description: Maintain, audit, publish, or apply layatai/dev-init's reproducible Omarchy desktop setup. Use when a request concerns the repository's install-omarchy.sh web installer, its managed Hyprland overrides, or reverse-engineering this user's live Omarchy preferences into that installer. Do not use for unrelated Omarchy customization that should remain local and untracked.
---

# Omarchy Dev Init

Keep the reproducible setup in `layatai/dev-init` aligned with intentional user-level Omarchy preferences.

## Source of truth

The repository owns:

- `install-omarchy.sh`: local and `curl | bash` entry point.
- `omarchy/hypr/input.lua`: natural scrolling and three-finger horizontal workspace switching.
- `omarchy/hypr/monitors.lua`: preferred resolution at native 1x display and GDK scale.
- The Omarchy section of `README.md`.

Treat the checked-in assets as the desired state and the live files under `~/.config/` as evidence when auditing or reverse-engineering. Ignore formatting-only differences and stock sample content.

## Maintain or extend the setup

Inspect the live user configuration and compare relevant files with `/usr/share/omarchy/config/`, which is read-only reference material. Capture only intentional, portable preferences. Exclude secrets, credentials, device caches, browser data, generated state, and unrequested machine-specific settings.

Keep all installed configuration under `${XDG_CONFIG_HOME:-$HOME/.config}`. Never write to `/usr/share/omarchy`. Preserve these installer properties:

- Idempotent reruns.
- Timestamped backups before replacing differing files.
- `--dry-run`, `--check`, and `--ref REF` support.
- Both checkout execution and raw GitHub asset downloads.
- Live `hyprctl reload` and `hyprctl configerrors` validation when a Hyprland instance is available.

Do not add packages, plugins, drivers, or privileged operations merely because they exist on the source machine. Add them only when the user explicitly includes them in the reproducible setup.

## Apply

Prefer a checkout's `./install-omarchy.sh`. For web installation, use:

```bash
curl -fsSL https://raw.githubusercontent.com/layatai/dev-init/master/install-omarchy.sh | bash
```

Use `--dry-run` first when the user asks to preview or when the live configuration may contain unrelated changes. Applying the installer mutates user configuration; publishing changes to GitHub is a separate external mutation and requires its own authorization or an explicit user request.

## Validate changes

Before publishing:

1. Run `bash -n install-omarchy.sh` and `shellcheck` when available.
2. Run `git diff --check`.
3. Exercise install, `--check`, and a second idempotent install with a temporary `XDG_CONFIG_HOME`.
4. Review the complete diff for secrets and unintended scope.
5. After an authorized push, execute the public raw URL with `--dry-run` and confirm the remote branch commit.

Preserve unrelated repository history and working-tree changes. Do not commit or push unless requested.
