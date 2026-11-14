# Level format

Each level lives in its own folder: `levels/<nn-name>/level.json`, plus the source `definition.ghx` or
canvas screenshots when provided. List the folder in `levels/index.json` to include it in the game, in play order.

The game never reads `.gh`/`.ghx` files at runtime: each script is transcribed once into `level.json`.
The node graph **is** the answer key. The preview is computed live from it by a small solver (`js/engine.js`).

## Top level

| Field | Meaning |
| --- | --- |
| `id`, `title`, `objective`, `learn` | Shown on the map and in the briefing |
| `monster` | A key from `js/monsters.js` (`rootbound`, `mossback`, `blightmoth`, `glyphleech`, `wraith`, `hexwarden`, `branchmaw`, `wyrm`) |
| `health` | Number of hearts |
| `guidance` | `guided` (slot says what it needs, 4 cards) · `standard` (5 cards) · `independent` (no card descriptions, 6 cards) |
| `lifesavers` | Counts of `hint`, `potion`, `fifty`, `clear`, `shield`, `second` |
| `params` | Sliders shown in the preview: `{ key, label, min, max, step, value }` |
| `order` | Optional build order of open node ids. Default: topological order of the graph |
| `boss` | Optional, `true` for the boss level |

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
- `passthrough`: while this open node is empty, data flows straight through it (used to show "before Graft" behaviour).
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
Line, Line SDL, Circle, Rectangle, Polygon, Interpolate, Divide Curve, Loft, Extrude, Pipe (thick curve), Boundary
Surfaces, Divide Domain², Isotrim, Area, Series, Range, Cull Pattern, List Item, Reverse/Sort/Shift List, Graft, Flatten,
Flip Matrix, Move, Rotate, Scale, Mirror, Sine, Multiplication, Addition, Radians, Remap, Graph Mapper.
Any other component needs a solver added to `js/engine.js` (and an entry in `js/data.js`), or `baked` output.
