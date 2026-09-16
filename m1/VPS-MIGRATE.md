# Move M1 to the VPS

## Cursor session (chat)

Local chats **do not** move with git.

| Method | Result |
| --- | --- |
| **Move to Cloud** (this PC, after push) | Same conversation at https://cursor.com/agents |
| **New chat** + `m1/SESSION-HANDOFF.md` | New agent with full context (rule `.cursor/rules/m1-session.mdc` also loads) |

On the VPS, paste:

```
Continue Mu Online Season 2 Milestone 1 from m1/SESSION-HANDOFF.md.
Do not repeat dead loops (file IP patch + blind relaunch).
Current blocker: client never sends to ConnectServer even with live IP 127.0.0.1 after Main.dll inject.
Next: find real CS port / why connect never fires after successful EntryProc; then login test/test123 → Lorencia → combat → recording.
```

## Git (code — you push)

Repo is **not** initialized yet on this PC. From `D:\work`:

```powershell
cd D:\work
git init -b main
git add -A
git status   # confirm host\Client is NOT listed (gitignored, ~2.5GB)
git commit -m "M1 handoff: xMuPP stack, CS UDP patch, Main.dll EntryProc, session docs"
git remote add origin <YOUR_GIT_URL>
git push -u origin main
```

`.gitignore` excludes `m1/host/Client/` and `m1/host/SQL/`. Copy the client separately.

## What must arrive on the VPS

**From git**

- `m1/SESSION-HANDOFF.md`, rules, scripts, Source, Server Files, Database `MuOnline.bak`, requirements doc

**Copy outside git (~2.5 GB)**

- `m1/host/Client/` (at least `play-safe`)

**On VPS after clone**

1. SQL Express + restore bak + 32-bit ODBC `MuOnline`
2. `.\m1\scripts\03-start-stack.ps1`
3. Rebuild Release `Main.dll` if exe not present; compile `LaunchMu.cs` x86
4. Continue from handoff blocker
