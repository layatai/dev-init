[CmdletBinding()]
param(
    [switch]$DryRun,
    [switch]$Check,
    [switch]$AllowPasswordAuthentication,
    [string]$Ref = 'master',
    [string]$Repository = 'layatai/dev-init',
    [string[]]$AuthorizedKey = @(
        'ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQDTtg1CE27MkdOR/I9MAG65fLiAC3/G3Jd+/TwUf0vrSM0V0elB1+1mSFVE+agFeYlJCecNWQ1aIY0zR91vUfMXJpQPIsgP78QFyDvIohf43NSkEuKXGMdFgGi4D6pWrfBt2B4h1wp3Zc8g8IGrOT6kihQ7bsAN8v4uIkVvpg3GiWqo0EEyvFBsbYOetyAZzSfKWpJSKzhGpk89oTVz9Wb9UxKOStD9GfqrmGZDN92JTwaimCAdSIRqSsNAf+KwqhV+MhS8m5mxNhHy7gpCGRSlPLlWG15xE+VE38TiBQbBnuUSCoY0AUrCHIADsLBUSYW2/ajKU7rnspnpeGNbjhWl tailay'
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$Script:SelfPath = if ($PSCommandPath) {
    $PSCommandPath
} elseif ($MyInvocation.MyCommand.PSObject.Properties['Path']) {
    $MyInvocation.MyCommand.Path
} else {
    $null
}
$Script:SelfSource = $MyInvocation.MyCommand.Definition
$OpenSshCapability = 'OpenSSH.Server~~~~0.0.1.0'

function Step([string]$Message) { Write-Host "==> $Message" -ForegroundColor Blue }

function Test-Administrator {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function ConvertTo-ArgumentList {
    $arguments = @()
    foreach ($item in $args) {
        if ($null -eq $item -or $item -eq '') { continue }
        if ($item -match '[\s"]') {
            $arguments += '"' + ($item -replace '"', '\"') + '"'
        } else {
            $arguments += $item
        }
    }
    return $arguments -join ' '
}

function Invoke-ElevatedSelf {
    if (Test-Administrator) { return }

    $scriptPath = $Script:SelfPath
    if (-not $scriptPath) {
        $tempRoot = Join-Path ([IO.Path]::GetTempPath()) ("dev-init-ssh-" + [guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        $scriptPath = Join-Path $tempRoot 'install-ssh-server.ps1'
        if ($Script:SelfSource) {
            Set-Content -LiteralPath $scriptPath -Value $Script:SelfSource -Encoding utf8
        } else {
            if ($Repository -notmatch '^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$') { throw "Invalid GitHub repository: $Repository" }
            if ($Ref -notmatch '^[A-Za-z0-9._/-]+$') { throw "Invalid Git ref: $Ref" }
            Invoke-RestMethod -Uri "https://raw.githubusercontent.com/$Repository/$Ref/install-ssh-server.ps1" |
                Set-Content -LiteralPath $scriptPath -Encoding utf8
        }
    }

    $arguments = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $scriptPath)
    foreach ($parameter in $PSBoundParameters.GetEnumerator()) {
        if ($parameter.Value -is [switch]) {
            if ($parameter.Value.IsPresent) { $arguments += "-$($parameter.Key)" }
            continue
        }

        if ($parameter.Value -is [array]) {
            foreach ($value in $parameter.Value) {
                $arguments += "-$($parameter.Key)"
                $arguments += [string]$value
            }
            continue
        }

        $arguments += "-$($parameter.Key)"
        $arguments += [string]$parameter.Value
    }

    Step 'Requesting administrator elevation'
    Start-Process -FilePath powershell.exe -Verb RunAs -Wait -ArgumentList (ConvertTo-ArgumentList @arguments)
    exit $LASTEXITCODE
}

function Set-ConfigValue([string[]]$Config, [string]$Name, [string]$Value) {
    $pattern = "^\s*#?\s*$Name\s+.*$"
    $replacement = "$Name $Value"

    if ($Config -match $pattern) {
        return @($Config | ForEach-Object {
            if ($_ -match $pattern) { $replacement } else { $_ }
        })
    }

    return @($Config + $replacement)
}

function Install-OpenSshServer {
    Step 'Installing OpenSSH Server'
    $capability = Get-WindowsCapability -Online -Name $OpenSshCapability
    if ($capability.State -ne 'Installed') {
        Add-WindowsCapability -Online -Name $OpenSshCapability | Out-Null
    }

    Set-Service -Name sshd -StartupType Automatic
    Start-Service -Name sshd

    $firewallRule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
    if (-not $firewallRule) {
        New-NetFirewallRule `
            -Name 'OpenSSH-Server-In-TCP' `
            -DisplayName 'OpenSSH Server (sshd)' `
            -Enabled True `
            -Direction Inbound `
            -Protocol TCP `
            -Action Allow `
            -LocalPort 22 | Out-Null
    } elseif ($firewallRule.Enabled -ne 'True') {
        Enable-NetFirewallRule -Name 'OpenSSH-Server-In-TCP'
    }
}

function Set-AuthorizedKeys {
    if (-not $AuthorizedKey.Count) { return }

    Step 'Configuring authorized_keys'
    $sshDir = Join-Path $env:USERPROFILE '.ssh'
    $authorizedKeysPath = Join-Path $sshDir 'authorized_keys'

    New-Item -ItemType Directory -Path $sshDir -Force | Out-Null
    if (-not (Test-Path -LiteralPath $authorizedKeysPath)) {
        New-Item -ItemType File -Path $authorizedKeysPath -Force | Out-Null
    }

    $existingKeys = @(Get-Content -LiteralPath $authorizedKeysPath -ErrorAction SilentlyContinue)
    foreach ($key in $AuthorizedKey) {
        if ($existingKeys -notcontains $key) {
            Add-Content -LiteralPath $authorizedKeysPath -Value $key
        }
    }

    $userRuleDir = "$env:USERNAME" + ':(OI)(CI)F'
    $userRuleFile = "$env:USERNAME" + ':F'
    icacls $sshDir /inheritance:r /grant:r $userRuleDir | Out-Null
    icacls $authorizedKeysPath /inheritance:r /grant:r $userRuleFile | Out-Null
}

function Set-SshdConfig {
    Step 'Configuring sshd authentication'
    $configPath = Join-Path $env:ProgramData 'ssh\sshd_config'
    if (-not (Test-Path -LiteralPath $configPath)) {
        throw "Missing sshd_config at $configPath. Install OpenSSH Server first."
    }

    $config = @(Get-Content -LiteralPath $configPath)
    $config = Set-ConfigValue -Config $config -Name 'PubkeyAuthentication' -Value 'yes'
    if ($AllowPasswordAuthentication) {
        $config = Set-ConfigValue -Config $config -Name 'PasswordAuthentication' -Value 'yes'
    } else {
        $config = Set-ConfigValue -Config $config -Name 'PasswordAuthentication' -Value 'no'
        $config = Set-ConfigValue -Config $config -Name 'KbdInteractiveAuthentication' -Value 'no'
        $config = Set-ConfigValue -Config $config -Name 'ChallengeResponseAuthentication' -Value 'no'
    }

    Set-Content -LiteralPath $configPath -Value $config -Encoding ascii
    Restart-Service -Name sshd
}

function Verify {
    Step 'Checking OpenSSH Server'
    $service = Get-Service -Name sshd -ErrorAction SilentlyContinue
    if (-not $service) { throw 'sshd service is missing.' }
    if ($service.Status -ne 'Running') { throw "sshd is $($service.Status), expected Running." }

    $configPath = Join-Path $env:ProgramData 'ssh\sshd_config'
    $config = if (Test-Path -LiteralPath $configPath) { Get-Content -LiteralPath $configPath -Raw } else { '' }
    if ($config -notmatch '(?m)^\s*PubkeyAuthentication\s+yes\s*$') {
        throw 'PubkeyAuthentication is not enabled.'
    }
    if (-not $AllowPasswordAuthentication -and $config -notmatch '(?m)^\s*PasswordAuthentication\s+no\s*$') {
        throw 'PasswordAuthentication is not disabled.'
    }

    $firewallRule = Get-NetFirewallRule -Name 'OpenSSH-Server-In-TCP' -ErrorAction SilentlyContinue
    if (-not $firewallRule -or $firewallRule.Enabled -ne 'True') {
        throw 'OpenSSH firewall rule is missing or disabled.'
    }

    Step 'SSH server check passed'
}

function Plan {
    Write-Host 'Would configure this Windows PC with:'
    Write-Host '  - OpenSSH Server on TCP port 22'
    Write-Host '  - automatic sshd service startup'
    Write-Host '  - public-key SSH authentication'
    if ($AllowPasswordAuthentication) {
        Write-Host '  - password SSH authentication left enabled'
    } else {
        Write-Host '  - password SSH authentication disabled'
    }
}

if ($DryRun) { Plan; return }

Invoke-ElevatedSelf

if ($Check) { Verify; return }

Install-OpenSshServer
Set-AuthorizedKeys
Set-SshdConfig
Verify
Step 'SSH server setup complete.'
