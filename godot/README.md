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
| `web/js/monsters.js` (options + phases) | `data/monsters.json` | `tools/sync_from_web.py` |
| `web/img/*` (hero sprite, monster paintings) | `img/` | `tools/sync_from_web.py` |

**When you run from the editor inside the repo, levels load straight from `../web/levels`**, so level edits
made for the web version show up without syncing. Run the sync script before exporting a build, or when
`data.js`, `monsters.js` or `web/img` change:

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

- The hero is the web version's sprite: `img/hero-main.png` (standing, bobbing) plus 4-frame reactions
  `img/hero-success-N.png`, `hero-damage-N.png`, `hero-defeat-N.png` (`scripts/ui/hero_view.gd`).
- Monsters come from `data/monsters.json`. Each level names one monster option (`"monster"` in level.json);
  its attacks come from the phase for the level's position on the path (the last phase repeats).
- An option with `img` uses that painting (`img/monster-<key>.png`); otherwise it uses the web SVG
  `art/monster_<art>.svg`. To try one monster on every level, run with `-- --monster=<key>`
  (the web version's `?monster=<key>`).
- Godot-only monsters live in `data/monsters_godot.json` with their art in `art/monster-*.png`. That file is
  merged over the synced `monsters.json` (same key = override, new key = new option) and the sync never touches it.
  Current: Spaghetti Boss v2 art, The Staris, The Voronoi Golem. Move an entry into `web/js/monsters.js` once
  the web version uses it, then delete it there.
- A level can set `"goal": "<file>.png"` in its folder for the Goal picture; otherwise the game renders
  the finished definition.

## Layout

```
art/        SVG art from the web version (fallback monsters, hearts, lifesaver icons)
img/        hero sprite frames and monster paintings (copied from web/img)
data/       components.json, monsters.json (generated)
fonts/      Cinzel + Barlow (SIL Open Font License), the web version's fonts
levels/     level.json copies (generated)
scenes/     main.tscn
scripts/core/  GHData, GHEngine, Geo, LevelLoader, Battle, SaveData: game logic, no UI
scripts/ui/    UIKit, Chip, GraphView, PreviewView, CardView, ArtView, HeroView, FxViews
scripts/main.gd  title, map and battle screens, modals, toasts, keyboard
tools/      sync_from_web.py
tests/      run_checks.gd, screenshots.gd
```

Godot-only additions (not in the web version): a Main Menu button on the map and battle screens, and an Exit button
on the title screen (hidden in web exports, where a page can't close itself).

Progress is saved to `user://pathogen_save.json`. Run with `-- --all` to unlock every level for testing.
