# M1 host setup helpers

Run these on the **Windows VPS as Administrator** after SQL Server and server files are installed.

| Script | Purpose |
| --- | --- |
| `01-firewall-m1.ps1` | Allow public ConnectServer + GameServer ports only |
| `02-verify-ports.ps1` | Run from an **external** PC to prove ports are reachable |
| `03-start-stack.ps1` | Start DataServer → JoinServer → ConnectServer → GameServer |

Examples:

```powershell
.\01-firewall-m1.ps1
.\02-verify-ports.ps1 -PublicIp "YOUR.VPS.IP"
.\03-start-stack.ps1 -ServerRoot "C:\MuS2\Server"
```

Update exe paths inside `03-start-stack.ps1` once the Season 2 package folder layout is known.
