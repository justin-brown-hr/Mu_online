param(
  [string]$Ip = "127.0.0.1",
  [int]$Port = 44405
)
$ErrorActionPreference = "Stop"
$udp = New-Object System.Net.Sockets.UdpClient
$udp.Client.ReceiveTimeout = 2000
try {
  $udp.Connect($Ip, $Port)
  $pkt = [byte[]](0xC1, 0x04, 0xF4, 0x06)
  [void]$udp.Send($pkt, $pkt.Length)
  Write-Host "Sent C1:F4:06 to ${Ip}:$Port"
  $ep = New-Object System.Net.IPEndPoint([Net.IPAddress]::Any, 0)
  $resp = $udp.Receive([ref]$ep)
  Write-Host ("Reply {0} bytes from {1}: {2}" -f $resp.Length, $ep, [BitConverter]::ToString($resp))
}
catch {
  Write-Host "No UDP reply: $($_.Exception.Message)"
  exit 1
}
finally {
  $udp.Close()
}
