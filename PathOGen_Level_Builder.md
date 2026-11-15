# PathOGen Level Builder: instructions for the model

> **How to use this file.** Attach this file and one Grasshopper definition to a chat with an LLM, then say:
> *"Follow PathOGen_Level_Builder.md and turn the attached Grasshopper file into game levels."*
> Save the definition as **.ghx** (File › Save As › Grasshopper XML). A `.gh` file is binary and the model can't
> read it. If you only have a `.gh` file, a canvas screenshot plus a list of components and wires also works.

---

## 0. Your role and the job

You are a level designer for **PathOGen**, a browser game that teaches Grasshopper (the visual scripting tool
in Rhino). Each level is a real Grasshopper definition that the player rebuilds one component at a time,
choosing the right component card from a hand while a monster attacks. A live 3D preview shows the geometry
growing with every correct move.

You are given **one Grasshopper definition**. Turn it into:

1. **A level plan.** Split the script into 2–4 levels that build on each other, each with 3 difficulties.
2. **Game files.** Write one JSON file per difficulty and one `level.json` per level, ready to drop into the
   repo's `web/levels/` folder.
3. **A Grasshopper build sheet.** For each difficulty, list the stages, the question nodes and their wrong
   choices, so the team can build the matching `.ghx` canvas.

Work through sections 1–8 in order. **Stop after section 3** and show the plan to the user before you write any
JSON, because the plan is where they'll want to make changes.

---

## 1. Read the script

Parse the definition and report:

- **What it makes.** One sentence, e.g. "a twisting, tapering tower with floor slabs and mullions".
- **Inputs.** Every Number Slider with its name, min, max and value, plus any Boolean Toggles and Panels with
  typed values.
- **The chain.** The components in dependency order with the wires between them. Use port names: Grasshopper
  wires connect *output port → input port*.
- **Data structure.** Where lists and data trees appear, e.g. Range or Series makes a list; Graft, Divide Curve
  on a list, Flip Matrix and Partition work on trees. This is what makes a method "harder".
- **Settings typed into inputs.** Persistent values on unconnected inputs, input modifiers (Graft, Flatten,
  Reverse), the Degrees option on Rotate's angle, and Graph Mapper curve types.
- **Unsupported components.** Anything not in the table in section 5. Plan a substitute for each one; see
  section 5.2.

If the file has groups or scribbles, read them too: they usually name the stages.

---

## 2. Split it into levels

A **level** is one chapter of the script, and each level continues from the one before. The original game path
works like this:

| Level | Builds | Starts from |
| --- | --- | --- |
| A (game level 1) | the base profile: Construct Point → Polygon | nothing |
| B (game level 2) | the mass: lift, twist, loft, cap | A's profile |
| C (game level 3) | the floors: contour or setback, extrude, cap, area | A + B |
| D (game level 4) | the facade: panels, joints, mullions | A + B (C is not needed) |

Rules:

- **2–4 levels per script.** Each level adds **4–10 new components** to learn.
- **Earlier levels are given.** In later levels, components from earlier levels are pre-placed (`"open": false`)
  so the player only builds the new chapter.
- **End each level on visible geometry.** Every level should finish with something the player can see grow:
  a solid, slabs or panels. Don't stop on a number or a plane.
- **Name each level.** Give a title, a one-line objective and a one-line "learn" sentence. Pick a monster key
  from `tower`, `spaghetti`, `tree`, `voronoi` or `placeholder`, and reuse monsters freely.

New levels **append** to the game. Use the next free number and folder name, e.g. `05-<short-name>`, and level IDs
`E`, `F`, … unless the user tells you to replace existing levels.

---

## 3. Make three difficulties per level

Each level has **3 difficulties**. Each one is a **different method that gets the same result**, so the player
learns several ways to build the same thing. Level IDs are the level letter plus a number: `E01`, `E02`, `E03`.

