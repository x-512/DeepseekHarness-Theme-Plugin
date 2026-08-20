param([string]$InstallRoot)
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$PackageRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$NodeVersion = '24.19.0'
$NodeFolder = "node-v$NodeVersion-win-x64"
$NodeSha256 = '57f71ab3652e797d84acddc79c81cc9ff1c6ddb2a1974cdb83f00fee9bff4c73'
$HarnessVersion = '0.1.0-rc.8'
$WebViewVersion = '1.0.4129.50'
$WebViewSha256 = 'd3934f482d484b89fb4825df720c710664e1143a1e90f7b3a60794ef33f473d2'
$CloudflaredVersion = '2026.8.2'
$CloudflaredSha256 = 'c29eee2b121f5436a642eed69fd9767da7e7b8c510fa50aaa130337f931357b5'
$MobileApkVersion = '1.3.3'
$MobileApkSha256 = '0817ab3310f997274f63e0335faf44f26e8d811b7cee25d3d0dc15d689ec459a'

if (-not $InstallRoot) {
  $InstallRoot = if (Test-Path 'D:\') { 'D:\DeepSeekHarness' } else { Join-Path $env:LOCALAPPDATA 'DeepSeekHarness' }
}
$InstallRoot = [IO.Path]::GetFullPath([Environment]::ExpandEnvironmentVariables($InstallRoot))
$RuntimeRoot = Join-Path $InstallRoot 'runtime'
$NodeRoot = Join-Path $RuntimeRoot $NodeFolder
$NodeExe = Join-Path $NodeRoot 'node.exe'
$NpmCmd = Join-Path $NodeRoot 'npm.cmd'
$AppRoot = Join-Path $InstallRoot 'app'
$LauncherRoot = Join-Path $InstallRoot 'launcher'
$DataRoot = Join-Path $InstallRoot 'data'
$WorkspaceRoot = Join-Path $InstallRoot 'workspace'
$TempRoot = Join-Path $InstallRoot '.install-cache'

function Download-Verified([string]$Url, [string]$Destination, [string]$Sha256) {
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
      Write-Host "Downloading: $Url"
      Invoke-WebRequest -UseBasicParsing -Uri $Url -OutFile $Destination
      $actual = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash.ToLowerInvariant()
      if ($actual -ne $Sha256.ToLowerInvariant()) { throw "Checksum mismatch: $Destination" }
      return
    } catch {
      Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
      if ($attempt -eq 3) { throw }
      Start-Sleep -Seconds (2 * $attempt)
    }
  }
}

function Copy-Theme {
  $source = Join-Path $PackageRoot 'profile-template\web\plugins\dsh-theme-lulu'
  if (-not (Test-Path (Join-Path $source 'lib\index.js'))) { throw 'The downloaded theme package is incomplete.' }
  $destination = Join-Path $AppRoot 'node_modules\@deepseek-ai\dsh-theme-lulu'
  $profileRoot = Join-Path $DataRoot 'profiles\web'
  $profileDestination = Join-Path $profileRoot 'node_modules\@deepseek-ai\dsh-theme-lulu'
  New-Item -ItemType Directory -Force $destination,$profileDestination | Out-Null
  Copy-Item (Join-Path $source '*') $destination -Recurse -Force
  Copy-Item (Join-Path $source '*') $profileDestination -Recurse -Force
  Copy-Item (Join-Path $source 'lib\desktop-theme.js') (Join-Path $LauncherRoot 'desktop-theme.js') -Force
  $patch = Join-Path $profileRoot 'cordis.patch.yml'
  New-Item -ItemType Directory -Force $profileRoot | Out-Null
  if (-not (Test-Path $patch)) { Set-Content -LiteralPath $patch '[]' -Encoding UTF8 }
  $content = Get-Content -LiteralPath $patch -Raw
  if ($content -notmatch 'id:\s*dsh-theme-lulu') {
    $entry = "- insert:`n    - id: dsh-theme-lulu`n      name: '@deepseek-ai/dsh-theme-lulu'`n"
    if ($content.Trim() -eq '[]') { Set-Content -LiteralPath $patch $entry -Encoding UTF8 }
    else { Add-Content -LiteralPath $patch "`n$entry" }
  }
}

Write-Host "Installing DeepSeek Harness to: $InstallRoot"
New-Item -ItemType Directory -Force $InstallRoot,$RuntimeRoot,$AppRoot,$LauncherRoot,$DataRoot,$WorkspaceRoot,$TempRoot | Out-Null

if (-not (Test-Path $NodeExe)) {
  $nodeZip = Join-Path $TempRoot "$NodeFolder.zip"
  Download-Verified "https://nodejs.org/dist/v$NodeVersion/$NodeFolder.zip" $nodeZip $NodeSha256
  Expand-Archive -LiteralPath $nodeZip -DestinationPath $RuntimeRoot -Force
}
if (-not (Test-Path $NodeExe) -or -not (Test-Path $NpmCmd)) { throw 'Portable Node.js installation failed.' }

