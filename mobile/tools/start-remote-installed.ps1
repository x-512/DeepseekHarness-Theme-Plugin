param([Parameter(Mandatory=$true)][string]$Node)
$ErrorActionPreference='Stop'
$Root=Split-Path -Parent $PSScriptRoot
$proxy=Join-Path $Root 'tools\secure-remote-proxy.js'
$cloudflared=Join-Path $Root 'tools\cloudflared.exe'
$data=if($env:DSH_REMOTE_DATA_DIR){$env:DSH_REMOTE_DATA_DIR}else{Join-Path $Root 'data'}
$logs=Join-Path $Root 'logs'
New-Item -ItemType Directory -Force $data,$logs|Out-Null
$urlFile=Join-Path $data 'remote-url.txt'
$existing=Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 3081 -State Listen -ErrorAction SilentlyContinue
if($existing -and (Test-Path $urlFile)){
  $existingUrl=(Get-Content $urlFile -Raw).Trim()
  try{$local=Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:3081/remote-pairing' -TimeoutSec 5;try{$public=Invoke-WebRequest -UseBasicParsing $existingUrl -TimeoutSec 10;$status=$public.StatusCode}catch{$status=$_.Exception.Response.StatusCode.value__};if($local.StatusCode -eq 200 -and $status -in @(200,401,403)){return}}catch{}
}
Remove-Item $urlFile -Force -ErrorAction SilentlyContinue
$env:REMOTE_PROXY_HOST='127.0.0.1';$env:REMOTE_PROXY_PORT='3081'
if(-not $existing){Start-Process $Node -ArgumentList @($proxy) -WorkingDirectory $Root -WindowStyle Hidden -RedirectStandardOutput (Join-Path $logs 'remote-proxy.log') -RedirectStandardError (Join-Path $logs 'remote-proxy-error.log')}
$deadline=(Get-Date).AddSeconds(20)
do{try{$existing=Get-NetTCPConnection -LocalAddress 127.0.0.1 -LocalPort 3081 -State Listen -ErrorAction Stop;break}catch{Start-Sleep -Milliseconds 300}}while((Get-Date)-lt$deadline)
if(-not $existing){throw 'Secure remote proxy startup failed.'}
$local=Invoke-WebRequest -UseBasicParsing 'http://127.0.0.1:3081/remote-pairing' -TimeoutSec 5
if($local.StatusCode -ne 200){throw 'Port 3081 is occupied by an incompatible service.'}
$tunnelLog=Join-Path $logs 'cloudflared.log';$tunnelError=Join-Path $logs 'cloudflared-error.log'
Remove-Item $tunnelLog,$tunnelError -Force -ErrorAction SilentlyContinue
Start-Process $cloudflared -ArgumentList @('tunnel','--no-autoupdate','--protocol','http2','--url','http://127.0.0.1:3081') -WorkingDirectory $Root -WindowStyle Hidden -RedirectStandardOutput $tunnelLog -RedirectStandardError $tunnelError
$deadline=(Get-Date).AddSeconds(90);$url=$null
do{foreach($file in @($tunnelLog,$tunnelError)){if(Test-Path $file){$match=[regex]::Match((Get-Content $file -Raw),'https://[a-z0-9-]+\.trycloudflare\.com');if($match.Success){$url=$match.Value;break}}};if(-not $url){Start-Sleep -Milliseconds 500}}while(-not $url -and (Get-Date)-lt$deadline)
if(-not $url){throw 'Cloudflare Tunnel startup timed out.'}
$deadline=(Get-Date).AddSeconds(120);$ready=$false
do{try{$response=Invoke-WebRequest -UseBasicParsing $url -TimeoutSec 10;$ready=$response.StatusCode -in @(200,401,403)}catch{$ready=$_.Exception.Response.StatusCode.value__ -in @(401,403)};if(-not $ready){Start-Sleep 1}}while(-not $ready -and (Get-Date)-lt$deadline)
if(-not $ready){throw 'Cloudflare Tunnel URL did not become reachable.'}
[IO.File]::WriteAllText($urlFile,$url,[Text.UTF8Encoding]::new($false))
