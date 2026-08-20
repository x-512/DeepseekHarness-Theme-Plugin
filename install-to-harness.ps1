param([string]$HarnessRoot)
$ErrorActionPreference = 'Stop'
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

function Resolve-HarnessRoot([string]$Path) {
  if (-not $Path) { return $null }
  $Path = [Environment]::ExpandEnvironmentVariables($Path.Trim('"',' '))
  if (-not (Test-Path -LiteralPath $Path)) { return $null }
  $item = Get-Item -LiteralPath $Path
  if (-not $item.PSIsContainer) {
    if ($item.Name -ne 'DeepSeek Harness.exe') { return $null }
    $launcher = $item.Directory
    if ($launcher.Name -ne 'launcher') { return $null }
    return $launcher.Parent.FullName
  }
  if (Test-Path -LiteralPath (Join-Path $item.FullName 'launcher\DeepSeek Harness.exe')) {
    return $item.FullName
  }
  if ($item.Name -eq 'launcher' -and (Test-Path -LiteralPath (Join-Path $item.FullName 'DeepSeek Harness.exe'))) {
    return $item.Parent.FullName
  }
  return $null
}

function Find-HarnessRoot {
  $candidates = @(
    'D:\AI-Coding-Tools\DeepSeek',
    (Join-Path $env:LOCALAPPDATA 'DeepSeekHarness'),
    (Join-Path $env:LOCALAPPDATA 'Programs\DeepSeekHarness'),
    (Join-Path $env:ProgramFiles 'DeepSeek Harness')
  )
  foreach ($candidate in $candidates) {
    $resolved = Resolve-HarnessRoot $candidate
    if ($resolved) { return $resolved }
  }

  Add-Type -AssemblyName System.Windows.Forms
  $dialog = New-Object System.Windows.Forms.OpenFileDialog
  $dialog.Title = 'Select launcher\DeepSeek Harness.exe (you can open This PC and choose drive D:)'
  $dialog.Filter = 'DeepSeek Harness launcher (DeepSeek Harness.exe)|DeepSeek Harness.exe|Executable files (*.exe)|*.exe'
  $dialog.FileName = 'DeepSeek Harness.exe'
  $dialog.CheckFileExists = $true
  $dialog.CheckPathExists = $true
  $dialog.Multiselect = $false
  $dialog.RestoreDirectory = $true
  $dialog.InitialDirectory = [Environment]::GetFolderPath('MyComputer')
  if ($dialog.ShowDialog() -ne [System.Windows.Forms.DialogResult]::OK) {
    throw 'Installation cancelled: DeepSeek Harness.exe was not selected.'
  }
  $resolved = Resolve-HarnessRoot $dialog.FileName
  if (-not $resolved) {
    throw "The selected file is not launcher\DeepSeek Harness.exe: $($dialog.FileName)"
  }
  return $resolved
}

$resolvedRoot = Resolve-HarnessRoot $HarnessRoot
if (-not $resolvedRoot) { $resolvedRoot = Find-HarnessRoot }
$HarnessRoot = $resolvedRoot
$Launcher = Join-Path $HarnessRoot 'launcher'
$HarnessExe = Join-Path $Launcher 'DeepSeek Harness.exe'
$AppTheme = Join-Path $HarnessRoot 'app\node_modules\@deepseek-ai\dsh-theme-lulu'
$PatchPath = Join-Path $HarnessRoot 'data\profiles\web\cordis.patch.yml'
$SourceTheme = Join-Path $PackageRoot 'profile-template\web\plugins\dsh-theme-lulu'

if (-not (Test-Path -LiteralPath $HarnessExe)) { throw "DeepSeek Harness launcher was not found: $HarnessExe" }
if (-not (Test-Path -LiteralPath (Join-Path $SourceTheme 'lib\index.js'))) { throw "Theme package is incomplete: $SourceTheme" }

New-Item -ItemType Directory -Force $AppTheme | Out-Null
Copy-Item -Path (Join-Path $SourceTheme '*') -Destination $AppTheme -Recurse -Force
Copy-Item -LiteralPath (Join-Path $SourceTheme 'lib\desktop-theme.js') -Destination (Join-Path $Launcher 'desktop-theme.js') -Force
if (-not (Test-Path -LiteralPath $PatchPath)) {
  New-Item -ItemType Directory -Force (Split-Path $PatchPath) | Out-Null
  Set-Content -LiteralPath $PatchPath '[]' -Encoding UTF8
}
$patch = Get-Content -LiteralPath $PatchPath -Raw
if ($patch -notmatch 'id:\s*dsh-theme-lulu') {
  Add-Content -LiteralPath $PatchPath "`n- insert:`n    - id: dsh-theme-lulu`n      name: '@deepseek-ai/dsh-theme-lulu'`n"
}

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'DeepSeek Harness.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $HarnessExe
$shortcut.WorkingDirectory = $HarnessRoot
$icon = Join-Path $Launcher 'deepseek.ico'
$shortcut.IconLocation = if (Test-Path -LiteralPath $icon) { "$icon,0" } else { "$HarnessExe,0" }
$shortcut.Description = 'DeepSeek Harness with the Lulu theme'
$shortcut.Save()

Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process -FilePath $HarnessExe -WorkingDirectory $HarnessRoot
Write-Host "Theme installed successfully: $HarnessRoot"
Write-Host "Desktop shortcut created: $shortcutPath"
