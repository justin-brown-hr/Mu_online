# M1 session handoff — continue on VPS

**Saved:** 2026-09-18  
**Workspace root:** `C:\work\Mu_online` (this VPS: `WIN-2G5KCBCCQ1R`, public IP `103.56.164.158`)  
**Package:** xMuPP Season 2 (`ptr0x-real/xMuPP`)  
**Goal:** Milestone 1 — 4 servers up → client login → char in Lorencia → combat → logout/login persist → one acceptance recording.  
**Scope lock:** No web admin / events UI / custom modules.

---

## Paste this in a new Cursor Agent chat on the VPS

```
Continue Mu Online Season 2 Milestone 1 from m1/SESSION-HANDOFF.md.
Do not repeat dead loops (file IP patch + blind relaunch).
Stack is up on 103.56.164.158. Current blocker: SuZaNa CLtDLL Erro 100 (false-positive on ConsoleWindowClass / PowerShell) then AV when MessageBox is nop'd; without CLtDLL the loader shows fatal "Error Acesse: www.servidoresmuonline.com.br/".
Next: finish anti-CLtDLL path so main stays alive with a real window + sendto CS, OR run play-safe client on a GPU PC (no agent consoles) against 103.56.164.158:44405.
Login test/test123 → Lorencia → combat → recording.
```

---

## Status (2026-09-18 VPS)

| Area | Status |
| --- | --- |
| Git repo on VPS | Done (`C:\work\Mu_online`) |
| SQL Express + MuOnline + 32-bit ODBC | **Done** |
| VS / MSBuild / C++ toolset v143 | **Done** |
| Server EXEs (DS/JS/CS/GS) | **Done** — running; UDP F4 probe OK on public IP |
| Account `test`/`test123` | **Done** |
| `play-safe` client | **Done** at `m1/host/Client/play-safe/` |
| Release `Main.dll` + `LaunchMu` | **Done** — suspended inject + early hooks + winsock rewrite; staged beside `main.exe` |
| ConnectServer / MainInfo public IP | **103.56.164.158** |
| Client launch on this VPS | **Blocked** — see SuZaNa / license notes below |
| Client → ConnectServer `sendto` | Not yet observed |
| Lorencia / combat / recording | Not started |

---

## Critical findings (2026-09-18 — do not re-learn)

1. **`Erro 100` is NOT DirectX.** Dialog text: SuZaNa CTM — “Foi Encontrado um Programa Hacker…”. Source DLL: `play-safe\CLtDLL.dll` (export `affvoce`). It `FindWindow`s `ConsoleWindowClass` (our PowerShell/agent consoles) and scans processes.
2. **Renaming `CLtDLL.dll` away** avoids Erro 100 but the packed loader then shows fatal **`Error Acesse: www.servidoresmuonline.com.br/`** and exits on OK. Keep `CLtDLL.dll` present.
3. **`LaunchMu` now `CREATE_SUSPENDED` → inject `Main.dll` → resume** so hooks install before CLtDLL runs (`m1/scripts/LaunchMu.cs`).
4. **`Main.dll` early hooks** (MessageBox / FindWindow / Process32 / Module32 / ExitProcess): can nop Erro 100 MessageBox, but process then **AV `0xC0000005`** (~200ms) — ExitProcess nop often never logs (possible `RtlExitUserProcess` path; hook added, needs retest).
5. Without CLtDLL + MessageBox nop on license nag: process stays alive but **no game window** (returning from ExitProcess after noreturn call = zombie).
6. Still true: ASPack-packed `main.exe`; runtime IP via `Main.dll`; CS UDP F4 patched; do not file-patch packed IP strings.
7. VPS video = **Microsoft Basic Display**; dgVoodoo D3D8/9 present. GPU PC client → `103.56.164.158:44405` remains valid fallback for M1 UI.
8. Defender exclusion for play-safe folder required (user confirmed).

---

## Critical findings (older — still valid)

