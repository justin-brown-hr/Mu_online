# Milestone 1 — Server running, client connecting ($500)

**Host:** VPS `C:\work\Mu_online` — public IP `103.56.164.158`

## Play now

**Do not expect a playable client on this VPS** (Basic Display + SuZaNa `CLtDLL` Erro 100 on PowerShell consoles).

Use a **GPU PC** client pointed at the VPS:

1. Keep the 4 MuEMU server windows open on the VPS (already running)
2. On the GPU PC, run Season 2 `play-safe` with `Main.dll` + `LaunchMu.exe` + `main.emu` IP `103.56.164.158` port `44405`
3. Login `test` / `test123` → Lorencia → combat → relog → one recording

VPS-only LaunchMu (for inject/log experiments):

`C:\work\Mu_online\m1\host\Client\play-safe\LaunchMu.exe`

## Status 2026-09-18

- [x] SQL + MuOnline + ODBC
- [x] VS 2022 Build Tools + MSBuild + cl.exe x86 (v143)
- [x] Server stack EXEs compiled + running (DS→JS→CS→GS)
- [x] CS UDP server-list works (public F4 probe OK)
- [x] Release `Main.dll` (suspended inject, early hooks, winsock rewrite) + `LaunchMu.exe`
- [x] Account `test` / `test123`
- [x] `play-safe` on VPS; Erro 100 root-caused (`CLtDLL.dll` / SuZaNa)
- [ ] **GPU PC client** → `103.56.164.158:44405` → login → Lorencia
- [ ] Combat → relog recording

**Ports:** CS `44405` TCP+UDP, GS `55901` TCP

**Resume:** `m1/SESSION-HANDOFF.md`
