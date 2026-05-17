param(
  [switch]$Once,
  [int]$IntervalSeconds = 60,
  [int]$LowThreshold = 50,
  [string]$StockQueryPath = ".\tools\ameen-stock-query.sql"
)

$ErrorActionPreference = "Stop"

function Require-Env($Name) {
  $value = [Environment]::GetEnvironmentVariable($Name, "User")
  if (-not $value) {
    $value = [Environment]::GetEnvironmentVariable($Name, "Process")
  }
  if (-not $value) {
    throw "Missing environment variable: $Name"
  }
  return $value
}

function Normalize-ItemName($Value) {
  $text = ""
  if ($null -ne $Value) {
    $text = [string]$Value
  }
  $text = $text.Trim()
  $text = [regex]::Replace($text, '^\d{2,}\s*-\s*', "")
  $text = $text.Replace("أ", "ا").Replace("إ", "ا").Replace("آ", "ا").Replace("ى", "ي").Replace("ة", "ه")
  $text = [regex]::Replace($text, "[^\p{L}\p{N}]+", " ")
  $text = [regex]::Replace($text, "\s+", " ")
  return $text.Trim().ToLowerInvariant()
}

function To-Number($Value) {
  if ($null -eq $Value -or $Value -eq "") {
    return 0
  }
  $text = ([string]$Value).Replace(",", "").Trim()
  $number = 0.0
  if ([double]::TryParse($text, [ref]$number)) {
    return $number
  }
  return 0
}

function Get-SupabaseSession($Url, $ApiKey, $Email, $Password) {
  $endpoint = "$Url/auth/v1/token?grant_type=password"
  $headers = @{
    apikey = $ApiKey
    "Content-Type" = "application/json"
  }
  $body = @{
    email = $Email
    password = $Password
  } | ConvertTo-Json

  try {
    return Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -Body $body
  } catch {
    throw "Supabase login failed for TOBACCO_SYNC_EMAIL. Rerun tools\setup-ameen-sync-env.ps1 with a valid Supabase Auth user. Original error: $($_.Exception.Message)"
  }
}

function Invoke-SqlRows($ConnectionString, $Query) {
  Add-Type -AssemblyName System.Data
  $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
  $rows = New-Object System.Collections.Generic.List[object]

  try {
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 60
    $command.CommandText = $Query
    $reader = $command.ExecuteReader()

    while ($reader.Read()) {
      $row = [ordered]@{}
      for ($index = 0; $index -lt $reader.FieldCount; $index++) {
        $name = $reader.GetName($index)
        $row[$name] = if ($reader.IsDBNull($index)) { $null } else { $reader.GetValue($index) }
      }
      $rows.Add([PSCustomObject]$row)
    }
  } finally {
    if ($connection.State -eq "Open") {
      $connection.Close()
    }
  }

  return $rows
}

function Build-InventoryReport($Rows, $LowThreshold) {
  $items = @()

  foreach ($row in $Rows) {
    $name = [string]$row.item_name
    $key = Normalize-ItemName $name
    if (-not $key) {
      continue
    }

    $qty = To-Number $row.stock_qty
    $status = "active"
    if ($qty -le 0) {
      $status = "out"
    } elseif ($qty -le $LowThreshold) {
      $status = "low"
    }

    $items += [ordered]@{
      key = $key
      name = $name
      stockQty = [math]::Round($qty, 3)
      status = $status
      priceListed = $false
      lowThreshold = $LowThreshold
    }
  }

  if (-not $items.Count) {
    throw "Ameen stock query returned no items. Edit tools\\ameen-stock-query.sql after identifying the real Ameen tables."
  }

  $summary = [ordered]@{
    reportDate = (Get-Date).ToString("yyyy-MM-dd")
    source = "ameen_sql_agent"
    totalStockItems = $items.Count
    availableItems = @($items | Where-Object { $_.stockQty -gt 0 }).Count
    lowStockItems = @($items | Where-Object { $_.status -eq "low" }).Count
    outOfStockItems = @($items | Where-Object { $_.status -eq "out" }).Count
    staleItems = 0
    activeItems = @($items | Where-Object { $_.status -eq "active" }).Count
    threshold = $LowThreshold
    syncedAt = (Get-Date).ToUniversalTime().ToString("o")
  }

  return @{
    Summary = $summary
    Items = $items
  }
}

function Send-InventoryReport($SupabaseUrl, $ApiKey, $Session, $Report) {
  $endpoint = "$SupabaseUrl/rest/v1/inventory_reports"
  $headers = @{
    apikey = $ApiKey
    Authorization = "Bearer $($Session.access_token)"
    "Content-Type" = "application/json"
    Prefer = "return=minimal"
  }
  $body = @{
    report_date = $Report.Summary.reportDate
    source = "ameen_sql_agent"
    summary = $Report.Summary
    items = $Report.Items
    created_by = $Session.user.id
  } | ConvertTo-Json -Depth 20

  Invoke-RestMethod -Method Post -Uri $endpoint -Headers $headers -Body $body | Out-Null
}

function Sync-Once {
  $connectionString = Require-Env "AMEEN_SQL_CONNECTION_STRING"
  $supabaseUrl = (Require-Env "TOBACCO_SUPABASE_URL").TrimEnd("/")
  $supabaseKey = Require-Env "TOBACCO_SUPABASE_PUBLIC_KEY"
  $syncEmail = Require-Env "TOBACCO_SYNC_EMAIL"
  $syncPassword = Require-Env "TOBACCO_SYNC_PASSWORD"

  if (-not (Test-Path -LiteralPath $StockQueryPath)) {
    throw "Stock query file not found: $StockQueryPath"
  }

  $query = Get-Content -Raw -LiteralPath $StockQueryPath
  $rows = Invoke-SqlRows -ConnectionString $connectionString -Query $query
  $report = Build-InventoryReport -Rows $rows -LowThreshold $LowThreshold
  $session = Get-SupabaseSession -Url $supabaseUrl -ApiKey $supabaseKey -Email $syncEmail -Password $syncPassword
  Send-InventoryReport -SupabaseUrl $supabaseUrl -ApiKey $supabaseKey -Session $session -Report $report

  Write-Host ("Synced {0} items. Low={1}, Out={2}, At={3}" -f $report.Items.Count, $report.Summary.lowStockItems, $report.Summary.outOfStockItems, (Get-Date))
}

do {
  Sync-Once
  if ($Once) {
    break
  }
  Start-Sleep -Seconds $IntervalSeconds
} while ($true)
