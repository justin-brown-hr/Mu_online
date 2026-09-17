# Mu Online Season 2 — PC server build

Client @luanbong93 · Contracted via Freelancer.com · Vietnamese-language client, all client-facing communication in Vietnamese

| Base contract | Milestones | Timeline | Optional custom | Target |
| --- | --- | --- | --- | --- |
| $3,300 | 4 | 6 weeks | $2,100 | Windows PC only |

## 01 Summary

Build and deliver a commercially operable Mu Online Season 2 private server for Windows PC, using the original Webzen client, with a web administration panel, player-facing web services and a payment/shop system.

Visual direction is fixed by the client: classic, minimal, sharp, not gaudy. Keep original Mu art assets, dark metal tone, restrained skill effects, uncluttered HUD. No bright custom art, no animated pop-ups or banners.

Reference servers supplied by the client: `muvietnamss2.com`, `muhanoi.id`, `vttt.cmplay.vn`. A gameplay recording of a server branded MU-ZEN was also supplied and is the source for the custom module specs in section 06.

### Server

- Season 2 emulator package — 32-bit Windows binaries, components: DataServer, JoinServer, ConnectServer, GameServer
- Startup order is fixed: DataServer → JoinServer → ConnectServer → GameServer
- SQL Server (Express acceptable), mixed-mode auth, TCP/IP enabled
- Databases: `MuOnline`, `Me_MuOnline`, plus ranking/log databases per package
- ODBC System DSNs must be created in the 32-bit manager at `C:\Windows\SysWOW64\odbcad32.exe`

### Ports

| Port | Component | Exposure |
| --- | --- | --- |
| `44405` | ConnectServer (TCP + UDP) | Public |
| `55901+` | GameServer channels | Public |
| `55960` | DataServer | Internal |
| `55970` | JoinServer | Internal |
| `1433` | SQL Server | Never public |

### Hosting

- Windows VPS provided and owned by the client — Windows Server 2019/2022, 4 GB RAM minimum, 2 vCPU, 60 GB SSD
- Region: Vietnam or Singapore. US hosting is unacceptable for the target player base.
- Development happens directly on this VPS to avoid a migration step and to let the client inspect progress himself
- Client rendering over RDP is poor — use a local Windows machine or VM for client testing and video capture

> **Keep local backups of every stage**
>
> The client holds administrator access to the VPS from day one. That is the correct arrangement, but it means no leverage if payment stalls. Snapshot each milestone locally as it completes.

### 3.1 Game core

- Season 2 class set: Dark Wizard, Dark Knight, Fairy Elf, Magic Gladiator, Dark Lord — including class change quests
- Full skill trees per class, damage formula applied uniformly across classes
- Item tables: normal, set, excellent options, wings, jewel upgrade paths
- Chaos Machine: item upgrade, jewel combination, wing crafting
- Drop tables configurable per map and per monster
- Monster spawns across all Season 2 maps — Lorencia, Noria, Devias, Dungeon, Atlans, Lost Tower, Tarkan, Icarus, Kalima, Stadium
- Boss spawns: Golden Dragons, White Wizard, Red Dragon, and map bosses
- NPCs: shops, warehouse, guild master, chaos goblin
- Party, guild, and real-time PK systems

### 3.2 Events (base)

- Blood Castle
- Devil Square
- Chaos Castle
- Golden Boss (Boss vàng)
- White Wizard (Phù thuỷ trắng)
- Red Dragon (Rồng đỏ)

All events run on server-side schedulers, with times and reward rates exposed in the web admin panel.

### 3.3 Quality-of-life features (included, no extra charge)

The client's position, which is correct: a pure vanilla Season 2 will not retain Vietnamese players. These are treated as standard, not custom.

- Character reset system — in-game and/or web
- Chat commands: `/buff`, `/reset`, `/addstr`, `/addagi`, `/addvit`, `/addene`, `/post`, `/pkclear`, `/move`
- `/buff` parameters configurable in admin: minimum level, cooldown, Zen or WcoinC cost, buff strength
- Auto pick-up
- Buff NPC (retained alongside the command)
- Extended warehouse
- WcoinC shop

### 3.4 Web admin panel

- Authenticated, role-based access
- Drop rate and experience rate configuration
- Boss spawn schedule and event schedule configuration
- Item and jewel upgrade success rates
- Account management: search, ban, unban, credit adjustment
- Revenue reporting
- Requirement: no code editing and no manual file editing for any routine operation

### 3.5 Player web services

- Account registration
- Rankings
- Character information lookup
- Top-up / shop front end

### 3.6 Commerce

- WcoinC purchase flow integrated with a Vietnamese payment provider
- Server-wide player trading and personal stores
- Transaction logging sufficient to investigate duplication claims

### 3.7 Security (baseline)

- Connection rate limiting and abnormal packet filtering in server code
- Speed-hack and basic client tamper detection
- DDoS mitigation via provider-level protection (Cloudflare for web/API, anti-DDoS VPS tiers) — no bespoke mitigation infrastructure

### 3.8 Handover

- Packaged server and client
- Full source
- Installation and deployment documentation sufficient for a clean rebuild

