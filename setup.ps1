#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Windows 11 Pro initial setup script.
.DESCRIPTION
    Installs a standard set of applications via winget and the Microsoft Store,
    enables WSL, configures Remote Desktop (RDP), and switches the system to
    dark mode.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---------------------------------------------------------------------------
# 1. winget packages
# ---------------------------------------------------------------------------
$wingetPackages = @(
    'Mozilla.Firefox',
    'Google.Chrome',
    'Microsoft.Powershell',
    'Microsoft.Powertoys',
    'Microsoft.VisualStudioCode',
    'Git.Git',
    'TheDocumentFoundation.LibreOffice',
    'Google.GoogleDrive',
    'Discord.Discord',
    'Telegram.TelegramDesktop',
    'WiresharkFoundation.Wireshark'
)

foreach ($pkg in $wingetPackages) {
    Write-Host "Installing $pkg ..."
    winget install --id $pkg --exact --accept-source-agreements --accept-package-agreements
}

# ---------------------------------------------------------------------------
# 2. Microsoft Store apps (by product ID)
# ---------------------------------------------------------------------------
$storeApps = @(
    '9PKTQ5699M62',  # iCloud
    'XPFFZHVGQWWLHB' # OneNote
)

foreach ($app in $storeApps) {
    Write-Host "Installing Store app $app ..."
    winget install --id $app --accept-source-agreements --accept-package-agreements
}

# ---------------------------------------------------------------------------
# 3. WSL
# ---------------------------------------------------------------------------
Write-Host 'Installing WSL ...'
wsl --install

# ---------------------------------------------------------------------------
# 4. Remote Desktop (RDP)
# ---------------------------------------------------------------------------
Write-Host 'Enabling Remote Desktop ...'
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server' `
    -Name 'fDenyTSConnections' -Value 0
Set-ItemProperty -Path 'HKLM:\System\CurrentControlSet\Control\Terminal Server\WinStations\RDP-TCP\' `
    -Name 'UserAuthentication' -Value 1
Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'

# ---------------------------------------------------------------------------
# 5. Dark mode
# ---------------------------------------------------------------------------
Write-Host 'Enabling dark mode ...'
@('AppsUseLightTheme', 'SystemUsesLightTheme') | ForEach-Object {
    Set-ItemProperty `
        -Path 'HKCU:SOFTWARE\Microsoft\Windows\CurrentVersion\Themes\Personalize' `
        -Name $_ -Value 0
}

# Restart Explorer so the theme change is applied visually immediately.
Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
Start-Process explorer

Write-Host 'Setup complete.'
