# M1 host setup helpers

Run these on the **Windows VPS as Administrator** after SQL Server and server files are installed.

| Script | Purpose |
| --- | --- |
| `01-firewall-m1.ps1` | Allow public ConnectServer + GameServer ports only |
| `02-verify-ports.ps1` | Run from an **external** PC to prove ports are reachable |
| `03-start-stack.ps1` | Start DataServer → JoinServer → ConnectServer → GameServer |
| `04-sql-odbc-setup.ps1` | Restore `MuOnline.bak` + 32-bit ODBC DSN (needs SQL Express first) |
| `05-probe-cs.ps1` | UDP `C1:F4:06` probe to ConnectServer `127.0.0.1:44405` |
| `LaunchMu.cs` | x86 injector — compile with Framework `csc.exe /platform:x86` |

Examples:

```powershell
.\01-firewall-m1.ps1
.\02-verify-ports.ps1 -PublicIp "YOUR.VPS.IP"
.\03-start-stack.ps1
.\05-probe-cs.ps1
```
