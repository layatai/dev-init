[CmdletBinding()]
param([switch]$DryRun,[switch]$Check)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Source = Join-Path $PSScriptRoot 'nvim'
$Destination = Join-Path $env:LOCALAPPDATA 'nvim'
$DataRoot = Join-Path $env:LOCALAPPDATA 'nvim-data'
function Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Blue }
function Refresh-Path { $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') }
function Has([string]$Name) { return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }
function Prerequisites {
    $manifest = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'packages.psd1')
    foreach ($package in $manifest.Nvim) {
        if (Has $package.Command) { continue }
        Step "Installing $($package.Id)"
        & winget install --id $package.Id --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) { throw "WinGet failed to install $($package.Id)." }; Refresh-Path
    }
    if (-not (Has tree-sitter)) {
        Step 'Installing tree-sitter-cli'; & npm install --global tree-sitter-cli
        if ($LASTEXITCODE -ne 0) { throw 'npm failed to install tree-sitter-cli.' }; Refresh-Path
    }
}
function Install-Config {
    if (-not (Test-Path (Join-Path $Source '.dev-init'))) { throw 'Bundled nvim configuration is incomplete.' }
    $marker = Join-Path $Destination '.dev-init'
    if ((Test-Path $Destination) -and -not (Test-Path $marker)) {
        $backup = "$Destination.backup.$(Get-Date -Format yyyyMMddHHmmss)"
        Move-Item -LiteralPath $Destination -Destination $backup; Step "Backed up existing config to $backup"
    }
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    Copy-Item -Path (Join-Path $Source '*') -Destination $Destination -Recurse -Force
    Copy-Item -LiteralPath (Join-Path $Source '.dev-init') -Destination $marker -Force
    Copy-Item -LiteralPath (Join-Path $Source '.stylua.toml') -Destination (Join-Path $Destination '.stylua.toml') -Force
    Step "Installed managed config in $Destination"
}
function Sync-Ide {
    Refresh-Path; Step 'Restoring Neovim plugins'; & nvim --headless '+Lazy! restore' '+qa'
    if ($LASTEXITCODE -ne 0) { throw 'Neovim plugin restore failed.' }
    $bootstrap = (Join-Path $Destination 'bootstrap.lua').Replace('\','/')
    Step 'Installing Mason tools and Treesitter parsers'; & nvim --headless "+luafile $bootstrap" '+qa'
    if ($LASTEXITCODE -ne 0) { throw 'Neovim IDE bootstrap failed.' }
}
function Verify {
    Refresh-Path; $missing = @()
    foreach ($name in @('nvim','node','npm','tree-sitter')) { if (-not (Has $name)) { $missing += $name } }
    if (-not (Test-Path (Join-Path $Destination '.dev-init'))) { $missing += 'managed config' }
    if (-not (Test-Path (Join-Path $DataRoot 'lazy\lazy.nvim'))) { $missing += 'Lazy plugins' }
    if ($missing.Count) { throw "Neovim check failed; missing: $($missing -join ', ')" }; Step 'Neovim IDE check passed'
}
if ($DryRun) { Write-Host 'Would install Neovim, Node, tree-sitter-cli, NvChad, plugins, Mason tools, and parsers.'; exit 0 }
if ($Check) { Verify; exit 0 }
Prerequisites
if (Has rustup) { Step 'Installing Rust editor tools'; & rustup component add rust-analyzer rustfmt }
Install-Config
Sync-Ide
Verify
Step 'Neovim IDE setup complete.'
