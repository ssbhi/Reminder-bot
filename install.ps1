# ============================================================
#   ReminderBot Installer
#   Run this once to install ReminderBot on your PC
# ============================================================
 
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   ReminderBot Installer" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
 
$installFolder = "$env:APPDATA\ReminderBot"
$scriptPath    = "$installFolder\ReminderBot.ps1"
$startupFolder = [System.Environment]::GetFolderPath("Startup")
$shortcutPath  = "$startupFolder\ReminderBot.lnk"
 
# Step 1: Create install folder
Write-Host "[1/4] Creating install folder..." -ForegroundColor Yellow
if (-not (Test-Path $installFolder)) {
    New-Item -ItemType Directory -Path $installFolder | Out-Null
}
Write-Host "      Done -> $installFolder" -ForegroundColor Green
 
# Step 2: Download ReminderBot.ps1 from GitHub
Write-Host "[2/4] Downloading ReminderBot..." -ForegroundColor Yellow
try {
    Invoke-WebRequest `
        -Uri "https://raw.githubusercontent.com/ssbhi/reminderbot/main/ReminderBot.ps1" `
        -OutFile $scriptPath
    Write-Host "      Done -> ReminderBot.ps1 downloaded" -ForegroundColor Green
} catch {
    Write-Host "      FAILED to download. Check your internet connection." -ForegroundColor Red
    exit
}
 
# Step 3: Create startup shortcut
Write-Host "[3/4] Adding to Windows startup..." -ForegroundColor Yellow
$wsh      = New-Object -ComObject WScript.Shell
$shortcut = $wsh.CreateShortcut($shortcutPath)
$shortcut.TargetPath  = "powershell.exe"
$shortcut.Arguments   = "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`""
$shortcut.Description = "ReminderBot - Desktop Reminder App"
$shortcut.Save()
Write-Host "      Done -> Added to startup" -ForegroundColor Green
 
# Step 4: Launch it now
Write-Host "[4/4] Launching ReminderBot..." -ForegroundColor Yellow
Start-Process powershell.exe -ArgumentList "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$scriptPath`"" -WindowStyle Hidden
Write-Host "      Done -> ReminderBot is running in your system tray!" -ForegroundColor Green
 
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   Installation Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "Look for the ReminderBot icon in your system tray (bottom right)." -ForegroundColor White
Write-Host "Right-click it to add your first reminder!" -ForegroundColor White
Write-Host ""
