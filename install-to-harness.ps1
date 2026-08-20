param(
  [Parameter(Mandatory = $true)]
  [string]$HarnessRoot
)

$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$profileWeb = Join-Path $HarnessRoot 'profile-template\web'
$patchPath = Join-Path $profileWeb 'cordis.patch.yml'
$pluginSource = Join-Path $repoRoot 'portable-overlay\profile-template\web\plugins\dsh-theme-lulu'
$pluginTarget = Join-Path $profileWeb 'plugins\dsh-theme-lulu'
$appendPath = Join-Path $repoRoot 'portable-overlay\profile-template\web\cordis.patch.append.yml'

if (!(Test-Path $profileWeb)) {
  throw "Cannot find DeepSeek Harness profile-template/web under: $HarnessRoot"
}
if (!(Test-Path $patchPath)) {
  throw "Cannot find cordis.patch.yml: $patchPath"
}
if (!(Test-Path $pluginSource)) {
  throw "Missing bundled plugin source: $pluginSource"
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $pluginTarget) | Out-Null
if (Test-Path $pluginTarget) {
  Remove-Item -Recurse -Force $pluginTarget
}
Copy-Item -Recurse -Force $pluginSource $pluginTarget

$patch = Get-Content -Raw -LiteralPath $patchPath
if ($patch -notmatch 'id:\s*lulu-theme') {
  $append = Get-Content -Raw -LiteralPath $appendPath
  Add-Content -LiteralPath $patchPath -Value $append
  Write-Host "Installed Lulu theme plugin and updated cordis.patch.yml"
} else {
  Write-Host "Installed Lulu theme plugin; cordis.patch.yml already contains lulu-theme"
}

Write-Host "Done. Start DeepSeek Harness and open the web UI. The '切换主题' button should appear automatically."