| # | Difficulty name | Method | What makes it harder |
| --- | --- | --- | --- |
| 01 | Hopper Hatchling | **Simple**: single items, the fewest components, direct transforms (Move, Rotate) | nothing; it introduces the ideas |
| 02 | Shape Scout | **Intermediate**: lists (Range/Series), so every item is built at once; blend maths (Multiplication + Addition) | list thinking |
| 03 | Pattern Pouncer | **Complex**: data trees (Graft, Flip Matrix), Graph Mapper or Sine shaping, more steps | tree thinking and shaping functions |

- The user's file is usually one of these three. Work out which, then **write the other two yourself**, using
  only supported components (section 5). Each method must produce the same kind of geometry.
- **Every difficulty is a full walkthrough.** Hints never fade. Difficulty rises only through the method
  itself, the hand size and the monster's attacks (section 6.4).

**Show the plan to the user and wait for their go-ahead.** For each level and difficulty, list the stages, the
question component for each stage, and the given stages.

---

## 4. Design the stages (the walkthrough)

Split each difficulty's new work into **stages**:

- **One concept per stage.** For example, "How tall is the tower?" (Multiplication), "Point it upward"
  (Unit Z), "Copy the profile to the top" (Move), "Twist the top" (Rotate). If a stage needs two ideas, split it.
- **One question node per stage.** This is the one component the player places. The rest of the stage is
  pre-placed. Pick the component that carries the stage's concept, not a helper.
- **Order.** Questions follow the build order, so a question node's inputs must exist when it's placed.
- **Given stages** from earlier levels come first, pre-placed, with a short "Given" note.
- **Optional last stage: "Check your result".** An Area (or other analysis) node feeding a Panel turns the
  output into a number, e.g. envelope area or floor plate areas. It teaches reading results as data.
- **Repeats are fine.** The same component can be the question in two stages or methods (e.g. Divide Curve
  for the base points, then again for the top points). Prefer new components where the method allows.

Each stage gets a **note**. This text becomes the stage text in the game and a scribble on the Grasshopper
canvas:

```
STEP 4  -  Twist the top
Goal: the roof outline turned by the twist angle.
Idea: a rotation needs a centre (the tower's centre point) and an angle.
Watch for: Angle is in radians unless the A input is set to Degrees (right-click A > Degrees).
Wire check: twist slider -> A, centre point -> P.
```

- **Goal**: what the stage produces, in plain words.
- **Idea**: the concept, in one or two sentences, in the player's language rather than Grasshopper jargon.
- **Watch for**: the most common mistake.
- **Wire check** (optional): which input a wire goes into, for the inputs people get wrong. These become
  wire-check questions in the game (section 6.3). Use 1–3 per difficulty.

---

## 5. Components the game can run

The game has **no Grasshopper at runtime**. A small solver recomputes the preview from the JSON. **Every node in
a difficulty file must be one of these components.** Wrong-answer cards (distractors) can be any Grasshopper
component (section 6.2).

### 5.1 Supported components: id, ports (letter = name)

