# Level format

Each level lives in its own folder: `levels/<nn-name>/level.json`, plus the source `definition.ghx` or
canvas screenshots when provided. List the folder in `levels/index.json` to include it in the game, in play order.

The game never reads `.gh`/`.ghx` files at runtime: each script is transcribed once into `level.json`.
The node graph **is** the answer key. The preview is computed live from it by a small solver (`js/engine.js`).

## Top level

| Field | Meaning |
| --- | --- |
| `id`, `title`, `objective`, `learn` | Shown on the map and in the briefing |
| `monster` | The level's monster: a key from `js/monsters.js` (`spaghetti`, `tower`, `tree`, or `placeholder` until the 4th artwork arrives). Attacks get harder with the level's position, whichever monster it is. `?monster=<key>` in the URL previews one monster everywhere |
| `health` | Number of hearts |
| `guidance` | `guided` (slot says what it needs, 4 cards) · `standard` (5 cards) · `independent` (no card descriptions, 6 cards) |
| `lifesavers` | Counts of `hint`, `potion`, `fifty`, `clear`, `shield`, `second` |
| `params` | Sliders shown in the preview: `{ key, label, min, max, step, value }` |
| `order` | Optional build order of open node ids. Default: topological order of the graph |
| `boss` | Optional, `true` for the boss level |
| `goal` | Optional image of the finished result, e.g. `"goal.png"` placed in the level's folder (a Rhino render or viewport capture). Without it, the game renders the complete definition itself with the default slider values. Shown in the briefing and as a click-to-enlarge thumbnail in the preview |
| `source` | Optional, the Grasshopper file this level was transcribed from |
| `placeholder` | Optional, `true` while the level is a stand-in waiting for its real script |

## Difficulties

A level can offer several difficulties. Players pick one from the map; progress, stars and XP are saved per difficulty,
and beating any difficulty unlocks the next level.

```json
"difficulties": [
  { "id": "1", "name": "Beginner", "description": "…", "file": "difficulty-1.json", "health": 5, "hand": 3 },
  { "id": "2", "name": "Easy", "file": "difficulty-2.json" }
]
```

- `file` (optional): a definition for this difficulty in the level's folder, in the same format as `level.json`
  (`params`, `nodes`, `wires`, `order`, text…). Use one per Grasshopper file. Leave it out to reuse the graph in `level.json`.
- Anything else overrides the level's settings for this difficulty: `objective`, `goal`, `guidance`, `health`,
  `lifesavers`, `params`, plus these game rules:

| Rule | Meaning |
| --- | --- |
| `hand` | Cards in hand per decision (default 4 / 5 / 6 for guided / standard / independent) |
| `attacks` | Monster attack set, 0–3 (0 = only hits … 3 = every trick). Default: the level's position on the path |
| `timer` | Seconds per decision; running out costs a heart |
| `open` | Node ids the player must place; every other node starts on the canvas. Lets easier difficulties pre-place parts of the same graph |

Settings merge in this order: `level.json` → the difficulty's `file` → the difficulty entry itself.
A level without `difficulties` plays as a single "Standard" difficulty.

## Nodes

```json
{ "id": "div", "comp": "divideCurve", "open": true, "x": 180, "y": 25,
  "need": "…", "hint": "…", "correct": "…",
  "wrong": { "divideLength": "…", "*": "fallback for any other card" },
  "distractors": ["divideLength", "shatter", "offset"], "draft": true }
```

- `comp`: a component id from `js/data.js`.
- `open`: `true` means the player must place it; otherwise it starts on the canvas. Open more nodes in later levels.
- `x`, `y`: canvas position (graph units; about 130 between columns).
- `label`: display name (sliders, renamed params).
- `param`: for sliders, the `params` key that drives the slider value.
- `set`: values for unconnected inputs, keyed by port letter, as if typed into the component. Use `"$key"` to read a slider param and `[a, b]` for a domain. Planes: `"XY"`, `"XZ"`, `"YZ"`. Example: `{ "P": "XZ", "X": [-6, 6], "Y": [0, 8] }`.
- `values`: list output of a Panel, e.g. `[true, false]`.
- `graph`: Graph Mapper curve, `{ "type": "linear" | "pinch" | "sine" | "bell", "param": "<slider key>" }`.
- `baked`: fixed geometry for referenced Rhino geometry, or for any component too complex to simulate, e.g. `{ "curve": [[x,y,z], …], "smooth": true }`, `{ "point": [x,y,z] }`.
- `preview`: force this node's geometry on (`true`) or off (`false`). By default only "leaf" nodes preview.
- `ghost`: draw this node's geometry faintly, as context (e.g. the tower mass behind the panels).
- `degrees`: on Rotate, read the angle in degrees (Grasshopper's Degrees option on the A input).
- `in_map`: Grasshopper's input modifiers, e.g. `{ "C": "flatten" }` or `{ "T": "graft" }` (port letter → modifier).
- `passthrough`: while this open node is empty, data flows straight through it (used to show "before Graft" behaviour).
- `stage`: one or two sentences on what this step does to the definition ("Draw a spoke out from the centre…").
  Shown at the top of the definition panel as "Stage 2 of 5" while the player works on this node. `stage_draft: true` until reviewed.
- Text: `need`, `hint`, `correct`, `wrong`. Card hands default to components of the same category when `distractors` is omitted.
- `draft`: `true` while the text is unreviewed. `review.html` lists every draft entry.

## Wires

```json
{ "from": "sn.N", "to": "div.N", "check": { "side": "in", "prompt": "…", "hint": "…", "correct": "…", "wrong": { "C": "…", "*": "…" }, "draft": true } }
```

Ports are `nodeId.PortLetter` (or `nodeId.<index>` when letters repeat). A wire with `check` becomes a **wire check**:
the player must pick the right input (`side: "in"`) or output (`side: "out"`) port. Until answered, the wire is
treated as disconnected, so the preview shows the component's default behaviour.

## Supported components (solver)

Number Slider, Panel, Boolean Toggle, Point/Curve (baked), XY Plane, Construct Point, Unit X/Z, Vector 2Pt, Amplitude,
Line, Line SDL, Circle, Rectangle, Polygon (with fillet), Interpolate, Contour, Cap Holes, Divide Curve, Loft, Extrude, Pipe (thick curve), Boundary
Surfaces, Divide Domain², Isotrim, Area, Series, Range, Cull Pattern, List Item, Reverse/Sort/Shift List, Graft, Flatten,
Flip Matrix, Move, Rotate, Scale, Mirror, Sine, Multiplication, Addition, Radians, Remap, Graph Mapper.
Also, for levels transcribed from `.ghx` files (ported from the Godot build): Unit Y, Division, Negative, Circle CNR, End Points,
PolyLine, Fillet, Fillet (t), Discontinuity, Join Curves, Merge, Trim with Region, Arc SED, Evaluate Curve, and Point/Curve/Data
parameters passing their input through.

`js/components_extra.js` adds ~150 more components (cards, ports, descriptions) generated from the Godot build's
`godot/data/components_godot.json`, so any card a `.ghx` level uses exists; only the ones above can be computed.
Any other component needs a solver added to `js/engine.js`, or `baked` output.