$HarnessCli = Join-Path $AppRoot 'node_modules\@deepseek-ai\dsh\lib\bin.js'
if (-not (Test-Path $HarnessCli)) {
  Write-Host "Installing DeepSeek Harness $HarnessVersion..."
  & $NpmCmd install --prefix $AppRoot --omit=dev --no-audit --no-fund --save-exact "@deepseek-ai/dsh@$HarnessVersion"
  if ($LASTEXITCODE -ne 0) { throw "DeepSeek Harness npm installation failed with exit code $LASTEXITCODE." }
}
if (-not (Test-Path $HarnessCli)) { throw 'DeepSeek Harness command was not installed.' }

$webViewCore = Join-Path $LauncherRoot 'Microsoft.Web.WebView2.Core.dll'
if (-not (Test-Path $webViewCore)) {
  $nupkg = Join-Path $TempRoot "Microsoft.Web.WebView2.$WebViewVersion.nupkg.zip"
  $unpacked = Join-Path $TempRoot 'webview2-package'
  Download-Verified "https://api.nuget.org/v3-flatcontainer/microsoft.web.webview2/$WebViewVersion/microsoft.web.webview2.$WebViewVersion.nupkg" $nupkg $WebViewSha256
  Remove-Item $unpacked -Recurse -Force -ErrorAction SilentlyContinue
  Expand-Archive -LiteralPath $nupkg -DestinationPath $unpacked -Force
  Copy-Item (Join-Path $unpacked 'lib\net462\Microsoft.Web.WebView2.Core.dll') $LauncherRoot -Force
  Copy-Item (Join-Path $unpacked 'lib\net462\Microsoft.Web.WebView2.WinForms.dll') $LauncherRoot -Force
  Copy-Item (Join-Path $unpacked 'runtimes\win-x64\native\WebView2Loader.dll') $LauncherRoot -Force
}

$MobileRoot = Join-Path $InstallRoot 'mobile'
$MobileTools = Join-Path $MobileRoot 'tools'
$MobileAndroid = Join-Path $MobileRoot 'Android'
New-Item -ItemType Directory -Force $MobileTools,$MobileAndroid | Out-Null
Copy-Item (Join-Path $PackageRoot 'mobile\tools\start-remote-installed.ps1') $MobileTools -Force
Copy-Item (Join-Path $PackageRoot 'mobile\tools\secure-remote-proxy.js') $MobileTools -Force
$Cloudflared = Join-Path $MobileTools 'cloudflared.exe'
if (-not (Test-Path $Cloudflared)) {
  Download-Verified "https://github.com/cloudflare/cloudflared/releases/download/$CloudflaredVersion/cloudflared-windows-amd64.exe" $Cloudflared $CloudflaredSha256
}
$QrModule = Join-Path $MobileTools 'npm\node_modules\qrcode-terminal\package.json'
if (-not (Test-Path $QrModule)) {
  & $NpmCmd install --prefix (Join-Path $MobileTools 'npm') --omit=dev --no-audit --no-fund --save-exact 'qrcode-terminal@0.12.0'
  if ($LASTEXITCODE -ne 0) { throw 'QR code dependency installation failed.' }
}
$MobileApk = Join-Path $MobileAndroid 'DeepSeek-Harness-Android.apk'
if (-not (Test-Path $MobileApk)) {
  Download-Verified "https://github.com/x-512/DeepseekHarness-Theme-Plugin/releases/download/mobile-v$MobileApkVersion/DeepSeek-Harness-Android.apk" $MobileApk $MobileApkSha256
}

Copy-Theme
Copy-Item (Join-Path $PackageRoot 'installer\DeepSeekLauncher.cs') $LauncherRoot -Force
Copy-Item (Join-Path $PackageRoot 'installer\deepseek.manifest') $LauncherRoot -Force
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw '.NET Framework 4 compiler is unavailable on this Windows installation.' }
$launcherExe = Join-Path $LauncherRoot 'DeepSeek Harness.exe'
Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $launcherExe } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 500
& $csc /nologo /target:winexe /optimize+ /utf8output "/out:$launcherExe" "/win32manifest:$(Join-Path $LauncherRoot 'deepseek.manifest')" /reference:System.dll /reference:System.Core.dll /reference:System.Drawing.dll /reference:System.Windows.Forms.dll "/reference:$(Join-Path $LauncherRoot 'Microsoft.Web.WebView2.Core.dll')" "/reference:$(Join-Path $LauncherRoot 'Microsoft.Web.WebView2.WinForms.dll')" (Join-Path $LauncherRoot 'DeepSeekLauncher.cs')
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $launcherExe)) { throw 'Native launcher compilation failed.' }

$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = Join-Path $desktop 'DeepSeek Harness.lnk'
$shell = New-Object -ComObject WScript.Shell
$shortcut = $shell.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $launcherExe
$shortcut.WorkingDirectory = $InstallRoot
$shortcut.IconLocation = "$launcherExe,0"
$shortcut.Description = 'DeepSeek Harness with Lulu theme'
$shortcut.Save()

Remove-Item $TempRoot -Recurse -Force -ErrorAction SilentlyContinue
Get-Process -Name 'DeepSeek Harness' -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $launcherExe } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Process -FilePath $launcherExe -WorkingDirectory $InstallRoot
Write-Host "Installation completed: $InstallRoot"
Write-Host "Desktop shortcut created: $shortcutPath"