| id | Component | Inputs | Outputs |
| --- | --- | --- | --- |
| `slider` | Number Slider | (none) | N=Number |
| `panel` | Panel | in=Input | out=Output |
| `toggle` | Boolean Toggle | (none) | B=Boolean |
| `pointParam` / `curveParam` / `dataParam` / `numberParam` | Point / Curve / Data / Number parameter (passes data through) | Pt / C / D / N | Pt / C / D / N |
| `xyPlane` | XY Plane | O=Origin | P=Plane |
| `constructPoint` | Construct Point | X, Y, Z | Pt=Point |
| `unitX` / `unitY` / `unitZ` | Unit X / Y / Z | F=Factor | V=Vector |
| `vector2pt` | Vector 2Pt | A=Point A, B=Point B, U=Unitize | V=Vector, L=Length |
| `amplitude` | Amplitude | V=Vector, A=Amplitude | V=Vector |
| `line` | Line | A=Start point, B=End point | L=Line |
| `lineSDL` | Line SDL | S=Start, D=Direction, L=Length | L=Line |
| `circle` | Circle | P=Plane, R=Radius | C=Circle |
| `circleCNR` | Circle CNR | C=Center, N=Normal, R=Radius | C=Circle |
| `rectangle` | Rectangle | P=Plane, X=X size, Y=Y size, R=Radius | R=Rectangle, L=Length |
| `polygon` | Polygon | P=Plane, R=Radius, S=Segments, Rf=Fillet | P=Polygon, L=Length |
| `interpolate` | Interpolate | V=Vertices, D=Degree, P=Periodic, K=Knot style | C=Curve, L=Length, D=Domain |
| `polyline` | PolyLine | V=Vertices, C=Closed | Pl=Polyline |
| `arcSED` | Arc SED | S=Start, E=End, D=Direction | A=Arc, P=Plane, R=Radius |
| `divideCurve` | Divide Curve | C=Curve, N=Count, K=Kinks | P=Points, T=Tangents, t=Parameters |
| `endPoints` | End Points | C=Curve | S=Start, E=End |
| `evaluateCurve` | Evaluate Curve | C=Curve, t=Parameter | P=Point, T=Tangent, A=Angle |
| `discontinuity` | Discontinuity | C=Curve, L=Level | P=Points, t=Parameters |
| `fillet` | Fillet | C=Curve, R=Radius | C=Curve |
| `filletCtR` | Fillet (at parameter) | C=Curve, t=Parameter, R=Radius | C=Curve, t=Parameter |
| `joinCurves` | Join Curves | C=Curves, P=Preserve | C=Curves |
| `trimWithRegion` | Trim with Region | C=Curve, R=Region, P=Plane | Ci=Inside, Co=Outside |
| `loft` | Loft | C=Curves, O=Options | L=Loft |
| `extrude` | Extrude | B=Base, D=Direction | E=Extrusion |
| `pipe` | Pipe | C=Curve, R=Radius, E=Caps | P=Pipe |
| `boundary` | Boundary Surfaces | E=Edges | S=Surfaces |
| `divDomain2` | Divide Domain² | I=Domain, U=U Count, V=V Count | S=Segments |
| `isotrim` | Isotrim | S=Surface, D=Domain | S=Surface |
| `capHoles` | Cap Holes | B=Brep | B=Brep |
| `contour` | Contour | S=Shape, P=Point, N=Direction, D=Distance | C=Contours |
| `area` | Area | G=Geometry | A=Area, C=Centroid |
| `series` | Series | S=Start, N=Step, C=Count | S=Series |
| `range` | Range | D=Domain, N=Steps | R=Range |
| `cullPattern` | Cull Pattern | L=List, P=Pattern | L=List |
| `listItem` | List Item | L=List, i=Index, W=Wrap | i=Item |
| `reverseList` | Reverse List | L=List | L=List |
| `sortList` | Sort List | K=Keys, A=Values A | K=Keys, A=Values A |
| `shiftList` | Shift List (always wraps) | L=List, S=Shift, W=Wrap | L=List |
| `merge` | Merge | D1, D2, D3 | R=Result |
| `graft` | Graft Tree | T=Tree | T=Tree |
| `flatten` | Flatten Tree | T=Tree, P=Path | T=Tree |
| `flipMatrix` | Flip Matrix | D=Data | D=Data |
| `move` | Move | G=Geometry, T=Motion | G=Geometry, X=Transform |
| `rotate` | Rotate | G=Geometry, A=Angle, P=Plane | G=Geometry, X=Transform |
| `scale` | Scale | G=Geometry, C=Centre, F=Factor | G=Geometry, X=Transform |
| `mirror` | Mirror | G=Geometry, P=Plane | G=Geometry, X=Transform |
| `sine` | Sine | x=Value | y=Result |
| `multiplication` | Multiplication | A, B | R=Result |
| `addition` | Addition | A, B | R=Result |
| `division` | Division | A, B | R=Result |
| `negative` | Negative | x=Value | y=Result |
| `radians` | Radians | D=Degrees | R=Radians |
| `remap` | Remap Numbers | V=Value, S=Source, T=Target | R=Mapped, C=Clipped |
| `graphMapper` | Graph Mapper | x=Numbers | y=Mapped |

