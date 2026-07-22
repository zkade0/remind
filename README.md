# remind

Small reminder CLI for macOS and Linux.

## Install

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

## Use

```sh
remind "email Parker" tomorrow 9am
remind "check the oven" in 20 minutes
remind --list
remind --cancel ID
```

On macOS, reminders go into a dedicated Reminders list named `remind`, survive reboots, and may sync through iCloud. Allow Reminders access when prompted and set Reminders notifications to **Alerts** if they should remain until dismissed. GNU `date` is optional but accepts more time expressions (`brew install coreutils`).

On Linux, `notify-send` and GNU `date` are required. Scheduling uses systemd, then `at`, then a non-persistent background process as a fallback.
