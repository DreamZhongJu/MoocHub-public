$ErrorActionPreference = "Stop"

$root = Split-Path -Parent $PSScriptRoot
$serviceAccount = Join-Path $PSScriptRoot "secrets\firebase-adminsdk.example.json"
$qqEnv = Join-Path $PSScriptRoot "secrets\qq.env"

if (Test-Path $qqEnv) {
  Get-Content $qqEnv | ForEach-Object {
    $line = $_.Trim()
    if ($line -eq "" -or $line.StartsWith("#")) { return }
    $parts = $line -split "=", 2
    if ($parts.Length -ne 2) { return }
    $name = $parts[0].Trim()
    $value = $parts[1].Trim()
    if ($name -ne "") {
      Set-Item -Path "Env:$name" -Value $value
    }
  }
}

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
