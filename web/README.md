# PathOGen

**Build the Script. Survive the Monster. Master Grasshopper.**

A browser game that teaches Grasshopper 3D. Each level is a real Grasshopper definition guarded by a monster:
pick the right component cards, answer wire checks (which input/output a wire goes into), and finish the
script before your health runs out. The 3D preview updates live as the definition grows.

## Run

Plain HTML/CSS/JS — no build step, no dependencies. Serve the `web` folder with any static server:

```bash
python -m http.server 5173 --directory web
```

Then open http://localhost:5173. Add `?all` to the URL to unlock every level (for testing), or `?inspect` for the
level inspector: jump to any level and difficulty and step through its definition stage by stage (`js/inspect.js`).

## Structure

| Path | What it holds |
| --- | --- |
| `levels/<nn-name>/level.json` | One level each: component graph (the answer key), sliders, card text. See [levels/README.md](levels/README.md) |
| `levels/index.json` | Which levels are in the game, in order |
| `review.html` | Lists every hint/explanation still marked `"draft": true`, for the team to review |
| `js/data.js` | Component library (real GH components: inputs, outputs, descriptions) and icons |
| `js/engine.js` | Simplified Grasshopper solver: data trees, longest-list matching, component solvers, preview builder |
| `js/loader.js` | Loads and validates `level.json` files, derives build order and wire checks |
| `js/monsters.js` | Monsters (one per level, chosen in each level.json) and the attack sets that escalate along the path |
| `img/` | Web-sized monster art and hero sprite frames, cut from `Images/Monster` and `Images/Hero` (hero v3) |
| `js/preview.js` | Wireframe 3D viewport |
| `js/art.js` | Original SVG monsters, hero and lifesaver icons |
| `js/game.js` | Game engine: turns, attacks, lifesavers, scoring, save data, rendering |

Levels are loaded with `fetch()`, so the game must be served over http (not opened as a file).
Each level's difficulties are transcribed from the team's Grasshopper files in `GameLevels/LevelA`–`LevelD`
(`A01`–`A05`, `B01`–`B03`, `C01`–`C03`, `D01`–`D03`), one JSON file per method. Hint and explanation text is generated or drafted
and still needs a review pass.

Progress (XP, stars, unlocked levels) is stored in the browser's localStorage.
