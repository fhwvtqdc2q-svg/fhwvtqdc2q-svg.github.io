param(
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

function Invoke-SupabaseLogin($Url, $ApiKey, $Email, $Password) {
  $endpoint = "$($Url.TrimEnd('/'))/auth/v1/token?grant_type=password"
  $headers = @{
    apikey = $ApiKey
    "Content-Type" = "application/json"
  }
  $body = @{
    email = $Email
    password = $Password
  } | ConvertTo-Json

  return Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -Body $body
}

if (-not (Test-Path -LiteralPath $ConfigPath)) {
  throw "Config file not found: $ConfigPath"
}

$configText = Get-Content -Raw -LiteralPath $ConfigPath
$supabaseUrl = Get-ConfigValue -Text $configText -Pattern 'url:\s*"([^"]+)"' -Name "Supabase URL"
$supabaseKey = Get-ConfigValue -Text $configText -Pattern 'publishableKey:\s*"([^"]+)"' -Name "Supabase publishable key"

$email = Read-Host "New Supabase sync user email"
$securePassword = Read-Host "New Supabase sync user password" -AsSecureString
$secureConfirmPassword = Read-Host "Confirm Supabase sync user password" -AsSecureString

$password = $null
$confirmPassword = $null

try {
  $password = Convert-SecureStringToPlainText $securePassword
  $confirmPassword = Convert-SecureStringToPlainText $secureConfirmPassword

  if ($password -ne $confirmPassword) {
    throw "The Supabase passwords do not match."
  }

  if ($password.Length -lt 8) {
    throw "Use a stronger Supabase password: at least 8 characters."
  }

  $signupEndpoint = "$($supabaseUrl.TrimEnd('/'))/auth/v1/signup"
  $headers = @{
    apikey = $supabaseKey
    "Content-Type" = "application/json"
  }
  $body = @{
    email = $email
    password = $password
    data = @{
      full_name = "TOBACCO Ameen Sync"
    }
  } | ConvertTo-Json -Depth 5

  try {
    [void](Invoke-RestMethod -Method Post -Uri $signupEndpoint -Headers $headers -Body $body)
    Write-Host "Signup request was accepted."
  } catch {
    Write-Host "Signup did not complete automatically: $($_.Exception.Message)"
    Write-Host "If the user already exists, this is OK. The next login test decides."
  }

  try {
    $session = Invoke-SupabaseLogin -Url $supabaseUrl -ApiKey $supabaseKey -Email $email -Password $password
    if (-not $session.access_token) {
      throw "Supabase did not return an access token."
    }

    Write-Host "Supabase sync user login works."
    Write-Host "Now run: .\tools\setup-ameen-sync-env.ps1"
  } catch {
    Write-Host "Supabase sync user was not able to log in yet."
    Write-Host "Confirm the email in Supabase Auth, or create this user manually from Supabase Dashboard > Authentication > Users."
    throw "Login test failed: $($_.Exception.Message)"
  }
} finally {
  Remove-Variable password -ErrorAction SilentlyContinue
  Remove-Variable confirmPassword -ErrorAction SilentlyContinue
}
