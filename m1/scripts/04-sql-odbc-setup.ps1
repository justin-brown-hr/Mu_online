# Requires Administrator
# Enables SQL Express protocols, restarts service, restores MuOnline, creates 32-bit ODBC DSN

$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$Bak = Join-Path $RepoRoot 'host\Server\xMuPP-src\Database Files\MuOnline.bak'
$DataDir = Join-Path $RepoRoot 'host\SQL\data'

$InstanceKey = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' -ErrorAction SilentlyContinue |
  Where-Object { $_.PSChildName -like 'MSSQL*.SQLEXPRESS' } |
  ForEach-Object { Join-Path $_.PSPath 'MSSQLServer\SuperSocketNetLib' } |
  Where-Object { Test-Path $_ } |
  Select-Object -First 1
if (-not $InstanceKey) {
  throw 'SQL Express registry key not found. Install SQL Server Express first (instance SQLEXPRESS).'
}

Write-Host "Using instance key: $InstanceKey"
Write-Host "Bak: $Bak"
Write-Host 'Enabling Shared Memory, Named Pipes, TCP/IP...'
Set-ItemProperty "$InstanceKey\Sm" -Name Enabled -Value 1
Set-ItemProperty "$InstanceKey\Np" -Name Enabled -Value 1
Set-ItemProperty "$InstanceKey\Tcp" -Name Enabled -Value 1

# Dynamic ports for Express is fine; ensure IPAll has TcpDynamicPorts
$ipAll = "$InstanceKey\Tcp\IPAll"
if (Test-Path $ipAll) {
    $dyn = (Get-ItemProperty $ipAll).TcpDynamicPorts
    if ([string]::IsNullOrWhiteSpace($dyn) -and [string]::IsNullOrWhiteSpace((Get-ItemProperty $ipAll).TcpPort)) {
        Set-ItemProperty $ipAll -Name TcpDynamicPorts -Value '0'
    }
}

Write-Host 'Restarting MSSQL$SQLEXPRESS...'
Restart-Service 'MSSQL$SQLEXPRESS' -Force
Start-Sleep -Seconds 8

$env:Path = [System.Environment]::GetEnvironmentVariable('Path','Machine') + ';' + [System.Environment]::GetEnvironmentVariable('Path','User')

Write-Host 'Testing connection...'
sqlcmd -S '.\SQLEXPRESS' -E -l 20 -Q "SELECT @@SERVERNAME AS ServerName, @@VERSION AS Ver" | Out-Host

New-Item -ItemType Directory -Force -Path $DataDir | Out-Null

Write-Host 'Inspecting backup logical names...'
sqlcmd -S '.\SQLEXPRESS' -E -l 20 -Q "RESTORE FILELISTONLY FROM DISK = N'$Bak'" -W -s "`t" | Out-Host

# Common logical names for Mu packs: MuOnline_Data / MuOnline_Log or MuOnline.mdf style
# Detect via FILELISTONLY parse
$filelist = sqlcmd -S '.\SQLEXPRESS' -E -l 20 -h -1 -W -Q "SET NOCOUNT ON; RESTORE FILELISTONLY FROM DISK = N'$Bak'"
# Fallback MOVE using typical names after FILELISTONLY printed — try standard MuOnline names
$mdf = Join-Path $DataDir 'MuOnline.mdf'
$ldf = Join-Path $DataDir 'MuOnline_log.ldf'

Write-Host 'Restoring MuOnline database (logical names MuOnline_Data / MuOnline_Log)...'
sqlcmd -S '.\SQLEXPRESS' -E -l 60 -b -Q @"
IF DB_ID('MuOnline') IS NOT NULL BEGIN
  ALTER DATABASE MuOnline SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE MuOnline;
END
RESTORE DATABASE MuOnline
FROM DISK = N'$Bak'
WITH MOVE 'MuOnline_Data' TO N'$mdf',
     MOVE 'MuOnline_Log' TO N'$ldf',
     REPLACE;
"@ | Out-Host
if ($LASTEXITCODE -ne 0) { throw "MuOnline restore failed with exit $LASTEXITCODE" }

Write-Host 'Creating 32-bit System DSN MuOnline -> .\SQLEXPRESS ...'
# Remove existing then add
Get-OdbcDsn -Name 'MuOnline' -DsnType System -Platform '32-bit' -ErrorAction SilentlyContinue | Remove-OdbcDsn -Confirm:$false -ErrorAction SilentlyContinue
Add-OdbcDsn -Name 'MuOnline' -DriverName 'SQL Server' -DsnType System -Platform '32-bit' -SetPropertyValue @(
    'Server=.\SQLEXPRESS',
    'Database=MuOnline',
    'Trusted_Connection=Yes',
    'Description=MuOnline xMuPP'
)

Write-Host 'Done.'
sqlcmd -S '.\SQLEXPRESS' -E -l 20 -Q "SELECT name, state_desc FROM sys.databases WHERE name = 'MuOnline'" | Out-Host
Get-OdbcDsn -Name 'MuOnline' -DsnType System -Platform '32-bit' | Format-List
