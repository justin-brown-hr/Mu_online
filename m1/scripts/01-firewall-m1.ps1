# Requires: Run as Administrator on the Windows VPS
# Opens only M1 public ports. Keeps SQL / DataServer / JoinServer closed to the internet.

param(
    [int[]]$GameServerPorts = @(55901),
    [int]$ConnectServerPort = 44405
)

$ErrorActionPreference = "Stop"

Write-Host "Creating Windows Firewall rules for Mu Season 2 M1..."

# Remove old rules with same names (idempotent)
$ruleNames = @(
    "MuS2-ConnectServer-TCP",
    "MuS2-ConnectServer-UDP",
    "MuS2-GameServer-TCP"
)
foreach ($name in $ruleNames) {
    Get-NetFirewallRule -DisplayName $name -ErrorAction SilentlyContinue | Remove-NetFirewallRule
}

New-NetFirewallRule -DisplayName "MuS2-ConnectServer-TCP" `
    -Direction Inbound -Action Allow -Protocol TCP -LocalPort $ConnectServerPort | Out-Null

New-NetFirewallRule -DisplayName "MuS2-ConnectServer-UDP" `
    -Direction Inbound -Action Allow -Protocol UDP -LocalPort $ConnectServerPort | Out-Null

New-NetFirewallRule -DisplayName "MuS2-GameServer-TCP" `
    -Direction Inbound -Action Allow -Protocol TCP -LocalPort $GameServerPorts | Out-Null

Write-Host "Allowed inbound:"
Write-Host "  TCP/UDP $ConnectServerPort (ConnectServer)"
Write-Host "  TCP $($GameServerPorts -join ', ') (GameServer channels)"
Write-Host ""
Write-Host "Do NOT open publicly: 1433 (SQL), 55960 (DataServer), 55970 (JoinServer)"
Write-Host "Also mirror these rules in the VPS provider security group / firewall."
