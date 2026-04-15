# BarbarianInspect

A World of Warcraft addon for the **Midnight** expansion that shows a compact raid/party gear overview in a single window. Spots missing enchants, empty gem sockets, and crafted items at a glance — and lets you yell at the offenders.

![Interface: 120001, 120005](https://img.shields.io/badge/Interface-120001%20%7C%20120005-blue)
![License: MIT](https://img.shields.io/badge/license-MIT-green)
![Version: 1.0.0](https://img.shields.io/badge/version-1.0.0-orange)

## Features

- **One window, whole raid** — self, party and raid members on a single, class-colored list
- **Per-slot gear icons** with item-level coloured by rarity, hover for full tooltip
- **Missing-enchant / empty-socket detection** — red border on the icon so you can spot offenders in a glance
- **Enchant quality badges** (silver / gold pentagon) extracted from tooltip via `C_TooltipInfo`
- **Crafted item badge** — hammer overlay on items with "Crafted"/"Radiance Crafted" tooltip lines
- **Sortable** by raid group, name, class, or item level (asc/desc, persistent choice)
- **Chat reports** — post a list of players with issues to Say / Party / Raid / Instance, with optional threshold for "people wearing fewer than N crafted items"
- **Ziemniak button** — bulk whisper every offender with a friendly `Jestes Ziemniakiem!!!` (the real killer feature)
- **Inspect icon** per row — opens the Blizzard character sheet (for yourself) or the native Inspect window (for others)
- **Resizable** (height), draggable, minimap button, persistent settings
- **Fast** — rows appear instantly with a lightweight stub, gear streams in as the inspect queue completes (~0.7s per player in a 25-man raid)

## Installation

1. Download or clone this repository into your WoW AddOns folder:
   ```
   World of Warcraft/_retail_/Interface/AddOns/BarbarianInspect/
   ```
2. Restart the game or type `/reload`.
3. Click the axe icon on the minimap, or type `/barbi`.

The addon ships as a single folder — no libraries, no setup required.

## Usage

| Command | Action |
|---------|--------|
| `/barbi` or `/bi` | Toggle the Raid Inspect window |
| `/barbi refresh` | Re-query every group member |
| `/barbi report` | Send a gear-check report to the currently selected chat channel |
| `/barbi ziemniak` | Whisper `Jestes Ziemniakiem!!!` to everyone with gear issues |
| `/barbi dump N` | Diagnostic — dump tooltip lines of your slot `N` (e.g. `16 = mainhand`) |
| `/barbi help` | Show the command list |

### Window controls

- **Sort by:** Group / Name / Class / iLvl — click an active button again to flip direction
- **Report:** channel dropdown + crafted-threshold dropdown + `[Report]` button + `[Ziemniak]` button (far right)
- **Per-row magnifying glass:** opens your character sheet (for yourself) or the Blizzard Inspect window (for others)
- **Resize grip** in the bottom-right corner — drag to adjust height (persistent across sessions)
- **Refresh** button (bottom-right) — re-queue all inspects

## Development & contributing

Contributions welcome. See [`CLAUDE.md`](./CLAUDE.md) for architecture, API references, and the Midnight-specific gotchas that bit us during development (`forbidden table` errors, chat throttle rejection, color token quirks, etc.). See [`CHANGELOG.md`](./CHANGELOG.md) for release history.

The project layout:

```
BarbarianInspect/
├── BarbarianInspect.toc     # manifest
├── Init.lua                 # namespace, constants (slots, enchantable slots)
├── Media/icon.tga           # addon/minimap icon
├── Core/
│   ├── Events.lua           # single event frame + dispatch table
│   ├── Inspect.lua          # NotifyInspect queue, item-link parsing, gear collection
│   └── Report.lua           # chat report + Ziemniak whisper logic
├── UI/
│   ├── Minimap.lua          # minimap button
│   └── MainFrame.lua        # main window — sort bar, report bar, row list, resize
└── BarbarianInspect.lua     # bootstrap — slash commands, PLAYER_LOGIN init
```

## License

MIT — see [LICENSE](./LICENSE). Free to use, fork, modify. No warranty.
