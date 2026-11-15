# PathOGen (Godot)

**Build the Script. Survive the Monster. Master Grasshopper.**

The Godot 4 version of the PathOGen web game in `../web`. It plays the same levels with the same rules,
the same Grasshopper solver and the same monsters, with painted art where the team has made it.

Open this `godot` folder in **Godot 4.4 or newer** and press Play.

## Where the game data comes from

The web version is the source of truth. Godot reads the same files:

| Web file | Godot copy | How it gets there |
|---|---|---|
| `web/levels/**/level.json`, `index.json` | `levels/` | `tools/sync_from_web.py` (copied as-is) |
| `web/js/data.js` (components, icons, filler) | `data/components.json` | `tools/sync_from_web.py` |
| `web/js/monsters.js` (options + phases) | `data/monsters.json` | `tools/sync_from_web.py` |
| `web/js/components_extra.js`, `web/js/gh_icons.js` | merged into `data/components.json` | `tools/sync_from_web.py` |
| `web/img/**` (hero, monsters, start-screen art, `gh-icons/`) | `img/` | `tools/sync_from_web.py` |
| `web/audio/**.wav` (effects + `bgm/` music) | `audio/` | `tools/sync_from_web.py` |

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

## Sound

`scripts/core/sound.gd` plays the web version's effects (card select, place, wire, correct, damage, victory, button
clicks) and music (title, battle, critical below 30% health, defeat). The Music button and volume slider sit top right
on every screen; turning music off also mutes the effects, as on the web. Settings are kept in
`user://pathogen_audio.json`.

## Guides

"Choose your guide" (title screen, or a card on About Us) swaps the hero for any team member's avatar
(`img/avatars/*.png`, synced from `web/img/avatars`). Avatars react with motion (jump, shake, slump) since they are
single pictures; the Spaghetti Hero keeps its sprite frames. The choice is saved with the progress.

## Team

Made at the AECTech Hackathon 2026 by Abhishek Bawiskar, Garrett Herbst, Joel Hills, Riku Kanemitsu, Danny Karas,
Maya Mashiach and Kazu Tajima (alphabetical by last name).
The names are in `TEAM` in `scripts/main.gd` (the About Us page from the title screen, and the end-of-game screen).

## Difficulties

A level can offer several difficulties (the web version's `difficulties` list in level.json: see
`web/levels/README.md`). Clicking a level on the map opens the difficulty picker; stars and XP are saved per
difficulty, and beating any one unlocks the next level. `hand`, `attacks`, `timer` and `open` work as on the web.

## Levels from Grasshopper files (.ghx)

The web version now carries the .ghx levels itself (`web/levels/*/A01.json` ... `D03.json`, with the extra components
in `web/js/components_extra.js` and Grasshopper's icons in `web/js/gh_icons.js` + `web/img/gh-icons/`), so Godot gets
them through `tools/sync_from_web.py` like any other level.

`tools/ghx_to_level.py` is still here for trying a new .ghx canvas in Godot before the web has it:
`python godot/tools/ghx_to_level.py GameLevels/LevelX 0N-level-folder` writes `levels_godot/<level>/` and
`data/components_godot.json`. A `levels_godot/<level>/difficulties.json` with a non-empty list replaces that level's
difficulties in Godot only; delete the folder (or empty the list) to go back to the web's levels.

## Layout

```
art/        SVG art from the web version (fallback monsters, hearts, lifesaver icons)
img/        hero sprite frames and monster paintings (copied from web/img)
data/       components.json, monsters.json (generated)
fonts/      Cinzel + Barlow (SIL Open Font License), the web version's fonts
levels/     level.json copies (generated)
levels_godot/  Godot-only difficulty files converted from .ghx
scenes/     main.tscn
scripts/core/  GHData, GHEngine, Geo, LevelLoader, Battle, SaveData: game logic, no UI
scripts/ui/    UIKit, Chip, GraphView, PreviewView, CardView, ArtView, HeroView, FxViews
scripts/main.gd  title, map and battle screens, modals, toasts, keyboard
tools/      sync_from_web.py, ghx_to_level.py (+ ghx.py reader)
tests/      run_checks.gd, screenshots.gd, parity_dump.gd
```

Godot-only additions (not in the web version): a Main Menu button on the map and battle screens, and an Exit button
on the title screen (hidden in web exports, where a page can't close itself).

Progress is saved to `user://pathogen_save.json`. Run with `-- --all` to unlock every level for testing.
