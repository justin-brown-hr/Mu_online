# Milestone 1 — Server running, client connecting ($500)

**Host:** local Windows (`D:\work\m1\host\`)

## Play now (important)

1. Close any old MU / Error / Erro / "desconectado" windows
2. Keep the 4 MuEMU server windows open
3. Run only this client:

`D:\work\m1\host\Client\play-safe\main.exe`

4. You should see a normal **MU** window (not only an OK dialog)
5. Server list → login **test** / **test123** → create character

Do **not** use `play-fix` or `play-clean` alone (wrong pack / no protocol DLL).

## Status 2026-09-16 (handoff → VPS)

- [x] SQL + MuOnline + ODBC (local)
- [x] Server stack (DS→JS→CS→GS)
- [x] CS UDP server-list (`SocketManagerUdp`)
- [x] Release Main.dll + LaunchMu inject; live IP/serial OK
- [ ] Client actually sends to CS / server list (current blocker)
- [ ] Login `test`/`test123` → Lorencia → combat → relog recording

**Resume:** open `m1/SESSION-HANDOFF.md` or say *Continue M1 from SESSION-HANDOFF.md*
