# CLAUDE.md — developer notes

Short developer reference. User-facing docs are in `README.md`, release history in `CHANGELOG.md`.

## API documentation

Order of trust (highest first):

1. [warcraft.wiki.gg](https://warcraft.wiki.gg/wiki/World_of_Warcraft_API) — community wiki, most up-to-date per patch
2. [Townlong Yak FrameXML live](https://www.townlong-yak.com/framexml/live) — live Blizzard UI source
3. [Gethe/wow-ui-source](https://github.com/Gethe/wow-ui-source) — FrameXML mirror, greppable

## Midnight (12.x) quirks we hit

Things that silently fail or behave differently from pre-Midnight. Each point cost hours; keep notes.

- **`BasicFrameTemplateWithInset` title occupies y=0..-60** from top; anything anchored in that range is hidden behind the gold title strip. Put content at y <= -60 (or use `frame.Inset` as parentKey).
- **PNG icons render as black** in Midnight — formally supported, practically broken. Convert to TGA 32-bit BGRA (`ffmpeg -i src.png -pix_fmt bgra out.tga`). Works since vanilla.
- **200 ms script watchdog** — if any single script run exceeds ~200 ms Blizzard kills it with "script ran too long". Heavy work (16× `C_TooltipInfo.GetInventoryItem` during initial load) must be deferred with `C_Timer.After(0, ...)`.
- **Chat channel color-token rejection** — server silently drops messages to PARTY/RAID that contain certain `|cffAARRGGBB|r` patterns (particularly with float-derived bytes). Send plain text in channel messages; keep colors only in local print.
- **Chat client throttle** — consecutive `SendChatMessage` calls within ~100 ms are silently dropped. Stagger via `C_Timer.After(i * 0.3, ...)`.
- **`NotifyInspect` conflicts** with MRT, RaiderIO and others. Detect foreign calls via `hooksecurefunc("NotifyInspect", ...)` and back off.
- **`GetInspectItemLevel(unit)` returns integer** (floored); `GetAverageItemLevel()` returns float. Compute the average manually from 16 slot ilvls for consistency.
- **"Forbidden tables"** — many native frames (`CastingBarFrame`, `Communities`, etc.) reject `__index` access from addons. Use API functions, not direct field access.
- **Pydantic-style secure values** — some args to `UnitIsUnit`, `C_Timer.NewTimer` no longer accept values coming from secure scope via an insecure addon callback.

## Hardcoded per-season data

The one thing there's no API for and that changes each season.

### Midnight Season 1 enchantable slots

In `Init.lua → addon.CAN_HAVE_ENCHANT`. Currently: `HEAD, SHOULDER, CHEST, LEGS, FEET, FINGER1, FINGER2, MAINHAND`. Back / wrist / hands have NO live enchants this season. **Update this table each season/patch.** There is no API to derive it — the only reliable way is to check in-game which crafted enchants exist for which slots.

Considered alternatives (deferred):

- Maintain a known enchantID set per expansion; treat unknown/old enchant IDs as "missing" too.
- Tooltip scan for an "Enchanted:" line — would only tell us *if* an item has an enchant, not whether its slot *should* have one this season.

## Developer slash commands

- `/barbi dump N` — dump raw tooltip lines of player's slot N (e.g. `16 = mainhand`) to local chat. Use when an item type doesn't match existing crafted/enchant detection patterns; you can see the exact strings Blizzard emits and add new patterns to `ScanItemTooltip`.

## File structure

See `README.md` for the project tree. Convention: one concern per file, `Init.lua` declares the namespace first, `Core/*` is framework-agnostic logic, `UI/*` touches frames.
