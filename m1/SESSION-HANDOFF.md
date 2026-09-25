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
| Character create / select (`M1Tester`, DK) | **Done** | `03-character-select.png` |
| Lorencia | **Done** | `04-lorencia-in-game.png` |
| Combat (kills, EXP) | **Done** | `05-…budge-dragon.png`, `06-…spider.png` |
| Relog (switch character → re-enter) | **Done** — EXP/level persisted (Dark Knight 2) | `07-…`, `08-…` |
| Item drop / pickup | **Done** — "Vine Gloves Obtido" | `06-…` |
| Recording | **Done** — 6m28s, **1024x768**, chat hidden | `M1-full-run.mp4` (not in git, 223 MB) |

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

## Display / recording quality

- Client resolution lives in the registry: `HKCU\Software\Webzen\Mu\Config` →
  `Resolution` (0 = 640x480, 1 = 800x600, **2 = 1024x768**), `WindowMode` 1 = windowed.
  Set to 2. At 1024x768 llvmpipe uses ~2 of the 6 vCPUs, so there is headroom.
- UI hit-boxes move with resolution: centred dialogs keep a fixed offset from the screen
  centre, bottom bars stay anchored to the bottom. 1024x768 coordinates used by
  `Enter-MuWorld`: server group (330,298), sub-server (505,299), account field (532,465),
  character slot (195,540), Connect (915,684), menu "Trocar de personagem" (512,207).
- `07-record.ps1` records at 30 fps / CRF 18 (near-lossless). The first recording used
  15 fps / CRF 26 and looked soft. Most of the "old" look is the game itself, though:
  MU S2 is a 2003 client with no anti-aliasing.
- Screen capture needs a **rendering** desktop. If the operator's RDP window is minimised
  the session stops drawing and gdigrab fails with `error 5`; the script now checks and
  reports this instead of writing an empty file.

## Client reference video (supplied 2026-09-21) — analysis

The customer sent a gameplay video of a Vietnamese server as the visual target
(`client-reference.mp4`, 1280x1032, 1m29s). Frame-by-frame comparison:

- **Same interface generation as ours.** Its inventory/equipment window and bottom HUD
  are the stock MU ones — identical frame art, 8x8 grid, `Zen` row, Q/W/E skill slots,
  coordinate box, red/blue orbs and the purple AG bar. It is *not* a reskinned UI.
- **Its resolution is 1280x1024** (video is 1280x1032 incl. border). Our client supports
  the same: registry `Resolution` = 3 → verified 1280x1024 renders; 4 → 1600x1200
  (clamped to 1600x1071 by the 1080p desktop). So resolution is a settings match, free.
- **Differences that are content, not interface:** level-100+ characters, 2nd-level wings,
  excellent items, player shops (`[Cua hang]` name tags), event kill counters
  (`da giet ... [25/50]`), pet indicator, 41M Zen. That is M2 territory.
- **Genuine client-side additions:** a **minimap** (top-right) and Vietnamese in-game text.
  Our client is a Brazilian repack, so its text is Portuguese.
- **Recording the demo:** `m1\scripts\10-demo-run.ps1` does the whole run in one pass
  (login → field → combat → relog), records it in three segments with the chat hidden
  between world entries, and joins them into `evidence\M1-full-run.mp4`.
- **Two input/login gotchas that broke automation for hours:**
  1. MU draws its own cursor from DirectInput *relative* deltas, which drift 20-30px
     from the real pointer, so server-list rows silently swallow clicks. `[MuUI]::ClickSync`
     parks the pointer at the screen corner first (clamping both cursors) and then moves -
     use it for every menu/UI click. Plain `Click` is fine for walking.
  2. Killing the client leaves JoinServer thinking the account is online, and the next
     login gets "Você foi desconectado do servidor" - the recording then captures four
     minutes of title screen. `Wait-MuAccountFree` now clears `MEMB_STAT.ConnectStat`
     after waiting, and `Test-MuDisconnectDialog` fails the run instead of recording junk.
- **Green Lorencia** (customer asked for green scenery): `m1\scripts\09-green-terrain.ps1`.
  Sampling the reference video's field gives grass at about **R=45 G=43 B=15** on screen —
  a dark olive-green — while this client's dry Lorencia renders about R=123 G=105 B=66.
  Measured render ≈ 0.77 x texture value, so the script recolours Lorencia's *own*
  `TileGrass01/02.OZJ` + `Object1\grass_01.OZT` to tint `0.55/0.62/0.22` with a 1.25
  contrast boost (keeps the grass-blade detail) and a 1.45 brighter tint for the tufts.
  Originals are backed up; `-Restore` reverts. Tints are parameters, so it is tunable.
- **Grass blades:** Lorencia's billboard grass (`World1\TileGrass01.OZT`) is pale straw
  spikes - that is what read as "dry stubble". Noria's (`World4`) is lush green blades at
  the same 256x64 size, and is the same grass seen on the character-select screen, so the
  script copies it in. Blade **height** is fixed by the client's billboard: a 256x128
  texture just gets stretched into giant streaks (tested), so `-Density` (default 3)
  overlays shifted copies of the texture instead, which is what makes the field look full.
  `-HideBlades` gives bare smooth ground; `-TallBlades` is the stretched experiment.
  Making the blades genuinely taller/denser per tile would mean editing Lorencia's object
  list - `EncTerrain1.obj` is encrypted, but the plain `Terrain.obj` decodes as
  1 version byte + `short count` (2835) + 30 bytes per object
  (short type, float x/y/z, float rot x/y/z, float scale).
- `play-safe\Customs.ini` (`Camera`, `MiniMap`, `Fog`) belongs to the **repack's original**
  `Main.dll` (`Main.dll.stock-bak`). We run xMuPP's `Main.dll` for the S2 protocol, which
  does not implement them — setting `MiniMap = 1` does nothing (tested). A minimap would
  have to be built into xMuPP's client DLL = custom client work, i.e. section 06 style.

## Known issues (not M1 blockers)

- **HP number in the HUD is sometimes byte-swapped** (e.g. `4099` = `0x1003` → real
  `0x0310` = 784; correct values such as `776 787` also appear). The xMuPP HP packet
  (`0x26`/`F3 03`) sends the value in the wrong byte order on some updates. Cosmetic;
  the bars and the real HP are fine.
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

Route to monsters (screen directions): walk **lower-right** through town,
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