## 04 Out of scope

- Mobile (iOS/Android) and macOS. The original Webzen client has no source and cannot be ported. Cross-platform means a full Unity client rewrite — a separate project estimated at $20,000+ and 3–4 months. This was the cause of the earlier stalled engagement and must not be re-absorbed into this contract.
- Season 6.3. Different client, server files and database. If commissioned, it is a second server sharing only the web infrastructure; estimated +40–50% of the base build.
- All custom modules in section 06 — separately quoted and separately funded.
- Deep client interface reskinning beyond basic adjustment.
- Payment merchant registration — see section 07.

## 05 Milestones

Milestone structure was proposed by the client and accepted unchanged. Funds are held in escrow and released by the client on acceptance. Week numbering starts from VPS handover, not contract date.

### M1 — Server running, client connecting

**Window:** 1–2 days · **Fee:** $500

#### Deliverables

- Full server stack installed and running on the client's VPS
- Client patched to the server IP and connecting from an external network
- Account and character creation functional
- Screen recording delivered to the client

#### Acceptance criteria

- All four processes start cleanly in the required order
- Client reaches the server list and connects from outside the host network
- Account registers; character creates and enters Lorencia
- Movement and melee combat function without disconnection over several minutes
- Character persists across logout and login — this proves the DataServer is writing to the database and is the real test of this milestone
- Single unbroken recording covering the whole chain, dated and identifiable as built for this client

> **Do not exceed scope here**
>
> No web admin, items, events or interface work in M1, and none of it visible in the recording. Showing M2 work during M1 establishes that it was free.

### M2 — Game content and base events

**Window:** Weeks 1–3 · **Fee:** $1,300
#### Deliverables

- All five classes configured with skill trees and balanced stats
- Item, set, excellent option and wing tables
- Chaos Machine upgrade and combination paths
- Drop tables and monster spawns across all Season 2 maps
- Boss spawns on schedule
- Base events: Blood Castle, Devil Square, Chaos Castle, Golden Boss, White Wizard, Red Dragon
- Quality-of-life set from 3.3: reset, chat commands, auto pick-up, buff NPC, extended warehouse

#### Acceptance criteria

- Each of the five classes is playable from level 1 through the class change quest
- Chaos Machine produces correct results for jewel combination and wing crafting at configured rates
- Every base event triggers on schedule, can be entered, completed and pays out
- Reset executes, applies its rules and persists across relog
- All chat commands function with their configured restrictions
- Client plays the server directly and signs off on feel and balance

### M3 — Web admin, commerce, security

**Window:** Weeks 4–5 · **Fee:** $1,200

#### Deliverables

- Web admin panel per 3.4
- Player web services per 3.5
- WcoinC shop with payment provider integration
- Server-wide trading and personal stores
- Rankings
- Baseline anti-cheat and rate limiting
- Balance pass against client feedback from M2

#### Acceptance criteria

- Drop rates, event times and boss schedules are all changeable through the panel by a non-technical operator
- Account ban, unban and credit adjustment work from the panel
- A full top-up transaction completes end to end in the provider's sandbox and credits the account
- Trade between two accounts completes with correct logging and no item duplication under repeated attempts
- Connection rate limiting is demonstrable under a simulated flood
- Revenue report reconciles against test transactions

> **Payment integration is blocked on the client**
>
> Vietnamese gateways require a Vietnamese business entity. The merchant account must exist before this milestone starts, or M3 stalls at an unfinishable item. Confirm early.

### M4 — Stabilisation and handover

**Window:** Week 6 · **Fee:** $300

#### Deliverables

- Outstanding bug fixes from M2 and M3 testing
- Packaged server and packaged client
- Full source handover
- Installation and deployment documentation

#### Acceptance criteria

- A clean install on a fresh VPS succeeds by following the documentation alone, with no undocumented steps
- Client package installs and connects without manual patching by the end user
- Source delivered in full, including web admin and web services
- Known-issues list delivered alongside

| Milestone | Window | Fee |
| --- | --- | --- |
| M1 — Server running | 1–2 days | $500 |
| M2 — Game content | Weeks 1–3 | $1,300 |
| M3 — Admin & commerce | Weeks 4–5 | $1,200 |
| M4 — Handover | Week 6 | $300 |
| **Base contract** | | **$3,300** |

## 06 Custom modules — optional, separately funded

Agreed to be built after the base server is stable, incrementally. Quotes held for the client. Each becomes its own funded milestone.

> **All five modules require custom UI windows inside the original client**
>
> Resonance, option removal, the event board, the jewel bank and the F6 menu do not exist in stock Mu. These need client-side patching — typically a DLL hook or modified `main.exe` — not just server logic. Verify the chosen server package ships a client extension framework before any of these quotes are treated as firm. Without one, the plumbing must be built before any feature, and the estimates below are void.

| Module | Effort | Price |
| --- | --- | --- |
| Jewel bank + Jewel of Luck | 3 days | $250 |
| VIP (single tier, time-limited) | 2–3 days | $200 |
| Loạn Chiến PK event | 3 days | $300 |
| Đại chiến Lorencia event | 6 days | $550 |
| Upgrade NPC suite | 8–9 days | $800 |
| **Total · bundled price $1,900** | | **$2,100** |

