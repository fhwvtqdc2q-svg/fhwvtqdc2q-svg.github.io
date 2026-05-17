param(
  [string]$ConnectionString = $env:AMEEN_SQL_CONNECTION_STRING
)

$ErrorActionPreference = "Stop"

if (-not $ConnectionString) {
  $ConnectionString = "Server=localhost;Integrated Security=True;TrustServerCertificate=True;Connection Timeout=5;"
}

Add-Type -AssemblyName System.Data

$connection = New-Object System.Data.SqlClient.SqlConnection $ConnectionString
try {
  $connection.Open()
  $command = $connection.CreateCommand()
  $command.CommandText = @"
select
  name,
  state_desc,
  create_date
from sys.databases
where database_id > 4
order by name;
"@
  $reader = $command.ExecuteReader()
  while ($reader.Read()) {
    [PSCustomObject]@{
      Name = $reader.GetString(0)
      State = $reader.GetString(1)
      Created = $reader.GetDateTime(2)
    }
  }
} finally {
  if ($connection.State -eq "Open") {
    $connection.Close()
  }
}