The solver does Grasshopper-style **longest-list matching** and **data trees**.

### 5.2 Substitutions for unsupported components

| Unsupported | Use instead |
| --- | --- |
| Subtraction | Multiplication by −1 plus Addition, or a Range with domain `[1, 0]` to get `1 − t` |
| Offset Curve | Scale about the curve's centre point (a setback) |
| Rotate Plane / Rotate Axis / Orient | Rotate with a point in P (rotation about Z through that point) |
| Volume | Area (it also gives the centroid) |
| Deconstruct / Point list maths | Construct Point fed by Multiplication / Range |
| Divide Surface, Surface Frames | Divide Domain² + Isotrim, or Divide Curve on contours |
| Sweep1 / Sweep2 / Network Surface | Loft through section curves |
| Plugin components (Kangaroo, LunchBox, …) | Rebuild with natives, or use `"baked"` geometry (section 6.1) |

**Grasshopper caveat:** Isotrim and Divide Domain² need a **single-face surface**. A Loft through only 2 filleted
polygons comes out multi-face in real Grasshopper. Loft through many section curves, or use Divide Curve + Line
for a simple facade.

---

## 6. Write the game files

### 6.1 Files and where they go

```
web/levels/index.json                     add "<nn-name>" to "levels", in play order
web/levels/<nn-name>/level.json           the level: title, monster, difficulties
web/levels/<nn-name>/<ID>.json            one per difficulty: params, nodes, wires, order
```

**`level.json`**, using the real Level B file as the pattern:

```json
{
  "id": 5,
  "title": "Build the Mass",
  "objective": "One sentence: what the player builds in this level.",
  "learn": "One sentence: the skills, e.g. vectors and transforms, then Loft and Cap Holes.",
  "monster": "tower",
  "health": 4,
  "guidance": "guided",
  "lifesavers": { "hint": 3, "potion": 1, "fifty": 1, "clear": 1, "shield": 1, "second": 1 },
  "params": [], "nodes": [], "wires": [],
  "difficulties": [
    { "id": "E01", "name": "Hopper Hatchling", "description": "Walkthrough: …", "file": "E01.json",
      "guidance": "guided", "health": 5, "hand": 3, "attacks": 0,
      "lifesavers": { "hint": 3, "potion": 2, "fifty": 2, "clear": 1, "shield": 2, "second": 2 } },
    { "id": "E02", "name": "Shape Scout", "description": "Walkthrough: …", "file": "E02.json",
      "guidance": "guided", "health": 4, "hand": 4, "attacks": 0,
      "lifesavers": { "hint": 3, "potion": 1, "fifty": 1, "clear": 1, "shield": 1, "second": 1 } },
    { "id": "E03", "name": "Pattern Pouncer", "description": "Walkthrough: …", "file": "E03.json",
      "guidance": "guided", "health": 4, "hand": 5, "attacks": 1,
      "lifesavers": { "hint": 2, "potion": 1, "fifty": 1, "clear": 1, "shield": 1, "second": 1 } }
  ]
}
```

The empty `params` / `nodes` / `wires` are fine: each difficulty's `file` supplies the graph. Settings merge in this
order: `level.json` → the difficulty file → the difficulty entry.

**Difficulty file (`E01.json`):**

```json
{
  "source": "GameLevels/LevelE/E01.ghx",
  "method": "E01",
  "params": [
    { "key": "s1", "label": "Floors", "min": 5, "max": 80, "step": 1, "value": 30 },
    { "key": "s2", "label": "Floor-to-floor (ft)", "min": 10, "max": 18, "step": 0.1, "value": 13 }
  ],
  "nodes": [ … ],
  "wires": [ … ],
  "order": ["mult", "uz", "mv", "rot", "loft", "cap"]
}
```

- `params`: one per slider. The slider node points at it with `"param": "s1"`. These sliders appear in the
  preview, and dragging them re-runs the definition.
- `order`: the **open** node ids in the order the player places them. It must list every open node.

