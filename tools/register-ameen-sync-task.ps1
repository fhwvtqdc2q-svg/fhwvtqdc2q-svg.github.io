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

$launcherPath = "C:\tmp\tobacco-ameen-sync.cmd"
$launcherDirectory = Split-Path -Parent $launcherPath
if (-not (Test-Path -LiteralPath $launcherDirectory)) {
  New-Item -ItemType Directory -Force -Path $launcherDirectory | Out-Null
}

$launcherContent = @"
@echo off
setlocal
set "PROJECT_ROOT=$projectRoot"
set "AGENT_PATH=$agentPath"
set "STOCK_QUERY_PATH=$projectRoot\tools\ameen-stock-query.sql"
set "LOG_PATH=$logPath"
pushd "%PROJECT_ROOT%"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File "%AGENT_PATH%" -Once -LowThreshold $LowThreshold -StockQueryPath "%STOCK_QUERY_PATH%" -LogPath "%LOG_PATH%"
set "SYNC_EXIT_CODE=%ERRORLEVEL%"
popd
exit /b %SYNC_EXIT_CODE%
"@
Set-Content -LiteralPath $launcherPath -Value $launcherContent -Encoding ASCII

$result = & schtasks.exe /Create /TN $TaskName /SC MINUTE /MO $IntervalMinutes /TR $launcherPath /F 2>&1
if ($LASTEXITCODE -ne 0) {
  throw "Failed to register scheduled task. schtasks.exe output: $result"
}

Write-Host "Scheduled task registered: $TaskName"
Write-Host "It will run every $IntervalMinutes minute(s)."
Write-Host "Launcher file: $launcherPath"
Write-Host "Log file: $logPath"
