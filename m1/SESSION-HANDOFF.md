# M1 session handoff — continue on VPS

**Saved:** 2026-09-16  
**Workspace root:** `D:\work` (repo) / project under `m1\`  
**Package:** xMuPP Season 2 (`ptr0x-real/xMuPP`)  
**Goal:** Milestone 1 — 4 servers up → client login → char in Lorencia → combat → logout/login persist → one acceptance recording.  
**Scope lock:** No web admin / events UI / custom modules.

---

## Paste this in a new Cursor Agent chat on the VPS

```
Continue Mu Online Season 2 Milestone 1 from m1/SESSION-HANDOFF.md.
Do not repeat dead loops (file IP patch + blind relaunch).
Current blocker: client never sends to ConnectServer even with live IP 127.0.0.1 after Main.dll inject.
Next: find real CS port / why connect never fires after successful EntryProc; then login test/test123 → Lorencia → combat → recording.
```

---

## Status

| Area | Status |
| --- | --- |
| SQL Express + MuOnline + 32-bit ODBC | Done (local). Re-do on VPS if fresh machine |
| DS → JS → CS → GS build & run | Done |
| Ports | CS `44405` TCP+UDP, GS `55901`, DS `55960`, JS `55970` |
| ConnectServer UDP F4:06 / F4:03 reply | **Done** — patched `SocketManagerUdp`; probe works |
| Release `Main.dll` + `LaunchMu` inject | **Done** — EntryProc runs, `main.emu` OK |
| Live memory after inject | IP `127.0.0.1`, ver `22548`, serial `k5lEopalwaudns8h` |
| Client → ConnectServer traffic | **BLOCKED** — no TCP/UDP from game to CS; disconnect OK dialog |
| Lorencia / combat / recording | Not started |

---

## Critical findings (do not re-learn the hard way)

1. **`play-safe\main.exe` is ASPack-packed.** Editing connect IP strings in the file does **not** fix live connect. Runtime patch via `Main.dll` after unpack is required.
2. **Debug `Main.dll` will not load** (depends on `VCRUNTIME140D`). Always build **Release|Win32** with toolset `v143`.
3. Stock `main.exe` does **not** import `Main.dll`. Use injector: `m1/scripts/LaunchMu.cs` → `LaunchMu.exe` beside client, or inject after main window appears.
4. ConnectServer stock only answered server-list on **TCP**. Season 2 clients use **UDP** F4. Patch is in:
   - `m1/host/Server/xMuPP-src/Source/Server Side/ConnectServer/SocketManagerUdp.cpp`
   - `m1/host/Server/xMuPP-src/Source/Server Side/ConnectServer/SocketManagerUdp.h`
5. Even with live IP correct + CS UDP working + inject OK, **game still never opens sockets to CS**. Remaining work is **why connect never fires** (wrong port in code, early disconnect with no retry, wrong connect path) — **not** another localhost IP file edit.
6. Port candidates seen in binary: `44405`, many `55557` hits. CS should stay on **44405** unless proven otherwise (55557 test: CS listened, still no client hit).

---

## Accounts / versions

- Login: `test` / `test123`
- Serial: `k5lEopalwaudns8h`
- Version: `1.02.03` → bytes `22548`
- `ServerList.dat`: GameServer `127.0.0.1:55901` SHOW
- On VPS for external client: change ServerList + MainInfo IP to VPS public IP

---

## Key paths

```
m1/SESSION-HANDOFF.md          ← this file
m1/VPS-MIGRATE.md              ← how to move files
m1/M1-CHECKLIST.md
m1/PACKAGE-DECISION.md
m1/scripts/03-start-stack.ps1
m1/scripts/LaunchMu.cs         ← client Main.dll injector source
m1/host/Server/xMuPP-src/Source/Server Side/ConnectServer/SocketManagerUdp.*
m1/host/Server/xMuPP-src/Source/Client Side/Main_v102c/Main.cpp   ← EntryProc + M1Log
m1/host/Server/xMuPP-src/Server Files/   ← running binaries + ini
m1/host/Client/play-safe/      ← test client (NOT in git — copy separately)
```

Client launch (after copying client to VPS):

1. Start stack: `m1/scripts/03-start-stack.ps1`
2. Build Release Main.dll → copy to `play-safe\Main.dll`
3. Compile `LaunchMu.cs` (x86) into `play-safe\LaunchMu.exe`
4. Run `LaunchMu.exe` (or start `main.exe`, wait for window, inject)
5. Check `play-safe\m1-main-dll.log` for `EntryProc done`
6. Watch ConnectServer `LOG\*.txt` for `SocketManagerUdp] ServerList`

---

## Next engineering steps (ordered)

1. On VPS: restore SQL + ODBC + start stack; confirm UDP F4 probe to `127.0.0.1:44405`.
2. Copy `host/Client/play-safe` (or full Client) outside git.
3. Prove whether client ever sends **any** packet (pktmon / Wireshark / CS log). If zero: find connect call / port in unpacked process, or try Tools main that matches Main_v102c offsets with a launcher that loads DLL earlier.
4. Unblock server list → login → create char → Lorencia → combat → relog → one recording.
5. Do not start M2 web/admin work.

---

## Cursor chat continuity

Local IDE chats **do not sync** to the VPS.

**Best for same conversation:** on this PC, after git push, use Cursor **Move to Cloud**, then open that agent from the VPS at https://cursor.com/agents  

**Reliable fallback:** new Agent chat on VPS + paste the prompt at the top of this file.
