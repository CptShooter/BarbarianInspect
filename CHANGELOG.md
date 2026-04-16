# Changelog

All notable changes to this project. Dates in YYYY-MM-DD.

## [1.0.2] — 2026-04-16

### Added
- **Progress counter** (`Loaded: X/Y`) in the bottom-right of the window, next to the Refresh button. Updates in real time as inspects complete.
- **Chat status** — prints `Refreshing N player(s)...` when a batch begins and `Refresh complete.` once the last stub resolves. Per-row refresh stays quiet.
- **Per-row refresh button** — refresh arrow icon right of the magnifying glass. Click re-queues inspect for that one player (or immediately re-collects own gear for self).

### Changed
- **Faster inspect queue** — throttle 0.3s → 0.2s, external-inspect backoff 2s → 0.5s. Real-world 25-man raid loads in ~12-17s instead of ~40s.
- **Piggyback on other addons' inspects** — if MRT / RaiderIO / anyone fires `NotifyInspect` and we have the target as a stub, we grab the data from `INSPECT_READY` too. In a raid with multiple inspect-using addons the effective rate roughly doubles.
- **`QueueInspect` returns a bool** so `RefreshAll` counts only newly added entries. Prevents the duplicated `Refreshing N players...` spam that was printed every `GROUP_ROSTER_UPDATE`.
- **`ProcessInspectQueue` no longer drops units on `CanInspect == false`** — it retries each tick until the target enters range. Previously a raid full of out-of-range players drained the queue on the first tick and never recovered.

### Fixed
- **Ziemniak / Report no longer flags stub players.** `CollectIssues` now returns `nil` for stubs, so not-yet-inspected players aren't reported as `crafts 0/2` (which happened because the default threshold is 2 and stub data has zero items). Whisper and report only target players whose gear has actually been scanned.

## [1.0.1] — 2026-04-16

Release infrastructure, no code changes.

### Added
- `.pkgmeta` for CurseForge automatic packaging.
- GitHub Actions workflow (`.github/workflows/release.yml`) using BigWigsMods/packager — tagged releases auto-build and upload to CurseForge.
- TOC now uses `@project-version@` (substituted by packager from the git tag) and declares `X-Curse-Project-ID: 1515379` so CurseForge App detects updates.

## [1.0.0] — 2026-04-16

First public release.

### Added
- **Core raid inspect window** — one row per party/raid member (self included), class-colored, with class icon, spec icon, name + realm, average item level, and 16 gear slot icons with item-level coloured by rarity.
- **Missing-enchant / missing-gem detection** with red border overlay on the item icon.
- **Enchant quality badges** (silver / gold pentagon) — atlas extracted from the item's tooltip "Enchanted:" line via `C_TooltipInfo.GetInventoryItem`.
- **Crafted badge** — hammer texture overlay, triggered by `ITEM_CREATED_BY`, "Radiance Crafted", `^Crafted:`, or any `hammer`/`anvil`/`smithing`/`crafting` atlas token in tooltip.
- **Stub entries + fast inspect queue** — rows appear instantly with name/class/realm, gear streams in as `INSPECT_READY` fires. Throttle 0.3s, immediate re-queue on `INSPECT_READY`. Guarded against `InspectFrame:IsShown()`, `InCombatLockdown()`, and conflicting `NotifyInspect` calls from other addons (via `hooksecurefunc`).
- **Sort bar** — "Sort by: Group / Name / Class / iLvl" buttons with asc/desc toggle, persistent.
- **Report bar** — channel dropdown (Say / Party / Raid / Instance; Guild deliberately excluded), craft-threshold dropdown (Ignore / < 1 / < 2 crafts), `[Report]` button, `[Ziemniak]` button on the far right.
- **Report** sends plain-text lines to the chosen channel, class as text suffix `(Shaman)` to avoid chat-server color-token rejection. Stagger `C_Timer.After(i * 0.3, ...)` between messages to dodge client-side chat throttle.
- **Ziemniak** — whisper `Jestes Ziemniakiem!!!` to every group member with gear issues (except self). Cross-realm `Name-Realm` format.
- **Inspect magnifying glass** on each row — `ToggleCharacter("PaperDollFrame")` for self, `InspectUnit(unit)` for others. Native Blizzard inspect window.
- **Minimap button** with custom axe icon (`Media/icon.tga`) and addon-list `IconTexture`.
- **Resizable window (height only)** — `SetResizeBounds` locks width, 260-1000 px height range, grip in bottom-right, height persisted in SavedVariables.
- **Slash commands**: `/barbi`, `/bi`, `/barbi refresh`, `/barbi report`, `/barbi ziemniak`, `/barbi dump N`, `/barbi help`.
- **Average item level** computed from own gear (sum of 16 slots / 16, with 2H-weapon mainhand counted twice) — consistent decimals for self and inspected players (Blizzard's `GetInspectItemLevel` returns integer; `GetAverageItemLevel` returns float — our own math bridges the gap).
- **Midnight Season 1 enchantable slots** hardcoded in `addon.CAN_HAVE_ENCHANT`: head, shoulder, chest, legs, feet, ring1, ring2, mainhand. Back, wrist, hands deliberately NOT flagged — no live enchants this season.
- **DB defaults with validation** — persisted values outside current option sets (e.g. deprecated `"GUILD"` channel) reset to defaults on `PLAYER_LOGIN`.

### Development notes (Midnight-specific gotchas we hit along the way)

- `BasicFrameTemplateWithInset` title decoration occupies y=0..-60; children positioned above that are hidden behind the gold strip. Resolved by placing sort/report bars at explicit Y offsets.
- Chat-server silently rejects messages with certain color tokens (particularly `|cffAARRGGBB`-style with float-derived bytes). Resolved by dropping color tokens from channel messages entirely and sending plain text.
- Client-side chat throttle silently drops messages fired < 100 ms apart. Resolved by `C_Timer.After` stagger.
- First `/barbi` in a 25-man raid triggered "script ran too long" (200 ms Blizzard watchdog) because self-gear collection does 16 tooltip scans. Resolved by deferring the heavy pass to next frame via `C_Timer.After(0, ...)`.
- PNG textures are formally supported but render as black rectangles in Midnight. Converted to TGA 32-bit BGRA (always worked, since vanilla).
- `NotifyInspect` conflicts with other addons (MRT, RaiderIO). Hooked via `hooksecurefunc` to detect external calls and back off for 2 seconds.
- `GetInspectItemLevel(unit)` is floored integer; `GetAverageItemLevel()` is float. Computed our own average to keep decimals consistent.
