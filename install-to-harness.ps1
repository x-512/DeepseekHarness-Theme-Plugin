param([string]$HarnessRoot)
$ErrorActionPreference = 'Stop'
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
function Find-HarnessRoot {
  foreach ($candidate in @('D:\AI-Coding-Tools\DeepSeek',(Join-Path $env:LOCALAPPDATA 'DeepSeekHarness'))) {
    if (Test-Path (Join-Path $candidate 'launcher\DeepSeek Harness.exe')) { return $candidate }
  }
  Add-Type -AssemblyName System.Windows.Forms
  $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
  $dialog.Description = 'Select the DeepSeek Harness installation folder.'
  $dialog.ShowNewFolderButton = $false
  if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) { throw 'No Harness folder was selected.' }
  return $dialog.SelectedPath
}
if (-not $HarnessRoot) { $HarnessRoot = Find-HarnessRoot }
$HarnessRoot = (Resolve-Path $HarnessRoot).Path
$Launcher = Join-Path $HarnessRoot 'launcher'
$HarnessExe = Join-Path $Launcher 'DeepSeek Harness.exe'
$AppTheme = Join-Path $HarnessRoot 'app\node_modules\@deepseek-ai\dsh-theme-lulu'
$PatchPath = Join-Path $HarnessRoot 'data\profiles\web\cordis.patch.yml'
$SourceTheme = Join-Path $PackageRoot 'profile-template\web\plugins\dsh-theme-lulu'
if (-not (Test-Path $HarnessExe)) { throw "Invalid DeepSeek Harness folder: $HarnessRoot" }
New-Item -ItemType Directory -Force $AppTheme | Out-Null
Copy-Item -Path (Join-Path $SourceTheme '*') -Destination $AppTheme -Recurse -Force
Copy-Item -LiteralPath (Join-Path $SourceTheme 'lib\desktop-theme.js') -Destination (Join-Path $Launcher 'desktop-theme.js') -Force
if (-not (Test-Path $PatchPath)) { New-Item -ItemType Directory -Force (Split-Path $PatchPath) | Out-Null; Set-Content $PatchPath '[]' -Encoding UTF8 }
$patch = Get-Content $PatchPath -Raw
if ($patch -notmatch 'id:\s*dsh-theme-lulu') { Add-Content $PatchPath "`n- insert:`n    - id: dsh-theme-lulu`n      name: '@deepseek-ai/dsh-theme-lulu'`n" }
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'DeepSeek Harness.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $HarnessExe
$shortcut.WorkingDirectory = $HarnessRoot
$shortcut.IconLocation = "$(Join-Path $Launcher 'deepseek.ico'),0"
$shortcut.Description = 'DeepSeek Harness with the Lulu theme'
$shortcut.Save()
Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process $HarnessExe -WorkingDirectory $HarnessRoot
Write-Host "Theme installed and desktop shortcut created: $shortcutPath"
