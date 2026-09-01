@{
    Core = @(
        @{ Id='Git.Git'; Command='git' }, @{ Id='GitHub.GitLFS'; Command='git-lfs' },
        @{ Id='GitHub.cli'; Command='gh' }, @{ Id='BurntSushi.ripgrep.MSVC'; Command='rg' },
        @{ Id='sharkdp.fd'; Command='fd' }, @{ Id='junegunn.fzf'; Command='fzf' },
        @{ Id='jqlang.jq'; Command='jq' }, @{ Id='MikeFarah.yq'; Command='yq' },
        @{ Id='sharkdp.bat'; Command='bat' }, @{ Id='eza-community.eza'; Command='eza' },
        @{ Id='Kitware.CMake'; Command='cmake' }, @{ Id='Ninja-build.Ninja'; Command='ninja' },
        @{ Id='koalaman.shellcheck'; Command='shellcheck' }, @{ Id='mvdan.shfmt'; Command='shfmt' },
        @{ Id='direnv.direnv'; Command='direnv' }, @{ Id='Casey.Just'; Command='just' },
        @{ Id='7zip.7zip'; Command='7z' }, @{ Id='jdx.mise'; Command='mise' },
        @{ Id='astral-sh.uv'; Command='uv' }
    )
    Nvim = @(
        @{ Id='Neovim.Neovim'; Command='nvim' },
        @{ Id='OpenJS.NodeJS.LTS'; Command='node' }
    )
    Apps = @(
        @{ Id='Microsoft.VisualStudioCode'; Command='code' },
        @{ Id='Docker.DockerDesktop'; Command='docker' },
        @{ Id='Microsoft.WindowsTerminal'; Command='wt' },
        @{ Id='Telegram.TelegramDesktop'; Command='Telegram' }
    )
}
