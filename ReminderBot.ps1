# ============================================================
#   ReminderBot - Windows System Tray Reminder App
#   github.com/YOUR_USERNAME/reminderbot
# ============================================================

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Drawing

$dataFolder   = "$env:APPDATA\ReminderBot"
$remindersFile = "$dataFolder\reminders.json"
$logFile       = "$dataFolder\log.txt"

# Create data folder if it doesn't exist
if (-not (Test-Path $dataFolder)) {
    New-Item -ItemType Directory -Path $dataFolder | Out-Null
}

function Write-Log($msg) {
    $line = "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] $msg"
    Add-Content -Path $logFile -Value $line
}

# ============================================================
#   REMINDERS FILE HELPERS
# ============================================================
function Load-Reminders {
    if (-not (Test-Path $remindersFile)) { return @() }
    try {
        $data = Get-Content $remindersFile -Raw | ConvertFrom-Json
        if ($null -eq $data) { return @() }
        return @($data)
    } catch { return @() }
}

function Save-Reminders($reminders) {
    $reminders | ConvertTo-Json | Set-Content $remindersFile
}

# ============================================================
#   DESKTOP NOTIFICATION
# ============================================================
function Show-Notification($title, $message) {
    $trayIcon.BalloonTipIcon  = [System.Windows.Forms.ToolTipIcon]::Info
    $trayIcon.BalloonTipTitle = $title
    $trayIcon.BalloonTipText  = $message
    $trayIcon.ShowBalloonTip(10000)
}

# ============================================================
#   ADD REMINDER DIALOG
# ============================================================
function Add-Reminder {
    $message = [Microsoft.VisualBasic.Interaction]::InputBox(
        "What do you want to be reminded about?`n`nExample: Team meeting at 2pm",
        "ReminderBot - New Reminder"
    )
    if ([string]::IsNullOrWhiteSpace($message)) { return }

    $daysInput = [Microsoft.VisualBasic.Interaction]::InputBox(
        "Remind you in how many days?`n`nEnter a number (e.g. 3)",
        "ReminderBot - Days"
    )
    if ($daysInput -notmatch '^\d+$') {
        [System.Windows.Forms.MessageBox]::Show("Please enter a valid number.", "ReminderBot")
        return
    }

    $days    = [int]$daysInput
    $dueDate = (Get-Date).AddDays($days).ToString("yyyy-MM-dd")

    $reminders = Load-Reminders
    $reminders += [PSCustomObject]@{
        id      = [System.Guid]::NewGuid().ToString()
        message = $message
        dueDate = $dueDate
        fired   = $false
    }
    Save-Reminders $reminders

    $friendlyDate = (Get-Date $dueDate).ToString("dddd, MMMM d")
    Show-Notification "Reminder Saved!" "I'll remind you about '$message' on $friendlyDate"
    Write-Log "Added reminder: '$message' due $dueDate"
}

# ============================================================
#   VIEW REMINDERS
# ============================================================
function View-Reminders {
    $reminders = @(Load-Reminders | Where-Object { $_.fired -eq $false })
    if ($reminders.Count -eq 0) {
        [System.Windows.Forms.MessageBox]::Show(
            "You have no upcoming reminders.`n`nRight-click the tray icon to add one!",
            "ReminderBot - Reminders"
        )
        return
    }

    $lines = $reminders | ForEach-Object {
        $friendly = (Get-Date $_.dueDate).ToString("dddd, MMM d")
        "• $($_.message) — $friendly"
    }
    $text = $lines -join "`n"
    [System.Windows.Forms.MessageBox]::Show($text, "ReminderBot - Upcoming Reminders")
}

# ============================================================
#   CHECK AND FIRE DUE REMINDERS
# ============================================================
function Check-Reminders {
    $reminders = Load-Reminders
    if ($reminders.Count -eq 0) { return }

    $today = (Get-Date).ToString("yyyy-MM-dd")
    $due   = @($reminders | Where-Object { $_.dueDate -eq $today -and $_.fired -eq $false })

    foreach ($r in $due) {
        Show-Notification "Reminder!" $r.message
        Write-Log "Fired reminder: '$($r.message)'"
        $r.fired = $true
    }

    if ($due.Count -gt 0) {
        Save-Reminders $reminders
    }
}

# ============================================================
#   BUILD TRAY ICON
# ============================================================

# Draw a simple icon using GDI+
$bitmap = New-Object System.Drawing.Bitmap(16, 16)
$g = [System.Drawing.Graphics]::FromImage($bitmap)
$g.Clear([System.Drawing.Color]::Transparent)
$g.FillEllipse([System.Drawing.Brushes]::DodgerBlue, 1, 1, 13, 13)
$g.DrawString("R", (New-Object System.Drawing.Font("Arial", 7, [System.Drawing.FontStyle]::Bold)),
    [System.Drawing.Brushes]::White,
    (New-Object System.Drawing.RectangleF(2, 2, 12, 12)))
$g.Dispose()
$icon = [System.Drawing.Icon]::FromHandle($bitmap.GetHicon())

$trayIcon = New-Object System.Windows.Forms.NotifyIcon
$trayIcon.Icon    = $icon
$trayIcon.Text    = "ReminderBot"
$trayIcon.Visible = $true

# Context menu
$menu         = New-Object System.Windows.Forms.ContextMenuStrip
$menuAdd      = New-Object System.Windows.Forms.ToolStripMenuItem("➕  Add Reminder")
$menuView     = New-Object System.Windows.Forms.ToolStripMenuItem("📋  View Reminders")
$menuSep      = New-Object System.Windows.Forms.ToolStripSeparator
$menuExit     = New-Object System.Windows.Forms.ToolStripMenuItem("❌  Exit")

$menu.Items.Add($menuAdd)  | Out-Null
$menu.Items.Add($menuView) | Out-Null
$menu.Items.Add($menuSep)  | Out-Null
$menu.Items.Add($menuExit) | Out-Null

$trayIcon.ContextMenuStrip = $menu

# Menu click handlers
$menuAdd.add_Click({ Add-Reminder })
$menuView.add_Click({ View-Reminders })
$menuExit.add_Click({
    $trayIcon.Visible = $false
    $trayIcon.Dispose()
    [System.Windows.Forms.Application]::Exit()
})

# Double-click tray icon = Add Reminder
$trayIcon.add_DoubleClick({ Add-Reminder })

# ============================================================
#   TIMER: Check reminders every hour
# ============================================================
$timer          = New-Object System.Windows.Forms.Timer
$timer.Interval = 3600000  # 1 hour in milliseconds
$timer.add_Tick({ Check-Reminders })
$timer.Start()

# Also check once on startup after 60 seconds
$startupTimer          = New-Object System.Windows.Forms.Timer
$startupTimer.Interval = 60000  # 1 minute
$startupTimer.add_Tick({
    $startupTimer.Stop()
    Check-Reminders
})
$startupTimer.Start()

Write-Log "ReminderBot started."
Show-Notification "ReminderBot is running!" "Right-click the tray icon to add a reminder."

# ============================================================
#   RUN THE APP
# ============================================================
[System.Windows.Forms.Application]::Run()