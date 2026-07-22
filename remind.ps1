#requires -Version 5.1
[CmdletBinding(DefaultParameterSetName = 'Set')]
param(
    [Parameter(Mandatory, Position = 0, ParameterSetName = 'Set')]
    [string]$Message,

    [Parameter(Mandatory, Position = 1, ValueFromRemainingArguments, ParameterSetName = 'Set')]
    [string[]]$When,

    [Parameter(Mandatory, ParameterSetName = 'List')]
    [Alias('l')]
    [switch]$List,

    [Parameter(Mandatory, ParameterSetName = 'Cancel')]
    [Alias('c')]
    [string]$Cancel
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-ReminderTime {
    param([Parameter(Mandatory)][string]$Text)

    $now = Get-Date
    $value = $Text.Trim() -replace '\s+tonight$', ''

    if ($value -match '^(?:in\s+)?(\d+)\s+(second|minute|hour|day|week)s?$') {
        $amount = [int]$Matches[1]
        switch ($Matches[2]) {
            'second' { return $now.AddSeconds($amount) }
            'minute' { return $now.AddMinutes($amount) }
            'hour'   { return $now.AddHours($amount) }
            'day'    { return $now.AddDays($amount) }
            'week'   { return $now.AddDays(7 * $amount) }
        }
    }

    if ($value -match '^(today|tomorrow)(?:\s+(?:at\s+)?(.+))?$') {
        $day = $now.Date.AddDays($(if ($Matches[1] -eq 'tomorrow') { 1 } else { 0 }))
        if (-not $Matches[2]) { return $day.Add($now.TimeOfDay) }
        try {
            $clock = [datetime]::Parse($Matches[2], [Globalization.CultureInfo]::CurrentCulture)
            return $day.Add($clock.TimeOfDay)
        } catch {
            throw "can't parse time: $Text"
        }
    }

    [datetime]$parsed = [datetime]::MinValue
    if ([datetime]::TryParse($value, [Globalization.CultureInfo]::CurrentCulture,
            [Globalization.DateTimeStyles]::AllowWhiteSpaces, [ref]$parsed)) {
        return $parsed
    }
    throw "can't parse time: $Text"
}

function Get-ReminderTasks {
    @(Get-ScheduledTask -TaskName 'remind-*' -ErrorAction SilentlyContinue)
}

function Remove-FiredTasks {
    foreach ($task in Get-ReminderTasks) {
        $info = Get-ScheduledTaskInfo -TaskName $task.TaskName -ErrorAction SilentlyContinue
        if ($info -and $info.LastRunTime.Year -gt 2000) {
            Unregister-ScheduledTask -TaskName $task.TaskName -Confirm:$false
        }
    }
}

if ($env:OS -ne 'Windows_NT') {
    throw 'remind.ps1 requires Windows 10 or newer'
}

Remove-FiredTasks

if ($List) {
    $tasks = Get-ReminderTasks
    if (-not $tasks) { Write-Output '(none)'; exit }
    $tasks | Sort-Object { $_.Triggers[0].StartBoundary } | ForEach-Object {
        [pscustomobject]@{
            ID      = $_.TaskName
            When    = [datetime]$_.Triggers[0].StartBoundary
            Reminder = $_.Description -replace '^\[remind\]\s*', ''
        }
    } | Format-Table -AutoSize
    exit
}

if ($Cancel) {
    if ($Cancel -notlike 'remind-*' -or -not (Get-ScheduledTask -TaskName $Cancel -ErrorAction SilentlyContinue)) {
        throw "reminder not found: $Cancel"
    }
    Unregister-ScheduledTask -TaskName $Cancel -Confirm:$false
    Write-Output "cancelled: $Cancel"
    exit
}

$target = Resolve-ReminderTime ($When -join ' ')
if ($target -le (Get-Date)) { throw 'that time is in the past' }

$id = 'remind-{0}-{1}' -f $target.ToString('yyyyMMddHHmmss'), ([guid]::NewGuid().ToString('N').Substring(0, 8))
$safeMessage = [Security.SecurityElement]::Escape($Message)
$toastXml = @"
<toast scenario="reminder">
  <visual>
    <binding template="ToastGeneric">
      <text>Reminder</text>
      <text>$safeMessage</text>
    </binding>
  </visual>
  <actions>
    <action content="Dismiss" arguments="dismiss" activationType="system"/>
  </actions>
  <audio src="ms-winsoundevent:Notification.Reminder"/>
</toast>
"@

$toastBase64 = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($toastXml))
$fire = @"
`$xmlText = [Text.Encoding]::Unicode.GetString([Convert]::FromBase64String('$toastBase64'))
[Windows.UI.Notifications.ToastNotificationManager, Windows.UI.Notifications, ContentType = WindowsRuntime] > `$null
`$xml = New-Object Windows.Data.Xml.Dom.XmlDocument
`$xml.LoadXml(`$xmlText)
`$toast = [Windows.UI.Notifications.ToastNotification]::new(`$xml)
[Windows.UI.Notifications.ToastNotificationManager]::CreateToastNotifier('Microsoft.Windows.PowerShell').Show(`$toast)
Unregister-ScheduledTask -TaskName '$id' -Confirm:`$false
"@
$encodedFire = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($fire))

$powershell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$action = New-ScheduledTaskAction -Execute $powershell -Argument "-NoProfile -NonInteractive -WindowStyle Hidden -EncodedCommand $encodedFire"
$trigger = New-ScheduledTaskTrigger -Once -At $target
$principal = New-ScheduledTaskPrincipal -UserId ([Security.Principal.WindowsIdentity]::GetCurrent().Name) -LogonType Interactive -RunLevel Limited
$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask -TaskName $id -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Description "[remind] $Message" | Out-Null
Write-Output ('set: "{0}"  ->  {1}  ({2})' -f $Message, $target.ToString('ddd yyyy-MM-dd HH:mm:ss'), $id)
