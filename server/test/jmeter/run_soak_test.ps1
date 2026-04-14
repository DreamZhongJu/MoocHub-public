param(
  [string]$JMeterBin = "D:\Document\apache-jmeter-5.6.3\apache-jmeter-5.6.3\bin\jmeter.bat",
  [string]$Plan = ".\scenario6_soak_mixed_rw.jmx",
  [string]$ResultCsv = ".\results\soak_all.csv",
  [string]$LogFile = ".\results\soak.log",
  [string]$MetricsCsv = ".\results\soak_metrics.csv",
  [int]$DurationHours = 2,
  [int]$SampleEverySec = 300,
  [string]$RedisContainer = "redis",
  [string]$RabbitMQContainer = "rabbitmq",
  [string]$MySQLContainer = "mysql",
  [string]$MySQLExePath = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe",
  [string]$MySQLUser = "root",
  [string]$MySQLPassword = "root"
)

$ErrorActionPreference = "Stop"
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
Set-Location $scriptDir
New-Item -ItemType Directory -Force -Path ".\results" | Out-Null

$collector = Start-Process powershell -PassThru -WindowStyle Hidden -ArgumentList @(
  "-NoProfile",
  "-ExecutionPolicy", "Bypass",
  "-File", (Join-Path $scriptDir "collect_soak_metrics.ps1"),
  "-DurationHours", $DurationHours,
  "-SampleEverySec", $SampleEverySec,
  "-OutputCsv", ((Resolve-Path ".\results").Path + "\soak_metrics.csv"),
  "-RedisContainer", $RedisContainer,
  "-RabbitMQContainer", $RabbitMQContainer,
  "-MySQLContainer", $MySQLContainer,
  "-MySQLExePath", $MySQLExePath,
  "-MySQLUser", $MySQLUser,
  "-MySQLPassword", $MySQLPassword
)

Write-Host "Metrics collector started, pid=$($collector.Id)"

try {
  & $JMeterBin -n -t $Plan -l $ResultCsv -j $LogFile
}
finally {
  if ($collector -and !$collector.HasExited) {
    Stop-Process -Id $collector.Id -Force -ErrorAction SilentlyContinue
  }
}

Write-Host "Soak test finished."
Write-Host "Result CSV: $ResultCsv"
Write-Host "JMeter log: $LogFile"
Write-Host "Metrics CSV: $MetricsCsv"
