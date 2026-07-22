# remind

Small reminder CLI for macOS, Linux, and Windows.

## Install

### macOS / Linux

```sh
git clone https://github.com/zkade0/remind.git
cd remind
mkdir -p "$HOME/.local/bin"
install -m 755 remind "$HOME/.local/bin/remind"
```

This installs only for your user on macOS or Linux. If needed, add this to your shell profile:

```sh
export PATH="$HOME/.local/bin:$PATH"
```

### Windows

From PowerShell:

```powershell
git clone --branch windows-powershell https://github.com/zkade0/remind.git
Set-Location remind
New-Item -ItemType Directory -Force "$HOME\bin" | Out-Null
Copy-Item remind.ps1 "$HOME\bin\remind.ps1"
```

Add `%USERPROFILE%\bin` to your user `PATH`, then reopen PowerShell.

## Use

```sh
remind "email Parker" tomorrow 9am
remind "check the oven" in 20 minutes
remind --list
remind --cancel ID
```

Windows PowerShell uses:

```powershell
remind "email Parker" tomorrow 9am
remind "check the oven" in 20 minutes
remind -List
remind -Cancel ID
```

On macOS, reminders go into a dedicated Reminders list named `remind`, survive reboots, and may sync through iCloud. Allow Reminders access when prompted and set Reminders notifications to **Alerts** if they should remain until dismissed. GNU `date` is optional but accepts more time expressions (`brew install coreutils`).

On Linux, `notify-send` and GNU `date` are required. Scheduling uses systemd, then `at`, then a non-persistent background process as a fallback.

On Windows 10 or newer, reminders use the built-in Task Scheduler and Windows PowerShell 5.1. They survive reboots, run after the next login if missed, and stay visible until **Dismiss** is clicked. No administrator access or extra modules are required.
