# Requires Administrator
# Enables SQL Express protocols, restarts service, restores MuOnline, creates 32-bit ODBC DSN

$ErrorActionPreference = 'Stop'
$InstanceKey = 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\MSSQL17.SQLEXPRESS\MSSQLServer\SuperSocketNetLib'
$Bak = 'D:\work\m1\host\Server\xMuPP-src\Database Files\MuOnline.bak'
$DataDir = 'D:\work\m1\host\SQL\data'

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

Write-Host 'Restoring MuOnline database...'
sqlcmd -S '.\SQLEXPRESS' -E -l 60 -Q @"
IF DB_ID('MuOnline') IS NOT NULL BEGIN
  ALTER DATABASE MuOnline SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
  DROP DATABASE MuOnline;
END
RESTORE DATABASE MuOnline
FROM DISK = N'$Bak'
WITH MOVE 'MuOnline' TO N'$mdf',
     MOVE 'MuOnline_log' TO N'$ldf',
     REPLACE;
"@ | Out-Host

# If first restore fails due to logical names, try alternate common names
if ($LASTEXITCODE -ne 0) {
    Write-Host 'Retry restore with alternate logical names...'
    sqlcmd -S '.\SQLEXPRESS' -E -l 60 -Q @"
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
}

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
