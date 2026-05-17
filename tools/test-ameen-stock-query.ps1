param(
  [string]$Server = "OZK-TOBACCO",
  [string]$Database = "AmnDb001",
  [string]$UserName = "sa",
  [string]$QueryPath = ".\tools\ameen-stock-query.sql",
  [int]$LowThreshold = 50,
  [int]$SampleSize = 10,
  [switch]$ShowSample,
  [string]$ConnectionString = $env:AMEEN_SQL_CONNECTION_STRING
)

$ErrorActionPreference = "Stop"

function Resolve-StockQueryPath($Path) {
  if (Test-Path -LiteralPath $Path) {
    return (Resolve-Path -LiteralPath $Path).Path
  }

  $fallbackPath = Join-Path -Path $PSScriptRoot -ChildPath "ameen-stock-query.sql"
  if (Test-Path -LiteralPath $fallbackPath) {
    return (Resolve-Path -LiteralPath $fallbackPath).Path
  }

  throw "Stock query file not found: $Path"
}

function New-SqlConnectionString($Server, $Database, $UserName, $Password) {
  $builder = New-Object System.Data.SqlClient.SqlConnectionStringBuilder
  $builder["Data Source"] = $Server
  $builder["Initial Catalog"] = $Database
  $builder["User ID"] = $UserName
  $builder["Password"] = $Password
  $builder["TrustServerCertificate"] = $true
  $builder["Connect Timeout"] = 10
  return $builder.ConnectionString
}

function Invoke-SqlDataTable($ConnectionString, $Query) {
  $connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
  try {
    $connection.Open()
    $command = $connection.CreateCommand()
    $command.CommandTimeout = 60
    $command.CommandText = $Query
    $adapter = New-Object System.Data.SqlClient.SqlDataAdapter $command
    $table = New-Object System.Data.DataTable
    [void]$adapter.Fill($table)
    return ,$table
  } finally {
    if ($connection.State -eq "Open") {
      $connection.Close()
    }
  }
}

function Get-Number($Value) {
  if ($null -eq $Value -or $Value -is [DBNull]) {
    return 0.0
  }

  $number = 0.0
  $text = ([string]$Value).Replace(",", "").Trim()
  if ([double]::TryParse($text, [ref]$number)) {
    return $number
  }

  return 0.0
}

function Show-UsefulColumns($ConnectionString) {
  $columnQuery = @"
select
  t.name as table_name,
  c.name as column_name,
  ty.name as type_name
from sys.tables t
join sys.columns c on c.object_id = t.object_id
join sys.types ty on ty.user_type_id = c.user_type_id
where t.name in ('mt000', 'ms000', 'st000', 'bi000', 'bu000')
order by t.name, c.column_id;
"@

  try {
    $columns = Invoke-SqlDataTable -ConnectionString $ConnectionString -Query $columnQuery
    if ($columns.Rows.Count -gt 0) {
      Write-Host ""
      Write-Host "Useful columns for fixing the query:"
      $columns | Select-Object table_name, column_name, type_name | Format-Table -AutoSize
    }
  } catch {
    Write-Host "Could not read fallback schema columns: $($_.Exception.Message)"
  }
}

Add-Type -AssemblyName System.Data

$queryFile = Resolve-StockQueryPath $QueryPath
$query = Get-Content -Raw -LiteralPath $queryFile
$securePassword = $null
$bstr = [IntPtr]::Zero
$password = $null

try {
  if (-not $ConnectionString) {
    $securePassword = Read-Host "SQL password for $UserName on $Server" -AsSecureString
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($securePassword)
    $password = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $ConnectionString = New-SqlConnectionString -Server $Server -Database $Database -UserName $UserName -Password $password
  }

  Write-Host "Testing Ameen stock query..."
  Write-Host "Query file: $queryFile"

  try {
    $table = Invoke-SqlDataTable -ConnectionString $ConnectionString -Query $query
  } catch {
    Write-Host "Stock query failed: $($_.Exception.Message)"
    Show-UsefulColumns -ConnectionString $ConnectionString
    throw
  }

  if (-not $table.Columns.Contains("item_name") -or -not $table.Columns.Contains("stock_qty")) {
    throw "The query must return item_name and stock_qty columns."
  }

  $totalRows = $table.Rows.Count
  $blankNames = 0
  $availableItems = 0
  $lowItems = 0
  $outItems = 0
  $negativeItems = 0

  foreach ($row in $table.Rows) {
    $name = ([string]$row["item_name"]).Trim()
    $qty = Get-Number $row["stock_qty"]

    if (-not $name) {
      $blankNames++
    }

    if ($qty -gt 0) {
      $availableItems++
      if ($qty -le $LowThreshold) {
        $lowItems++
      }
    } elseif ($qty -lt 0) {
      $negativeItems++
      $outItems++
    } else {
      $outItems++
    }
  }

  [PSCustomObject]@{
    RowsReturned = $totalRows
    AvailableItems = $availableItems
    LowItems = $lowItems
    OutOrZeroItems = $outItems
    NegativeItems = $negativeItems
    BlankNames = $blankNames
    LowThreshold = $LowThreshold
  } | Format-List

  if ($ShowSample) {
    Write-Host "Sample rows:"
    $table |
      Select-Object -First $SampleSize item_name, stock_qty |
      Format-Table -AutoSize
  } else {
    Write-Host "Sample rows hidden. Add -ShowSample if you want to inspect item names locally."
  }
} finally {
  if ($bstr -ne [IntPtr]::Zero) {
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
  }
  Remove-Variable password -ErrorAction SilentlyContinue
}
