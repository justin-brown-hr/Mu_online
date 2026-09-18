param([string]$ServerRoot = (Join-Path $PSScriptRoot "..\host\Server\xMuPP-src\Server Files"))
$ErrorActionPreference = "Stop"
$ordered = @(
  @{ Name = "DataServer";    RelPath = "DataServer\DataServer.exe" },
  @{ Name = "JoinServer";    RelPath = "JoinServer\JoinServer.exe" },
  @{ Name = "ConnectServer"; RelPath = "ConnectServer\ConnectServer.exe" },
  @{ Name = "GameServer";    RelPath = "GameServer\GameServer.exe" }
)
foreach ($item in $ordered) {
  $path = Join-Path $ServerRoot $item.RelPath
  if (-not (Test-Path $path)) { throw "Missing $($item.Name): $path" }
  Write-Host "Starting $($item.Name)..."
  Start-Process -FilePath $path -WorkingDirectory (Split-Path $path -Parent)
  Start-Sleep -Seconds 3
}
Write-Host "Stack launched. Ports: 44405, 55901, 55960, 55970"
