---
name: windows-ssh-server
description: Set up or verify Windows OpenSSH Server for public-key login, especially using the layatai/dev-init SSH installer.
metadata:
  short-description: Configure Windows OpenSSH Server
---

# Windows SSH Server

Use this skill when the user asks to set up, repair, verify, or harden Windows OpenSSH Server access on this machine. It is especially relevant when the request mentions `layatai/dev-init`, `install-ssh-server.ps1`, `sshd`, `authorized_keys`, or installing a GitHub public key for inbound SSH.

## Workflow

- Inspect local state first with Windows-native tools: `sc query sshd`, `sc qc sshd`, `ssh -V`, `netsh advfirewall firewall show rule name=all`, and `C:\ProgramData\ssh\sshd_config` when readable.
- If the user points to `https://github.com/layatai/dev-init`, prefer the repository's `install-ssh-server.ps1` over reimplementing its behavior. Run `-DryRun` before making changes.
- Treat service, firewall, `C:\ProgramData\ssh`, and Windows capability changes as admin-level operations. Request escalation immediately before the mutating command.
- The default managed key in `layatai/dev-init` is the `tailay` key embedded in `install-ssh-server.ps1`; do not replace it with every key from `https://github.com/layatai.keys` unless the user explicitly asks for account-wide GitHub keys.
- For administrator accounts, Windows OpenSSH checks `C:\ProgramData\ssh\administrators_authorized_keys`. Standard users normally use `%USERPROFILE%\.ssh\authorized_keys`. It is acceptable for the managed key to be present in both.
- Verify the outcome with the script's `-Check` mode when possible, plus independent checks that `sshd` is running, auto-started, public-key auth is enabled, password and keyboard-interactive auth are disabled unless requested otherwise, and a TCP 22 firewall rule is enabled.

## Known Script Fixes

If `install-ssh-server.ps1` exits with an error like `$LASTEXITCODE` cannot be retrieved after `Start-Process -Verb RunAs -Wait`, update the elevation wrapper to use `-PassThru` and exit the child process code:

```powershell
$process = Start-Process -FilePath powershell.exe -Verb RunAs -Wait -PassThru -ArgumentList (ConvertTo-ArgumentList @arguments)
exit $process.ExitCode
```

If verification fails because the firewall rule `OpenSSH-Server-In-TCP` is missing but Windows shows `OpenSSH SSH Server (sshd)` under the `OpenSSH Server` group, broaden rule detection to find enabled TCP port 22 OpenSSH rules by name, display name, or display group before creating a new rule.

## Verification Notes

- A localhost SSH attempt that reaches the server and fails with `Permission denied (publickey,keyboard-interactive)` can confirm the daemon is reachable and password auth is not being offered for that account.
- Protected key files may be unreadable from a sandbox or non-admin account. Use an elevated, read-only verification script that writes a small result file to `%TEMP%` when direct inspection is blocked.
- Do not weaken SSH authentication or enable password login unless the user explicitly requests it.