1. **`play-safe\main.exe` is ASPack-packed.** Editing connect IP strings in the file does **not** fix live connect. Runtime patch via `Main.dll` after unpack is required.
2. **Debug `Main.dll` will not load** (depends on `VCRUNTIME140D`). Always build **Release|Win32** with toolset **v143**.
3. Stock `main.exe` does **not** import `Main.dll`. Use injector: `m1/scripts/LaunchMu.cs` → `LaunchMu.exe` beside client.
4. ConnectServer stock only answered server-list on **TCP**. Season 2 clients use **UDP** F4. Patch is in:
   - `m1/host/Server/xMuPP-src/Source/Server Side/ConnectServer/SocketManagerUdp.cpp`
   - `m1/host/Server/xMuPP-src/Source/Server Side/ConnectServer/SocketManagerUdp.h`
5. Old session: live IP was `127.0.0.1` after inject, CS UDP probe worked, **game still never opened sockets to CS**. Do **not** another localhost IP file edit.
6. Port candidates: `44405`, many `55557` hits. CS stays on **44405** unless proven otherwise (55557 listen test: still no client hit).
7. **Likely real cause (not yet proven):** `LaunchMu` used to wait for the MU window **plus 2 seconds**. CS connect often fires at scene start, so inject was after the first (failed) connect, and the game already sat on the disconnect OK dialog. IP in memory looked correct *after* that, which is why CS logs stayed empty.
8. xMuPP 1.02c `EntryProc` patches IP at `0x7A16C2` and does **not** patch `IpAddressPort` (that SetWord is only in a commented S6-era block).
9. This VPS has **no** SQL, compiler, server binaries, or client. Old-session “stack is up” does not carry over.

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
C:\work\Mu_online\m1\SESSION-HANDOFF.md
C:\work\Mu_online\m1\VPS-MIGRATE.md
C:\work\Mu_online\m1\M1-CHECKLIST.md
C:\work\Mu_online\m1\scripts\03-start-stack.ps1
C:\work\Mu_online\m1\scripts\04-sql-odbc-setup.ps1
C:\work\Mu_online\m1\scripts\05-probe-cs.ps1
C:\work\Mu_online\m1\scripts\LaunchMu.cs
C:\work\Mu_online\m1\host\Server\xMuPP-src\Source\Server Side\ConnectServer\SocketManagerUdp.*
C:\work\Mu_online\m1\host\Server\xMuPP-src\Source\Client Side\Main_v102c\Main.cpp
C:\work\Mu_online\m1\host\Server\xMuPP-src\Server Files\
C:\work\Mu_online\m1\host\Client\play-safe\   ← NOT in git
```

---

## Next engineering steps (ordered)

1. Install **SQL Server Express** (instance `SQLEXPRESS`, TCP/IP on) + run `m1\scripts\04-sql-odbc-setup.ps1`.
2. Install **VS 2022 Build Tools** with C++ (`Microsoft.VisualStudio.Workload.VCTools`) + ATL, toolset v143.
3. Build Release Win32: ConnectServer, JoinServer, DataServer, GameServer (post-build copies into `Server Files`). Rebuild ConnectServer so UDP F4 patch is in the EXE.
4. Build Release Win32 `Main.dll` (`Main_v102c`, toolset v143). Compile `LaunchMu.cs` x86 with `C:\Windows\Microsoft.NET\Framework\v4.0.30319\csc.exe`.
5. Copy `play-safe` client onto this VPS (not in git). Put `Main.dll` + `LaunchMu.exe` beside `main.exe`.
6. Start stack: `m1\scripts\03-start-stack.ps1`. Probe UDP: `m1\scripts\05-probe-cs.ps1`.
7. Run `LaunchMu.exe`. Read `play-safe\m1-main-dll.log` for `sendto` / `connect` lines. That proves whether connect ever fires.
8. Login `test` / `test123` → create char → Lorencia → combat → relog → one recording.
9. Do not start M2 web/admin work.

---

## Cursor chat continuity

Local IDE chats **do not sync** to the VPS.

**Best for same conversation:** on this PC, after git push, use Cursor **Move to Cloud**, then open that agent from the VPS at https://cursor.com/agents  

**Reliable fallback:** new Agent chat on VPS + paste the prompt at the top of this file.
