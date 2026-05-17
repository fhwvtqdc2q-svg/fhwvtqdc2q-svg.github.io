param(
  [string]$Server = "OZK-TOBACCO",
  [string]$Database = "AmnDb001",
  [string]$SqlUserName = "tobacco_sync_reader",
  [string]$ConfigPath = (Join-Path $PSScriptRoot "..\src\config.js")
)

$ErrorActionPreference = "Stop"

function Convert-SecureStringToPlainText($SecureValue) {
  $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureValue)
  try {
    return [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
  } finally {
    if ($bstr -ne [IntPtr]::Zero) {
      [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
  }
}

function Get-ConfigValue($Text, $Pattern, $Name) {
  $match = [regex]::Match($Text, $Pattern)
  if (-not $match.Success) {
    throw "Could not read $Name from $ConfigPath"
  }
  return $match.Groups[1].Value
}

function New-SqlConnectionString($Server, $Database, $UserName, $Password) {
  $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
  $builder["Data Source"] = $Server
  $builder["Initial Catalog"] = $Database
  $builder["User ID"] = $UserName
  $builder["Password"] = $Password
  $builder["TrustServerCertificate"] = $true
  return $builder.ConnectionString
}

function Set-UserAndProcessEnv($Name, $Value) {
  [Environment]::SetEnvironmentVariable($Name, $Value, "User")
  [Environment]::SetEnvironmentVariable($Name, $Value, "Process")
}

function Test-SqlLogin($ConnectionString) {
  $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
  try {
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 30
    $command.CommandText = "select count_big(*) from dbo.mt000;"
    [void]$command.ExecuteScalar()
  } finally {
    if ($connection.State -eq "Open") {
      $connection.Close()
    }
  }
}

function Test-SupabaseLogin($Url, $ApiKey, $Email, $Password) {
  $endpoint = "$($Url.TrimEnd('/'))/auth/v1/token?grant_type=password"
  $headers = @{
    apikey = $ApiKey
    "Content-Type" = "application/json"
  }
  $body = @{
    email = $Email
    password = $Password
  } | ConvertTo-Json

  try {
    $session = Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -Body $body
    if (-not $session.access_token -or -not $session.user.id) {
      throw "Supabase did not return a valid session."
    }
  } catch {
    throw "Supabase login failed. Create/confirm the sync user in Supabase Auth, or rerun this script with the correct email and password. Original error: $($_.Exception.Message)"
  }
}

Add-Type -AssemblyName System.Data

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Config file not found: $ConfigPath"
}

$configText = Get-Content -Raw -LiteralPath $ConfigPath
$supabaseUrl = Get-ConfigValue -Text $configText -Pattern 'url:\s*"([^"]+)"' -Name "Supabase URL"
$supabaseKey = Get-ConfigValue -Text $configText -Pattern 'publishableKey:\s*"([^"]+)"' -Name "Supabase publishable key"

$sqlSecurePassword = Read-Host "SQL password for $SqlUserName on $Server" -AsSecureString
$syncEmail = Read-Host "Supabase sync user email"
$supabaseSecurePassword = Read-Host "Supabase sync user password" -AsSecureString

$sqlPassword = $null
$supabasePassword = $null

try {
  $sqlPassword = Convert-SecureStringToPlainText $sqlSecurePassword
  $supabasePassword = Convert-SecureStringToPlainText $supabaseSecurePassword
  $connectionString = New-SqlConnectionString -Server $Server -Database $Database -UserName $SqlUserName -Password $sqlPassword

  Test-SqlLogin -ConnectionString $connectionString
  Test-SupabaseLogin -Url $supabaseUrl -ApiKey $supabaseKey -Email $syncEmail -Password $supabasePassword

  Set-UserAndProcessEnv -Name "AMEEN_SQL_CONNECTION_STRING" -Value $connectionString
  Set-UserAndProcessEnv -Name "TOBACCO_SUPABASE_URL" -Value $supabaseUrl.TrimEnd("/")
  Set-UserAndProcessEnv -Name "TOBACCO_SUPABASE_PUBLIC_KEY" -Value $supabaseKey
  Set-UserAndProcessEnv -Name "TOBACCO_SYNC_EMAIL" -Value $syncEmail
  Set-UserAndProcessEnv -Name "TOBACCO_SYNC_PASSWORD" -Value $supabasePassword

  Write-Host "Sync environment variables were saved for this Windows user."
  Write-Host "Run: .\tools\ameen-sync-agent.ps1 -Once -LowThreshold 50"
  Write-Host "Do not send or paste any password in chat."
} finally {
  Remove-Variable sqlPassword -ErrorAction SilentlyContinue
  Remove-Variable supabasePassword -ErrorAction SilentlyContinue
}