**Node fields**

| Field | Meaning |
| --- | --- |
| `id` | short unique id, e.g. `mv`, `rot`, `slider3` |
| `comp` | a component id from section 5.1 |
| `open` | `true` = the player must place it (a question); `false` = pre-placed |
| `x`, `y` | canvas position. Columns are about 130–180 apart, left to right in build order, with stages side by side |
| `label` | display name (sliders, renamed parameters) |
| `param` | sliders only: the `params` key that drives the value |
| `set` | values for **unconnected** inputs by port letter: numbers, `[a, b]` for a domain, `"XY"`/`"XZ"`/`"YZ"` planes, `"$s1"` to read a slider param. E.g. `{ "B": -1 }`, `{ "D": [1, 0] }` |
| `degrees` | Rotate only: `true` = the angle is in degrees |
| `in_map` | input modifiers: `{ "T": "graft" }` or `{ "C": "flatten" }` |
| `graph` | Graph Mapper: `{ "type": "linear" \| "pinch" \| "sine" \| "bell" }` or `{ "type": "bezier", "cp": [[0,0],[0.3,1],[0.7,1],[1,0]] }` |
| `preview` | force geometry on (`true`) or off (`false`). By default only nodes with no outgoing wires preview |
| `ghost` | draw faintly as context, e.g. the given tower mass behind the floors |
| `baked` | fixed geometry for anything the solver can't compute: `{ "curve": [[x,y,z], …] }`, `{ "point": [x,y,z] }` |
| `question` | open nodes: the question id, e.g. `"E01_Q03"` |
| `stage` | open nodes: the stage text, "Title: Goal. Idea." Shown as "Stage n of N" |
| `need` | open nodes: what the slot needs, in plain words ("a transform that lifts the outline along the up vector") |
| `hint` | open nodes: the Grasshopper tab › panel, plus the "Watch for" line |
| `correct` | open nodes: why this component is right (1–2 sentences) |
| `wrong` | open nodes: `{ "<distractor id>": "why it fails here", "*": "fallback" }` |
| `distractors` | open nodes: wrong component ids for the hand (section 6.2) |
| `draft`, `stage_draft` | always `true` on text you write, so the team reviews it in `review.html` |

**Wires**: `{ "from": "nodeId.OutPort", "to": "nodeId.InPort" }`, using the port letters in section 5.1. Several
wires into one input merge into a list, like Loft's C taking the base outline and the top outline.

### 6.2 Distractors (wrong cards)

Give each open node **6–12 distractor ids**. These are real Grasshopper components that are **plausible but wrong
for this exact step**: the same tab or a similar job, never a valid substitute. Examples from the game:

- `move`: moveToPlane, mirror, scale, rotate, moveAwayFrom, rotate3D, rotateAxis, scaleNU, shear, orient, orientDirection, linearArray
- `loft`: sweep1, sweep2, extrude, edgeSurface, networkSurface, boundary, surfaceFromPoints, pipe, revolution, railRevolution, patch, extrudeLinear
- `range`: series, random, duplicateData, sequence, repeatData, fibonacci, jitter, constructDomain, divideDomain, bounds, remapNumbers, stackData

Distractor ids are camelCase Grasshopper names (`Brep Join` → `brepJoin`, `Divide Domain` → `divideDomain`).
They must exist in `web/js/data.js` or `web/js/components_extra.js`. The game silently drops unknown ids, so a
wrong guess shrinks the hand rather than breaking the level. List any ids you weren't sure of in your notes. Write a `wrong` entry for the 2–4 most tempting distractors, plus `"*"`.

### 6.3 Wire checks

A wire with `check` becomes a **wire-check question**: the player picks which port the wire plugs into. Add one
to the wires named in your stage's "Wire check" line:

```json
{ "from": "uzRelay.D", "to": "mv.T",
  "check": { "side": "in",
             "prompt": "Which input of Move takes the up vector?",
             "hint": "G = geometry to move, T = the motion vector.",
             "correct": "T is the motion. Until it was connected Move used its default (10 units up); now the top sits at roof height.",
             "wrong": { "G": "G is the geometry to move: the outline is already plugged in there.", "*": "That input isn't the motion vector." },
             "draft": true } }
```

