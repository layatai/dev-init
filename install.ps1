[CmdletBinding()]
param([switch]$DryRun,[switch]$Check,[switch]$NonInteractive,[switch]$SkipApps,[switch]$SkipNvim)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$BlockStart = '# >>> dev-init >>>'
$BlockEnd = '# <<< dev-init <<<'

function Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Blue }
function Refresh-Path { $env:Path = [Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [Environment]::GetEnvironmentVariable('Path','User') }
function Has([string]$Name) { return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue) }
function Packages {
    $manifest = Import-PowerShellDataFile (Join-Path $PSScriptRoot 'packages.psd1')
    $items = @($manifest.Core)
    if (-not $SkipNvim) { $items += @($manifest.Nvim) }
    if (-not $SkipApps) { $items += @($manifest.Apps) }
    return $items
}
function Plan {
    @('Would configure this Windows PC with:','  - Git, Git LFS, and GitHub CLI','  - modern CLI search, data, build, and shell tools','  - mise, uv, Node LTS, Python, and pnpm','  - a managed PowerShell profile block') | Write-Host
    if (-not $SkipNvim) { Write-Host '  - Neovim with the managed NvChad IDE config' }
    if (-not $SkipApps) { Write-Host '  - VS Code, Docker Desktop, and Windows Terminal' }
}
function Install-Packages {
    if (-not (Has winget)) { throw 'WinGet is required. Install App Installer from the Microsoft Store.' }
    foreach ($package in Packages) {
        if (Has $package.Command) { Step "$($package.Id) is already available"; continue }
        Step "Installing $($package.Id)"
        & winget install --id $package.Id --exact --source winget --accept-package-agreements --accept-source-agreements --disable-interactivity
        if ($LASTEXITCODE -ne 0) { throw "WinGet failed to install $($package.Id) (exit $LASTEXITCODE)." }
        Refresh-Path
    }
}
function Update-Profile {
    $path = $PROFILE.CurrentUserAllHosts
    New-Item -ItemType Directory -Path (Split-Path -Parent $path) -Force | Out-Null
    $old = if (Test-Path -LiteralPath $path) { Get-Content -LiteralPath $path -Raw } else { '' }
    if ($old -and -not $old.Contains($BlockStart)) {
        $backup = "$path.backup.$(Get-Date -Format yyyyMMddHHmmss)"
        Copy-Item -LiteralPath $path -Destination $backup
        Step "Backed up profile to $backup"
    }
    $start = [regex]::Escape($BlockStart); $end = [regex]::Escape($BlockEnd)
    $clean = [regex]::Replace($old,"(?ms)^$start.*?^$end\s*",'').TrimEnd()
    $managed = @'
# >>> dev-init >>>
if (Get-Command mise -ErrorAction SilentlyContinue) { (& mise activate pwsh) | Out-String | Invoke-Expression }
if (Get-Command direnv -ErrorAction SilentlyContinue) { (& direnv hook pwsh) | Out-String | Invoke-Expression }
# <<< dev-init <<<
'@
    Set-Content -LiteralPath $path -Value $(if ($clean) { "$clean`r`n`r`n$managed" } else { $managed }) -Encoding utf8
    Step "Updated managed block in $path"
}
function Install-Runtimes {
    Refresh-Path; if (-not (Has mise)) { throw 'mise is not available after installation.' }
    Step 'Installing language runtimes with mise'
    & mise use --global node@lts python@latest pnpm@latest
    if ($LASTEXITCODE -ne 0) { throw 'mise failed to install runtimes.' }
}
function Configure-GitHub {
    Refresh-Path
    & git lfs install; if ($LASTEXITCODE -ne 0) { throw 'Git LFS initialization failed.' }
    if ($NonInteractive -or -not (Has gh)) { return }
    & gh auth status *> $null; if ($LASTEXITCODE -eq 0) { Step 'GitHub CLI is already authenticated'; return }
    $answer = Read-Host 'Set up GitHub authentication now? [Y/n]'
    if ($answer -and $answer -notmatch '^(?i)y(es)?$') { Write-Warning 'Skipping GitHub authentication'; return }
    & gh auth login --hostname github.com --git-protocol ssh --web
    if ($LASTEXITCODE -ne 0) { throw 'GitHub authentication failed.' }
    & gh auth setup-git
}
function Verify {
    Refresh-Path; $missing = @()
    foreach ($package in Packages) {
        $ok = Has $package.Command; Write-Host ('  {0,-18} {1}' -f $package.Command,$(if($ok){'ok'}else{'missing'}))
        if (-not $ok) { $missing += $package.Command }
    }
    $profileText = if (Test-Path -LiteralPath $PROFILE.CurrentUserAllHosts) { Get-Content -LiteralPath $PROFILE.CurrentUserAllHosts -Raw } else { '' }
    if (-not $profileText.Contains($BlockStart) -or -not $profileText.Contains($BlockEnd)) { $missing += 'PowerShell profile block' }
    if (-not $SkipNvim -and -not (Test-Path (Join-Path $env:LOCALAPPDATA 'nvim\.dev-init'))) { $missing += 'Neovim config' }
    if ($missing.Count) { throw "Setup check failed; missing: $($missing -join ', ')" }
    Step 'Setup check passed'
}

if ($DryRun) { Plan; exit 0 }
if ($Check) { Verify; exit 0 }
Install-Packages
Update-Profile
Install-Runtimes
if (-not $SkipNvim) { & (Join-Path $PSScriptRoot 'install-nvim.ps1') }
Configure-GitHub
Verify
Step 'Developer setup complete. Open a new PowerShell window.'
