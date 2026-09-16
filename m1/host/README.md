# Local Windows M1 layout

Build everything here first, then copy the same setup to the client VPS for the external-connect clip.

```
D:\work\m1\host\
  Server\      ← put Season 2 emulator files here (DataServer, JoinServer, ConnectServer, GameServer)
  Client\      ← put matching Season 2 client here (1.02c / package match)
  SQL\         ← put .bak / .sql scripts from the package here
  Recordings\  ← M1 acceptance videos
```

## What you must drop in now

1. **Server package zip** → extract into `D:\work\m1\host\Server\`
2. **Matching client zip** → extract into `D:\work\m1\host\Client\`
3. **SQL scripts / backups** from that same package → `D:\work\m1\host\SQL\`

Until those files are on disk, we cannot finish M1 (binaries are not in this repo).

## After SQL Express is installed

1. Enable **mixed mode** + set `sa` password (SQL Server Installation Center / Configuration Manager)
2. Enable **TCP/IP** for the instance → restart SQL service
3. Create 32-bit System DSNs via `C:\Windows\SysWOW64\odbcad32.exe`
4. Run `D:\work\m1\scripts\03-start-stack.ps1` (paths updated to match your package)

## Local connect IP

Use `127.0.0.1` in ConnectServer / client for same-PC testing.