Until the player answers, the wire counts as disconnected and the preview shows the component's default. Mention
that in `correct`.

### 6.4 Difficulty knobs

| Knob | 01 | 02 | 03 |
| --- | --- | --- | --- |
| `guidance` | guided | guided | guided |
| `hand` (cards per pick) | 3 | 4 | 5 |
| `health` | 5 | 4 | 4 |
| `attacks` (0–3) | 0 | 0 | 1 |

Optionally, `timer` (seconds per decision) on a 4th or 5th difficulty, named Geometry Wizard or Grasshopper Legend.

### 6.5 Text style

- Write for an architecture student who is new to Grasshopper. Use short sentences, units in feet, and no
  jargon without a reason.
- `need` describes the **job**, not the component name ("a vector pointing straight up", not "Unit Z").
- `hint` names the Grasshopper tab › panel, e.g. "Transform › Euclidean".
- `correct` explains **why** it works and what the output looks like now.
- Each `wrong` entry says what that card *would* do instead.

---

## 7. The Grasshopper build sheet (for the team)

The team keeps a matching `.ghx` per difficulty in `GameLevels/Level<X>/<ID>.ghx`, using this canvas convention.
For each difficulty, give them a table of **stage → components → question node → 12 wrong choices**, and say
which stages are given.

| Group | Name | Colour (A, R, G, B) | Contents |
| --- | --- | --- | --- |
| Method | `E01` | 225, 255, 255, 255 (white) | the whole working definition |
| Stage | (no name) | 225, 255, 255, 255 (white) | one stage, plus its note scribble |
| Question | `E01_Q03` | 225, 255, 0, 0 (red) | the one wired question component. **Create red groups last** so they draw on top |
| Correct copy | `E01_Q03_Correct` | 225, 161, 205, 68 (green) | a locked, unwired copy of the question component, placed just above its choices |
| Choices | `E01_Q03_Choices` | 180, 0, 135, 220 (blue) | 12 locked, unwired, **native** components that are wrong for the step, in a 6 × 2 grid |

Stages from earlier levels are pre-placed white groups with a "GIVEN (Level X)" note and no red group. The
repo's converter (`godot/tools/ghx_to_level.py`) turns these canvases into the JSON in section 6.

---

## 8. Check before you hand it over

Go through this list and fix anything that fails:

- [ ] Every node `comp` is in section 5.1. Every `distractors` id is a real Grasshopper component and never the correct one.
- [ ] Every wire's ports exist on those components (section 5.1 letters), and every required input is wired or `set`.
- [ ] `order` lists every `open: true` node, in build order. Each open node's inputs come from nodes placed earlier.
- [ ] Every open node has `question`, `stage`, `need`, `hint`, `correct`, `distractors`, and `draft: true`.
- [ ] Every slider has a `param` that exists in `params`, with sensible min, max, step and value.
- [ ] Rotate angles that come from degree sliders have `"degrees": true`.
- [ ] The final geometry previews: add `"preview": true` to the result if a check node (Area) comes after it.
- [ ] Each level's three difficulties produce the same kind of result, and each later level starts from the previous level's result.
- [ ] `index.json` lists the new level folder.

**Your reply, in this order:**
1. The level plan (sections 2–4) as tables. Then **stop and ask the user to confirm** before writing files.
2. After they confirm: every file as a fenced code block headed with its repo path (`web/levels/05-…/level.json`,
   `…/E01.json`, …) and the `index.json` change.
3. The Grasshopper build sheet (section 7).
4. Open questions: substitutions you made, distractor ids you weren't sure of, anything you couldn't compute.

**How the team tests it:** run `python -m http.server 5173 --directory web` in the repo, then open
<http://localhost:5173/?all>. `?all` unlocks every level. Play each difficulty, drag the sliders, and review the
draft text at `/review.html`.
