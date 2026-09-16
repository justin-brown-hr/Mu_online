# Milestone 1 — package decision

## Chosen package: **xMuPP (Season 2)**

| Field | Value |
| --- | --- |
| Package | [ptr0x-real/xMuPP](https://github.com/ptr0x-real/xMuPP) |
| Protocol / client | Season 2 · Main `1.02c` |
| Why | Matches contract stack (DataServer / JoinServer / ConnectServer / GameServer), ports `44405` / `55901` / `55960` / `55970`, ODBC `MuOnline`, **full source** for later custom UI (section 06) |
| Local path | `D:\work\m1\host\Server\xMuPP-src\` |
| Database | `Database Files\MuOnline.bak` |
| Has client extension path? | Yes — client-side source under `Source\Client Side` |

## Gaps to close for M1

- `GameServer.exe` and `DataServer.exe` are **not** in the repo (must compile from `Source\Server Side`)
- Client folder only has `Main.exe` — still need full client `Data\` assets (download separate 1.02c client pack, then replace/use xMuPP `Main.exe`)
- ConnectServer `ServerList.dat` currently points at `192.168.0.33` → change to `127.0.0.1` for local test

## Rejected for M1 baseline

- Random Namech/MMT forum repacks alone: good binaries, weak source for custom modules later
- Strategy: **xMuPP as canonical base**; if compile blocks M1 timeline, overlay a known-good S2 binary set only as temporary bridge
