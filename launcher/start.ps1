param(
  [ValidateSet('main', 'pairing')][string]$Mode = 'main'
)
$ErrorActionPreference = 'Stop'
$BundleRoot = Split-Path -Parent $PSScriptRoot
$AppRoot = Join-Path $BundleRoot 'app'
$Node = Join-Path $BundleRoot 'runtime\node-v24.19.0-win-x64\node.exe'
$Dsh = Join-Path $AppRoot 'node_modules\@deepseek-ai\dsh\lib\bin.js'
$MobileRoot = Join-Path $BundleRoot 'mobile'
$MobileScript = Join-Path $MobileRoot 'tools\start-remote-installed.ps1'
$DataRoot = Join-Path $env:LOCALAPPDATA 'DeepSeekHarnessPortable'
$ProfileRoot = Join-Path $DataRoot 'profiles\web'
$ProfileTemplate = Join-Path $BundleRoot 'profile-template\web'
$Workspace = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'DeepSeekHarnessWorkspace'
$ChromeProfile = Join-Path $DataRoot 'chrome-profile'
$MobileData = Join-Path $DataRoot 'mobile-remote'

function Find-Chrome {
  $candidates = @(
    (Join-Path $env:ProgramFiles 'Google\Chrome\Application\chrome.exe'),
    (Join-Path ${env:ProgramFiles(x86)} 'Google\Chrome\Application\chrome.exe'),
    (Join-Path $env:LOCALAPPDATA 'Google\Chrome\Application\chrome.exe')
  )
  foreach ($candidate in $candidates) { if ($candidate -and (Test-Path $candidate)) { return $candidate } }
  throw 'Google Chrome is required. Install Chrome and run this shortcut again.'
}

function Test-LocalPort([int]$Port) {
  return [bool](Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort $Port -State Listen -ErrorAction SilentlyContinue)
}

function Wait-LocalPort([int]$Port, [int]$Seconds) {
  $deadline = (Get-Date).AddSeconds($Seconds)
  do {
    if (Test-LocalPort $Port) { return }
    Start-Sleep -Milliseconds 400
  } while ((Get-Date) -lt $deadline)
  throw "Local service port $Port did not start."
}

$Chrome = Find-Chrome
New-Item -ItemType Directory -Force $DataRoot,$Workspace | Out-Null
if (-not (Test-Path (Join-Path $ProfileRoot 'package.json'))) {
  New-Item -ItemType Directory -Force (Split-Path -Parent $ProfileRoot) | Out-Null
  Copy-Item $ProfileTemplate $ProfileRoot -Recurse -Force
}

$TemplateTheme = Join-Path $ProfileTemplate 'plugins\dsh-theme-lulu'
$ProfileTheme = Join-Path $ProfileRoot 'plugins\dsh-theme-lulu'
$ProfilePatch = Join-Path $ProfileRoot 'cordis.patch.yml'
if (Test-Path $TemplateTheme) {
  New-Item -ItemType Directory -Force (Split-Path -Parent $ProfileTheme) | Out-Null
  if (Test-Path $ProfileTheme) { Remove-Item -Recurse -Force $ProfileTheme }
  Copy-Item $TemplateTheme $ProfileTheme -Recurse -Force
  if ((Test-Path $ProfilePatch) -and -not ((Get-Content -Raw $ProfilePatch) -match 'id:\s*lulu-theme')) {
    Add-Content -LiteralPath $ProfilePatch -Value "`n# Bundle the Lulu theme plugin directly into this DeepSeek Harness profile so it is available by default.`n- insert:`n    - id: lulu-theme`n      name: './plugins/dsh-theme-lulu/lib/index.js'`n"
  }
}

if (-not (Test-LocalPort 3080)) {
  $env:DSH_HOME = $DataRoot
  $env:DSH_AGENTS_HOME = Join-Path $DataRoot '.agents'
  Start-Process -FilePath $Node -ArgumentList @($Dsh, 'web', '--host', '127.0.0.1', '--port', '3080') -WorkingDirectory $Workspace -WindowStyle Hidden
  Wait-LocalPort 3080 90
}

if ($Mode -eq 'pairing' -and -not (Test-LocalPort 3081)) {
  $env:DSH_REMOTE_DATA_DIR = $MobileData
  $env:DSH_REMOTE_NO_OPEN = '1'
  Start-Process -FilePath 'powershell.exe' -ArgumentList @('-NoLogo', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $MobileScript, '-Node', $Node) -WorkingDirectory $MobileRoot -WindowStyle Hidden
  Wait-LocalPort 3081 40
}

$url = if ($Mode -eq 'pairing') { 'http://127.0.0.1:3081/remote-pairing' } else { 'http://127.0.0.1:3080' }
Start-Process -FilePath $Chrome -ArgumentList @(
  "--app=$url",
  "--user-data-dir=$ChromeProfile",
  '--no-first-run',
  '--disable-default-apps',
  '--start-maximized'
) -WorkingDirectory $Workspace
