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

$powershellPath = Join-Path $env:SystemRoot "System32\WindowsPowerShell\v1.0\powershell.exe"
$logPath = Join-Path (Split-Path -Parent $PSScriptRoot) "logs\ameen-sync.log"
$arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$agentPath`" -Once -LowThreshold $LowThreshold -LogPath `"$logPath`""

$action = New-ScheduledTaskAction -Execute $powershellPath -Argument $arguments
$trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1)
$trigger.Repetition.Interval = "PT${IntervalMinutes}M"
$trigger.Repetition.Duration = "P3650D"

$settings = New-ScheduledTaskSettingsSet `
  -MultipleInstances IgnoreNew `
  -StartWhenAvailable `
  -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

Register-ScheduledTask `
  -TaskName $TaskName `
  -Action $action `
  -Trigger $trigger `
  -Settings $settings `
  -Description "Uploads Al-Ameen stock summaries to Supabase for TOBACCO." `
  -Force | Out-Null

Write-Host "Scheduled task registered: $TaskName"
Write-Host "It will run every $IntervalMinutes minute(s)."
Write-Host "Log file: $logPath"
