# M1 session handoff — Milestone 1 complete on the VPS

**Updated:** 2026-09-20
**Workspace root:** `C:\work\Mu_online` (VPS `WIN-2G5KCBCCQ1R`, IP `103.56.164.158`)
**Package:** xMuPP Season 2 (`ptr0x-real/xMuPP`), client 1.02C+Season2 (Brazilian repack, English opcodes)
**Scope lock:** No web admin / events UI.

---

## Status

| Area | Status | Evidence (`m1/evidence/`) |
| --- | --- | --- |
| SQL / ODBC / DS / JS / CS / GS | **Done** | — |
| Client runs **on this VPS** (no GPU) | **Done** | `01-title-screen.png` |
| Server list → GameServer → login | **Done** | `02-login-screen.png` |
| Character create (`M1Tester`, DK) | **Done** | `03-character-created.png` |
| Lorencia | **Done** | `04-lorencia-in-game.png` |
| Combat (kills, EXP) | **Done** | `05-…budge-dragon.png`, `06-…spider.png` |
| Relog (switch character → re-enter) | **Done** — EXP/position persisted in DB | `07-…`, `08-…` |
| Recording | **Done** — 5m46s, 800x600, chat window hidden | `M1-full-run.mp4` (not in git, 140 MB) |

**A local PC is NOT required.**

---

## Root causes fixed

### Client (`play-safe\main.exe` would not start)

`main.exe` starts through two stubs bolted on by the repacker, before ASPack:

```
EP (.LibHook 0x0845C200):  LoadLibraryA("CLtDLL.dll")       ; SuZaNa
0x088569E9 (.as_0003):     LoadLibraryA("hack.dll")
                           or eax,eax / jz 0x00000000        ; fail = jump to NULL
                           GetProcAddress(h,"Inicio"); call eax
                           jmp 0x00782597                    ; ASPack / real start
```

1. `hack.dll` had been renamed `.off` → the stub jumped to NULL ("EIP=0"). **Keep `hack.dll`.**
2. SuZaNa skipped by repointing the PE entry point `0x0845C200 → 0x084569E9` (header offset `0x128`). Backup `main.exe.libhook-bak`.
3. MU 1.02c is **OpenGL**. dgVoodoo D3D/DDraw DLLs crashed Mesa → moved to `play-safe\_dgvoodoo-disabled\`. Mesa llvmpipe renders on the Basic Display Adapter.
4. `LaunchMu*.exe` injectors are not needed; `main.exe` loads `Main.dll` itself.

### Server (walking/combat silently ignored → no monsters)

`GameServer.vcxproj` defined **`GAMESERVER_LANGUAGE=0`** (Korean opcodes: walk `0xD3`,
attack `0xD7`), overriding `stdafx.h`'s `1`. This client uses English opcodes
(walk `0xD4`, attack `0x11`, position `0x15`, multi-skill `0xDB`), so every walk/attack
packet fell through the dispatch `switch` with no error. The server kept the player at
the spawn point, so monsters never entered the viewport. **Fixed: `GAMESERVER_LANGUAGE=1`**
in both configs. Rebuild with `m1\scripts\08-rebuild-gs.ps1` (GameServer.exe is gitignored).

---

## Known issues (not M1 blockers)

- **HP number is byte-swapped** in the HUD (e.g. `4355` = `0x1103` → real `0x0311` = 785).
  The xMuPP HP packet (`0x26`/`F3 03`) sends the value in the wrong byte order. Cosmetic.
- The chat window starts at full screen height, so its frame looks like two tall vertical
  lines across the view. **F4** cycles its size (hidden → small → medium → full). The size
  isn't saved, so press F4 after each world entry (usually once) before recording.
  `M1-full-run.mp4` was recorded in 3 segments with the chat hidden, then joined with ffmpeg.
- GameServer receives connections from internet scanners (seen `195.250.79.2`) — ports are public.
- **Test character was buffed for the combat test:** `M1Tester` Str 250 / Agi 120 / Vit 250
  (set in DB while offline). A fresh level-1 unarmed DK dies in seconds to a group of
  Budge Dragons.

---

## How to run

```powershell
C:\work\Mu_online\m1\scripts\03-start-stack.ps1           # if servers are down
C:\work\Mu_online\m1\scripts\06-start-client.ps1 -Restart
. C:\work\Mu_online\m1\scripts\MuUI.ps1; Enter-MuWorld     # scripted login -> Lorencia
C:\work\Mu_online\m1\scripts\07-record.ps1 -Start / -Stop  # ffmpeg (C:\tools\ffmpeg)
```

Manual: server group **"Ajuda em MuOnline"** → **"(Non-PVP) Conectar"** → `test` / `test123`
→ select `M1Tester` → Connect. In game, Esc → "Trocar de personagem" = relog.

Route to monsters (screen directions, 800x600): walk **lower-right** through town,
across the east bridge (~x 165–185), Spiders/Budge Dragons at x 180–226.
Screen-up ≈ −X, screen-down/right ≈ +X. Attack monsters once they are adjacent.

Helpers: `MuUI.ps1` (`Get-MuWindow`, `Click`, `TypeText`, `Key`, `Shot`, `Pin`,
`Enter-MuWorld`) — clicks use absolute `mouse_event` moves (DirectInput ignores
`SetCursorPos`). The window must be pinned on top or the editor steals focus.

Diagnostics:
- `play-safe\m1-main-dll.log` — Main.dll hex-dumps every `send`/`recv`.
- `m1\scripts\MuTrace.cs` — tiny Win32 debugger (`csc /platform:x86 MuTrace.cs`).
- C1 client packets are XOR'd (key `E7 6D 3A 89 …`, `GAMESERVER_UPDATE 200`).

## Accounts

- `test` / `test123` — character `M1Tester` (Dark Knight)
- CS `103.56.164.158:44405`, GS `55901`, JS `55970`, DS `55960`

## Next

M1 acceptance is complete. Do not start M2 web/admin until asked.
