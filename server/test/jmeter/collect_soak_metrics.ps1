param(
  [int]$DurationHours = 2,
  [int]$SampleEverySec = 300,
  [string]$OutputCsv = ".\\results\\soak_metrics.csv",
  [string]$RedisContainer = "redis",
  [string]$RabbitMQContainer = "rabbitmq",
  [string]$MySQLContainer = "mysql",
  [string]$MySQLExePath = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe",
  [string]$MySQLUser = "root",
  [string]$MySQLPassword = "root",
  [int]$BackendPort = 3000
)

$ErrorActionPreference = "Continue"
Set-Location $PSScriptRoot

function Get-BackendProcessId {
  try {
    $conn = Get-NetTCPConnection -State Listen -LocalPort $BackendPort -ErrorAction Stop | Select-Object -First 1
    return $conn.OwningProcess
  } catch { return $null }
}

function Get-BackendMemoryMB {
  param([int]$Pid)
  if (-not $Pid) { return $null }
  try {
    $p = Get-Process -Id $Pid -ErrorAction Stop
    return [math]::Round($p.WorkingSet64 / 1MB, 2)
  } catch { return $null }
}

function Get-RedisMemoryMB {
  param([string]$Container)
  try {
    $raw = docker exec $Container redis-cli info memory 2>$null
    $line = $raw | Select-String "used_memory:"
    if (-not $line) { return $null }
    return [math]::Round(([double]((($line -split ":")[1]).Trim())) / 1MB, 2)
  } catch { return $null }
}

function Get-MySQLConnections {
  param([string]$Container, [string]$ExePath, [string]$User, [string]$Password)
  try {
    $containerNames = docker ps --format "{{.Names}}" 2>$null
    if ($Container -and ($containerNames | Where-Object { $_ -eq $Container })) {
      $raw = docker exec $Container mysql -u$User -p$Password -N -e "show status like 'Threads_connected';" 2>$null
      if ($raw) { return [int](($raw -split "\s+")[-1]) }
    }
    if (Test-Path $ExePath) {
      $raw = & $ExePath -u$User -p$Password -N -e "show status like 'Threads_connected';" 2>$null
      if ($raw) { return [int](($raw -split "\s+")[-1]) }
    }
    return $null
  } catch { return $null }
}

function Get-RabbitBacklog {
  param([string]$Container)
  try {
    $raw = docker exec $Container rabbitmqctl list_queues name messages 2>$null
    if (-not $raw) { return $null }
    $sum = 0
    foreach ($line in $raw) {
      if ($line -match "^\S+\s+(\d+)$") { $sum += [int]$matches[1] }
    }
    return $sum
  } catch { return $null }
}

function Write-Row {
  param([string]$Path, [object]$Row)
  if (-not (Test-Path (Split-Path -Parent $Path))) {
    New-Item -ItemType Directory -Force -Path (Split-Path -Parent $Path) | Out-Null
  }
  if (-not (Test-Path $Path)) {
    ($Row | ConvertTo-Csv -NoTypeInformation) | Set-Content -Path $Path -Encoding UTF8
  } else {
    ($Row | ConvertTo-Csv -NoTypeInformation | Select-Object -Skip 1) | Add-Content -Path $Path -Encoding UTF8
  }
}

$deadline = (Get-Date).AddHours($DurationHours)
while ((Get-Date) -lt $deadline) {
  $backendPid = Get-BackendProcessId
  $row = [PSCustomObject]@{
    timestamp         = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
    backend_pid       = $backendPid
    backend_memory_mb = Get-BackendMemoryMB -Pid $backendPid
    redis_memory_mb   = Get-RedisMemoryMB -Container $RedisContainer
    mysql_connections = Get-MySQLConnections -Container $MySQLContainer -ExePath $MySQLExePath -User $MySQLUser -Password $MySQLPassword
    rabbitmq_backlog  = Get-RabbitBacklog -Container $RabbitMQContainer
  }
  Write-Row -Path $OutputCsv -Row $row
  Start-Sleep -Seconds $SampleEverySec
}
