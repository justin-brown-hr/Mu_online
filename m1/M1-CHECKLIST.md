# Milestone 1 — Server running, client connecting ($500)

**Host:** VPS `C:\work\Mu_online` — public IP `103.56.164.158`
**Hard requirement:** Client must work **without a discrete GPU** — met: it runs on
this VPS (Microsoft Basic Display Adapter) with Mesa llvmpipe software OpenGL.

## Play

```powershell
C:\work\Mu_online\m1\scripts\06-start-client.ps1 -Restart
```

Server group "Ajuda em MuOnline" → "(Non-PVP) Conectar" → `test` / `test123`.
The same `play-safe` folder also works on any normal Windows PC.

## Status (2026-09-20) — complete

- [x] Stack + account + public CS (`103.56.164.158:44405`)
- [x] Client runs on the VPS (no GPU) — `evidence/01-title-screen.png`
- [x] Server list → GameServer → login — `evidence/02-login-screen.png`
- [x] Character created — `evidence/03-character-created.png`
- [x] Lorencia — `evidence/04-lorencia-in-game.png`
- [x] Combat — `evidence/05-combat-kill-budge-dragon.png`, `06-combat-kill-spider.png`
- [x] Relog — `evidence/07-relog-character-select.png`, `08-relog-back-in-lorencia.png`
- [x] Recording — `evidence/M1-full-run.mp4` (5m46s, chat window hidden; not in git)

Known cosmetic issue: HP number in the HUD is byte-swapped (server packet bug).

**Details:** `m1/SESSION-HANDOFF.md`
