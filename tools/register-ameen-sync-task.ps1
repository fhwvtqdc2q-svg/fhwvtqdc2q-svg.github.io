param(
  [string]$TaskName = "TOBACCO Ameen Sync",
  [int]$IntervalMinutes = 1,
  [int]$LowThreshold = 50
)

$ErrorActionPreference = "Stop"

$agentPath = Join-Path $PSScriptRoot "ameen-sync-agent.ps1"
if (-not (Test-Path -LiteralPath $agentPath)) {
  throw "Sync agent not found: $agentPath"
}

$projectRoot = Split-Path -Parent $PSScriptRoot
$logPath = Join-Path $projectRoot "logs\ameen-sync.log"
$logDirectory = Split-Path -Parent $logPath
if (-not (Test-Path -LiteralPath $logDirectory)) {
  New-Item -ItemType Directory -Force -Path $logDirectory | Out-Null
}

$powershellPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$taskCommand = "`"$powershellPath`" -NoProfile -ExecutionPolicy Bypass -File `"$agentPath`" -Once -LowThreshold $LowThreshold -LogPath `"$logPath`""

$result = & schtasks.exe /Create /TN $TaskName /SC MINUTE /MO $IntervalMinutes /TR $taskCommand /F 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Failed to register scheduled task. schtasks.exe output: $result"
}

Write-Host "Scheduled task registered: $TaskName"
Write-Host "It will run every $IntervalMinutes minute(s)."
Write-Host "Log file: $logPath"
