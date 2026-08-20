$ErrorActionPreference = 'Stop'
$BundleRoot = Split-Path -Parent $PSScriptRoot
$StartScript = Join-Path $PSScriptRoot 'start.ps1'
$Icon = Join-Path $PSScriptRoot 'deepseek.ico'
$PowerShell = "$env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
$Desktop = [Environment]::GetFolderPath('Desktop')
$Programs = Join-Path ([Environment]::GetFolderPath('Programs')) 'DeepSeek Harness'
$Shell = New-Object -ComObject WScript.Shell
New-Item -ItemType Directory -Force $Programs | Out-Null

function New-AppShortcut([string]$Path, [string]$Mode, [string]$Description) {
  $shortcut = $Shell.CreateShortcut($Path)
  $shortcut.TargetPath = $PowerShell
  $shortcut.Arguments = "-NoLogo -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$StartScript`" -Mode $Mode"
  $shortcut.WorkingDirectory = $BundleRoot
  $shortcut.IconLocation = "$Icon,0"
  $shortcut.Description = $Description
  $shortcut.Save()
}

foreach ($folder in @($Desktop, $Programs)) {
  New-AppShortcut (Join-Path $folder 'DeepSeek Harness.lnk') 'main' 'DeepSeek Harness desktop application'
  New-AppShortcut (Join-Path $folder 'DeepSeek Harness 手机配对.lnk') 'pairing' 'DeepSeek Harness mobile pairing'
}

Start-Process (Join-Path $Desktop 'DeepSeek Harness.lnk')