### 6.1 Loạn Chiến PK — free-for-all arena

- Entry requirement: character level 200+
- Registration through the event board; automatic teleport into the arena
- Scoring by kill count
- Rewards — Top 1: 10,000 WcoinC + 5 Bless · Top 2: 7,000 + 3 Bless · Top 3: 5,000 + 1 Bless · Top 4–10: 3,000 WcoinC
- Schedule and rewards configurable in web admin

### 6.2 Đại chiến Lorencia — guild siege

- Dedicated map instance using Lorencia scenery; the live Lorencia map is unaffected
- Four entry gates for up to four guilds, one gate per faction
- Minimum two registered guilds for the event to run
- Destructible tower at the centre
- Damage on the tower attributed per guild
- Win condition: the guild that destroys the tower
- Timeout fallback: highest cumulative guild damage wins — ensures every run resolves
- Tower HP configurable in web admin for post-launch tuning
- Single reward tier, paid to the winning guild master

> **Highest-risk item in the custom set**
>
> Per-guild damage attribution on a destructible object, with members joining and dying throughout, is the part most likely to overrun. Re-estimate before committing if the framework offers no existing damage-tracking hooks.

### 6.3 Upgrade NPC suite

- Item resonance (cộng hưởng): main item + secondary item produce a result item; success rate and WcoinC cost displayed before execution
- Excellent option removal (huỷ dòng hoàn hảo): select a specific excellent option on an item and remove it; 100% success rate, 50,000 WcoinC per the reference
- Item upgrade, box opening, socket breaking: independent success and failure rates per function, all admin-configurable

### 6.4 Jewel bank and VIP

- Jewel bank: deposit and withdraw jewels as counts rather than inventory items; hotkey accessible
- Jewel of Luck with its own configurable rate
- VIP: single tier with expiry, experience and drop bonuses, on-screen badge; benefits and price admin-configurable
- Daily check-in and daily quests are explicitly excluded at the client's request

## 07 Client dependencies

Work is blocked without these. Track them as hard dependencies, not requests.

| Item | Blocks | Notes |
| --- | --- | --- |
| Windows VPS with RDP credentials | M1 onwards | Client-owned account. Timeline starts on handover, not contract date. |
| Payment merchant account | M3 | Vietnamese gateways require a Vietnamese entity. Client must register; we integrate only. |
| Reference material for UI features | M2, custom | Screenshots or recordings. Already supplied for the custom modules. |
| Milestone review and release | Each milestone | Funds move only on client release. |

## 08 Risks

| Risk | Sev | Mitigation |
| --- | --- | --- |
| Server package lacks a client extension framework, making all custom UI infeasible at quoted prices | HIGH | Verify before M1 completes. If absent, re-quote section 06 or choose a different base package now. |
| UI fidelity expectation — client wants the look of his reference servers | HIGH | Editing original client interface assets is slow specialist work and is the likeliest source of overrun. Agree explicitly what "similar" means before M2. |
| Payment merchant account not ready by M3 | MED | Raise now, not in week four. Build the shop against a sandbox so the rest of M3 can complete. |
| Server files and client version mismatch | MED | Source both from the same package. Symptom presents as a network fault and burns days. |
| Per-guild damage attribution overrun in 6.2 | MED | Re-estimate before starting. Flag to the client before work begins rather than after. |
| Client relationship — a prior attempt at this project stalled and went silent for over a week | HIGH | The communication cadence in section 10 is a contractual-grade commitment, not a nicety. A missed update costs more than a missed feature. |
| Legal exposure — commercial server on Webzen's client and assets | MED | Common in this market but takedown risk is real and the platform will not arbitrate in our favour on it. Business decision, taken knowingly. |

## 09 Open questions

- Which Season 2 server package are we standardising on, and does it ship a client extension framework?
- Reset system rules — level requirement, stat handling, cost, maximum resets, reward per reset
- Which Vietnamese payment provider, and is the merchant account already registered?
- Target concurrent player count for launch, which drives VPS sizing
- How closely must the interface match the reference servers — same layout and feel, or asset-level replication?
- HUD element set: the reference recording has a crowded top bar, which conflicts with the client's stated minimal direction. Resolve before M2.
- Post-handover support window — 30 days for bug fixes excluding new features has been proposed but not confirmed by the client

## 10 Working agreement

- Progress update to the client every 2–3 days with a screenshot or short recording, including on days with little to show
- Problems reported the same day they are found, with a revised date — silence is the specific failure mode that nearly lost this contract
- Client tests each milestone directly before release
- Where a requirement cannot be met as specified, propose an equivalent alternative rather than dropping it silently
- Custom work: quote and approval before any work starts, funded as its own milestone
- All payments through Freelancer milestones; nothing off-platform
- Adjusting existing Season 2 content — rates, drops, balance, event timings — is included and unlimited. Creating anything that does not exist in Season 2 is custom and quoted.

Scope, pricing and specifications in this document reflect what has been agreed with the client in writing. Changes require agreement from both sides and an update here.
