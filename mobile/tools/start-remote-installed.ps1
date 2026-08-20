param(
  [Parameter(Mandatory = $true)][string]$Node
)
$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $PSScriptRoot
$proxy = Join-Path $Root 'tools\secure-remote-proxy.js'
$cloudflared = Join-Path $Root 'tools\cloudflared.exe'
$data = if ($env:DSH_REMOTE_DATA_DIR) { $env:DSH_REMOTE_DATA_DIR } else { Join-Path $Root 'data' }
$logs = Join-Path $Root 'logs'
New-Item -ItemType Directory -Force $data,$logs | Out-Null
Remove-Item (Join-Path $data 'remote-url.txt') -Force -ErrorAction SilentlyContinue
$env:REMOTE_PROXY_HOST = '127.0.0.1'
$env:REMOTE_PROXY_PORT = '3081'
Start-Process -FilePath $Node -ArgumentList @($proxy) -WorkingDirectory $Root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logs 'remote-proxy.log') -RedirectStandardError (Join-Path $logs 'remote-proxy-error.log')
$deadline = (Get-Date).AddSeconds(20)
$connection = $null
do {
  try { $connection = Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 3081 -State Listen -ErrorAction Stop; break } catch { Start-Sleep -Milliseconds 300 }
} while ((Get-Date) -lt $deadline)
if (-not $connection) { throw 'Secure remote proxy startup failed.' }
$tunnelLog = Join-Path $logs 'cloudflared.log'
$tunnelError = Join-Path $logs 'cloudflared-error.log'
Remove-Item $tunnelLog,$tunnelError -Force -ErrorAction SilentlyContinue
Start-Process -FilePath $cloudflared -ArgumentList @('tunnel','--no-autoupdate','--protocol','http2','--url','http://127.0.0.1:3081') -WorkingDirectory $Root -WindowStyle Hidden -RedirectStandardOutput $tunnelLog -RedirectStandardError $tunnelError
$deadline = (Get-Date).AddSeconds(90)
$url = $null
do {
  foreach ($file in @($tunnelLog,$tunnelError)) {
    if (Test-Path $file) {
      $content = Get-Content $file -Raw
      if ($content) {
        $match = [regex]::Match($content, 'https://[a-z0-9-]+\.trycloudflare\.com')
        if ($match.Success) { $url = $match.Value; break }
      }
    }
  }
  if (-not $url) { Start-Sleep -Milliseconds 500 }
} while (-not $url -and (Get-Date) -lt $deadline)
if (-not $url) { throw 'Cloudflare Tunnel startup timed out.' }
$deadline = (Get-Date).AddSeconds(120)
$publicReady = $false
do {
  try {
    $response = Invoke-WebRequest -UseBasicParsing -Uri $url -TimeoutSec 10
    $publicReady = $response.StatusCode -in @(200,401,403)
  } catch {
    $status = $_.Exception.Response.StatusCode.value__
    $publicReady = $status -in @(401,403)
  }
  if (-not $publicReady) { Start-Sleep -Seconds 1 }
} while (-not $publicReady -and (Get-Date) -lt $deadline)
if (-not $publicReady) { throw 'Cloudflare Tunnel URL was created but did not become reachable.' }
[IO.File]::WriteAllText((Join-Path $data 'remote-url.txt'), $url, [Text.UTF8Encoding]::new($false))
if ($env:DSH_REMOTE_NO_OPEN -ne '1') { Start-Process 'http://127.0.0.1:3081/remote-pairing' }
