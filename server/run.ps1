$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$serviceAccount = Join-Path $PSScriptRoot "secrets\firebase-adminsdk.example.json"

if (!(Test-Path $serviceAccount)) {
  Write-Host "FCM service account not found: $serviceAccount" -ForegroundColor Red
  Write-Host "Place the JSON file under server\\secrets and retry." -ForegroundColor Yellow
  exit 1
}

Push-Location $PSScriptRoot
try {
  go run .\main.go --fcm-service-account "$serviceAccount" --fcm-project-id "moochub-8987a"
} finally {
  Pop-Location
}
