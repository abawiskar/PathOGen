# PathOGen (Godot)

**Build the Script. Survive the Monster. Master Grasshopper.**

The Godot 4 version of the PathOGen web game in `../web`. It plays the same eight levels with the same rules,
the same Grasshopper solver and the same monsters, with painted art where the team has made it.

Open this `godot` folder in **Godot 4.4 or newer** and press Play.

## Where the game data comes from

The web version is the source of truth. Godot reads the same files:

| Web file | Godot copy | How it gets there |
|---|---|---|
| `web/levels/**/level.json`, `index.json` | `levels/` | `tools/sync_from_web.py` (copied as-is) |
| `web/js/data.js` (components, icons, filler) | `data/components.json` | `tools/sync_from_web.py` |
| `web/js/monsters.js` | `data/monsters.json` | `tools/sync_from_web.py` |

**When you run from the editor inside the repo, levels load straight from `../web/levels`**, so level edits
made for the web version show up without syncing. Run the sync script before exporting a build, or when
`data.js` or `monsters.js` change:

```
python godot/tools/sync_from_web.py
```

Other web files are ported by hand, so check them when the web version changes:

| Web file | Godot file |
|---|---|
| `js/engine.js` (solver) | `scripts/core/gh_engine.gd` |
| `js/loader.js` | `scripts/core/level_loader.gd` |
| `js/preview.js` (geometry + viewport) | `scripts/core/geo.gd`, `scripts/ui/preview_view.gd` |
| `js/game.js` (rules) | `scripts/core/battle.gd` |
| `js/game.js` (screens) | `scripts/main.gd`, `scripts/ui/*` |
| `js/art.js` | `art/*.svg` (exported once) |

## Art

- `art/hero.png` is the hero (red-scarf concept).
- `art/monster_<key>.png` is painted monster art. Any monster without a PNG uses the web version's SVG
  (`art/monster_<key>.svg`). Current PNGs: `rootbound`, `branchmaw`, `wyrm` (Spaghetti Wyrm) and
  `hexwarden` (the twisted tower). To give a monster new art, drop in `monster_<key>.png` with a transparent background.
- Monster keys are in `data/monsters.json`.

## Checks

```
godot --headless -s res://tests/run_checks.gd
```

Loads every level, plays a perfect run (every correct card must be in its hand, 3 stars) and a run full of
mistakes. Exits with code 1 on failure.

`tests/screenshots.gd` drives the real UI and saves screenshots (needs a display, not `--headless`).

The solver was checked against the web version: for every level and every build step, the preview
geometry (lines, points, labels, arrows) matches `js/engine.js` exactly.

## Layout

```
art/        hero + monster art (PNG painted, SVG from the web version), lifesaver icons
data/       components.json, monsters.json (generated)
fonts/      Cinzel + Barlow (SIL Open Font License), the web version's fonts
levels/     level.json copies (generated)
scenes/     main.tscn
scripts/core/  GHData, GHEngine, Geo, LevelLoader, Battle, SaveData: game logic, no UI
scripts/ui/    UIKit, Chip, GraphView, PreviewView, CardView, ArtView, FxViews
scripts/main.gd  title, map and battle screens, modals, toasts, keyboard
tools/      sync_from_web.py
tests/      run_checks.gd, screenshots.gd
```

Progress is saved to `user://pathogen_save.json`. Run with `-- --all` to unlock every level for testing.
