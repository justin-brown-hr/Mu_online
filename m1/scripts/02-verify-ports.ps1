# Run from an EXTERNAL machine (not the VPS) to prove public reachability.

param(
    [Parameter(Mandatory = $true)]
    [string]$PublicIp,
    [int]$ConnectServerPort = 44405,
    [int[]]$GameServerPorts = @(55901)
)

$ErrorActionPreference = "Continue"

Write-Host "Testing ConnectServer TCP $PublicIp`:$ConnectServerPort"
$cs = Test-NetConnection -ComputerName $PublicIp -Port $ConnectServerPort -WarningAction SilentlyContinue
Write-Host ("  TcpTestSucceeded = {0}" -f $cs.TcpTestSucceeded)

foreach ($port in $GameServerPorts) {
    Write-Host "Testing GameServer TCP $PublicIp`:$port"
    $gs = Test-NetConnection -ComputerName $PublicIp -Port $port -WarningAction SilentlyContinue
    Write-Host ("  TcpTestSucceeded = {0}" -f $gs.TcpTestSucceeded)
}

Write-Host ""
Write-Host "If ConnectServer fails: check Windows Firewall + cloud security group + ConnectServer running."
Write-Host "UDP 44405 cannot be tested the same way; verify in-game server list after TCP passes."
