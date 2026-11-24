$listener = Get-NetTCPConnection -LocalPort 8081 -State Listen -ErrorAction SilentlyContinue
if (-not $listener) {
  exit 1
}

$owner = $listener[0].OwningProcess
$status = 0
try {
  $response = Invoke-WebRequest 'http://127.0.0.1:8081/tp7/departements' -UseBasicParsing -TimeoutSec 2
  $status = [int]$response.StatusCode
} catch {
  if ($_.Exception.Response) {
    $status = [int]$_.Exception.Response.StatusCode
  }
}

if ($status -notin @(200, 401, 403)) {
  Write-Output "OCCUPIED $owner"
  exit 0
}

$corsOrigin = ''
try {
  $preflight = Invoke-WebRequest 'http://127.0.0.1:8081/login' -Method Options `
    -Headers @{
      Origin = 'http://localhost:53000'
      'Access-Control-Request-Method' = 'POST'
      'Access-Control-Request-Headers' = 'authorization,content-type'
    } -UseBasicParsing -TimeoutSec 2
  $corsOrigin = [string]$preflight.Headers['Access-Control-Allow-Origin']
} catch {
  if ($_.Exception.Response) {
    $corsOrigin = [string]$_.Exception.Response.Headers['Access-Control-Allow-Origin']
  }
}

if ($corsOrigin -eq 'http://localhost:53000') {
  Write-Output "RUNNING $owner"
} else {
  Write-Output "STALE $owner"
}
