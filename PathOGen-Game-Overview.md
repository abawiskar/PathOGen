# PathOGen — Game Overview

**Build the Script. Survive the Monster. Master Grasshopper.**

PathOGen is a browser game that teaches Grasshopper 3D. Each level is a real Grasshopper definition guarded by a monster.
Players pick the right component cards, wire them correctly, and complete the definition before the monster defeats them.
A live 3D preview shows the geometry growing with every correct move.

*Status as of 14 Nov 2026: playable prototype. All four levels are built from the team's `.ghx` files
(`GameLevels/LevelA`–`LevelD`): five difficulties for level 1 and three each for levels 2–4.*

---

## 1. Running the game

The game is plain HTML/CSS/JavaScript in `web/` — no build step, no install. It must be served over http
(levels are loaded with `fetch`), not opened as a file:

```bash
python -m http.server 5173 --directory web
```

Then open <http://localhost:5173>.

| URL option | Effect |
| --- | --- |
| `?all` | Unlocks every level (for testing) |
| `?inspect` | Testing inspector: a bar to jump to any level and difficulty and step through its definition stage by stage (auto-placing the right answers), with the live preview and sliders. Nothing is saved |
| `?monster=tower` (or `spaghetti`, `tree`, `voronoi`) | Shows one monster on every level |

Other pages: `web/review.html` lists every hint and explanation still marked as draft, for the team to review.

---

## 2. The screen

| Area | What it shows |
| --- | --- |
| **Completed definition** (button, top right of the definition panel) | Opens the finished graph — every node placed and wired, the ones you place framed in gold — next to its output. |
| **Build your definition** (top left) | A simplified Grasshopper canvas: placed components, wires, and empty nodes still to fill. Empty nodes appear as greyed-out components with a `?`; the one you're filling glows gold. Drag to pan on big graphs. |
| **Preview** (centre) | Live wireframe 3D of the definition so far. Drag to orbit, scroll to zoom, double-click to reset. Perspective / Top / Front views. |
| **Sliders** (preview, top right) | The definition's sliders — drag them and the whole definition re-runs. |
| **Goal** (under the sliders) | Thumbnail of the finished result; click to enlarge. |
| **Your health** (top right) | Hearts, current level and difficulty, XP. Active penalties appear underneath. |
| **Monster** (right) | Monster art, health bar, and its *intent* — the attack it will use on your next mistake. |
| **Featured card + Field notes** (left) | The selected card up close, with a Place button; explanations of every move. |
| **Lifesavers** (left) | Six support cards with remaining counts. |
| **Your hand** (bottom) | The component cards (or port cards during a wire check) to choose from. |
| **Hero** (bottom left) | The guide character; reacts to success, damage and defeat. |
| **Moves / Help** (bottom right) | Moves opens a log of every decision with its explanation; Help explains the rules. |
| **Title screen** | Begin the Hunt, How to Play, About Us, and Exit (asks first; closes the tab where the browser allows it, otherwise shows a goodbye message). |
| **Main Menu / ← Map** (bottom right) | Leave the battle for the title screen or the map; asks first if the level is in progress. The map also has a Main Menu button. |

---

## 3. How a turn works

1. **Pick a card** from your hand — it appears in the featured slot.
2. **Place it**: click Place, the glowing node, or the card again. Keyboard: `1`–`6` select, `Enter` places, `H` uses a hint.
3. **Wire checks**: after some components, the cards turn into *ports* and you choose which input (or output) a wire
   connects to — e.g. the slider goes into Polygon's `S` (segments), not `R` (radius). Until answered, the wire counts as
   unplugged and the preview shows the component's default behaviour.
4. **Read the field notes**: every choice explains why it works or doesn't, what the component expects and what it outputs.

A correct choice advances the definition, damages the monster and awards XP. A wrong choice costs health, removes that
card from your hand, and triggers the monster's attack.

---

## 4. Monster attacks

A wrong pick costs one heart plus the monster's telegraphed intent. Penalties wear off as you place correct components.

| Attack | Effect |
| --- | --- |
| Strike | Lose 1 heart |
| Heavy Strike | Lose 2 hearts |
| Blurred Vision | Card names and the preview blur for 2 correct placements |
| Icon Curse | Card names and descriptions vanish (only icons and ports remain) for 2 correct placements. Cards show an "Icon Curse" label and a banner explains it. |
| Scramble | Your hand is shuffled |
| Locked Component | A placed node hides its label for 3 placements |
| Time Pressure | 15 seconds for the next decision, or take a hit |

**Attack sets escalate** along the path (or per difficulty, see §7):

| Set | Attacks used |
| --- | --- |
| 0 | Strikes only |
| 1 | Strikes, Scramble, Blur |
| 2 | Blur, Icon Curse, Locked Component, Strike |
| 3 | Heavy Strike plus every trick, including Time Pressure |

---

## 5. Lifesavers

| Lifesaver | Effect |
| --- | --- |
| Hint | Reveals a clue about the missing component or port |
| Health Potion | Restores one heart |
| 50/50 | Removes two incorrect cards from your hand |
| Clear Vision | Removes Blur, Icon Curse and Locked Component (pulses when useful) |
| Shield | Blocks the next monster attack completely |
| Second Chance | Undoes your last mistake — health, penalty and card restored (also offered on the defeat screen) |

Every 3 correct picks in a row can award a bonus lifesaver (up to 2 per level).

---

## 6. Scoring and progress

- **+100 XP** per correct component, **+60** per wire check, **+40** for getting it right first time.
- On victory: **efficiency bonus** (decisions ÷ picks × 200), **+50 per heart** remaining, **+500** for a perfect run
  (no mistakes, no lifesavers).
- **Stars**: 3 with no mistakes, 2 with up to two, otherwise 1.
- Progress, stars and best XP are saved **per level and difficulty** in the browser. Beating any difficulty unlocks the
  next level. Total XP sets your rank: Novice → Apprentice → Wirebender → Definition Smith → Parametric Ranger → Script Master.

---

## 7. Levels and difficulties

### The path

| # | Level | Monster | What the player builds | Source |
| --- | --- | --- | --- | --- |
| 1 | **Build the Base Shape** | The Spaghetti Boss | A rounded floor plate outline, five different ways | `GameLevels/LevelA/A01–A05.ghx` |
| 2 | **Build the Mass** | The Twisted Tower | The twisted tower mass: floors stacked, scaled, rotated, lofted and capped | `GameLevels/LevelB/B01–B03.ghx` |
| 3 | **Panels & Floors** | The Voronoi Golem | Floor slabs: the mass sliced level by level, set back and extruded | `GameLevels/LevelC/C01–C03.ghx` |
| 4 | **Data Trees & Details** | The Branch Tree | Facade details: mullions run up the tower and the skin cut into panels | `GameLevels/LevelD/D01–D03.ghx` |

### Difficulties

Each level can offer several difficulties, chosen from the map. Level 1 has five; the others currently have one
("Standard"). Each difficulty can load its **own definition file** (one per Grasshopper file) and adjust the rules:

| Rule | Meaning |
| --- | --- |
| `guidance` | `guided` (open node says what it needs) · `standard` · `independent` (card descriptions hidden) |
| `health`, `lifesavers` | Hearts and lifesaver counts |
| `hand` | Cards in hand per decision |
| `attacks` | Attack set 0–3 |
| `timer` | Seconds per decision |
| `open` | Which nodes the player must place; the rest start on the canvas |

Level 1's difficulties are five **methods** for building the same rounded pentagon floor plate, transcribed from
`GameLevels/LevelA/A01–A05.ghx` by the Godot build's `tools/ghx_to_level.py` (files `web/levels/01-base-shape/A01–A05.json`):

| Difficulty | Method (components you place) | Mode | Hearts | Cards | Attacks | Extra |
| --- | --- | --- | --- | --- | --- | --- |
| A01 Hopper Hatchling | Construct Point → Polygon | Guided | 5 | 3 | 0 | Generous lifesavers |
| A02 Shape Scout | Construct Point → Line SDL → Rotate → End Points → Fillet | Guided | 4 | 4 | 0 | |
| A03 Pattern Pouncer | Construct Point → Move → Series → Rotate → Discontinuity | Standard | 4 | 5 | 1 | |
| A04 Geometry Wizard | Construct Point → Divide Curve → Shift List → PolyLine → Flatten Tree | Independent | 3 | 6 | 2 | Fewer lifesavers |
| A05 Grasshopper Legend | Construct Point → Divide Curve → Trim with Region → Arc SED → Shift List → Merge | Independent | 3 | 6 | 3 | 30-second timer |

Levels 2–4 each have three methods, converted from LevelB–D for the web build (names and rules follow the
Godot converter's defaults for the first three difficulties):

| Difficulty | Level 2 · Mass (LevelB) | Level 3 · Floors (LevelC) | Level 4 · Details (LevelD) | Rules |
| --- | --- | --- | --- | --- |
| Hopper Hatchling | Multiplication → Unit Z → Rotate → Loft → Cap Holes | Contour → Multiplication → Extrude → Cap Holes | Divide Curve → Line → Pipe | Guided, 5 hearts, 3 cards |
| Shape Scout | Range → Multiplication → Addition → Polygon → Rotate → Loft → Cap Holes | Scale → Multiplication → Extrude → Cap Holes → Area | Divide Domain² → Isotrim → Area → Scale → Pipe | Guided, 4 hearts, 4 cards |
| Pattern Pouncer | Range → Graph Mapper → Multiplication → Addition → Polygon → Sine → Rotate → Loft → Cap Holes | Graft Tree → Scale → Multiplication → Extrude → Cap Holes → Area | Divide Domain² → Isotrim → Divide Curve → Flip Matrix → Interpolate → Pipe | Standard, 4 hearts, 5 cards, attack set 1 |

### Learning progression

Early difficulties show descriptions and tell you what each open node needs; later ones hide descriptions, offer more
cards and pre-place less — moving players from **recognition → understanding → application → independent scripting**.

---

## 8. Art

| Asset | Source | In game |
| --- | --- | --- |
| Component icons | David Rutten's original Grasshopper icons, from github.com/aidannewsome/grasshopper-icons (free to use for Grasshopper-related projects) | `web/img/gh-icons/*.svg`, mapped in `web/js/gh_icons.js`; 161 of 202 components, the rest keep a simple line icon |
| Hero | `Images/Hero/Material Seat for the hero_v3 - upscale.png` | Main pose (idle), Success, Damage and Defeat frames, cut to `web/img/hero-*.png` |
| The Spaghetti Boss | `Images/Monster/Spaghetti Boss_v1.png` | `web/img/monster-spaghetti.png` |
| The Twisted Tower | `Images/Monster/Twisted Tower Monster_v3.png` (dark background removed) | `web/img/monster-tower.png` |
| The Branch Tree | `Images/Monster/Tree Branch Monster_v1.png` | `web/img/monster-tree.png` |
| The Voronoi Golem | `Images/Monster/voronoi_v1.png` (same version as the Godot build) | `web/img/monster-voronoi.png` |

Monster names and backstory lines are placeholders and can be edited in `web/js/monsters.js`.

---

## 9. How levels are built (for the team)

- **No Grasshopper at runtime.** Each Grasshopper script is transcribed once into JSON; the game never reads `.gh`/`.ghx` files.
- Each level is a folder `web/levels/<nn-name>/` with a `level.json`; `web/levels/index.json` sets the play order.
- The **node graph is the answer key**: nodes (pre-placed or open), wires (some marked as wire checks), and per-node text —
  `need`, `hint`, `correct`, `wrong` (per wrong card, plus a `*` fallback). Card hands default to same-category distractors.
- Text drafted by Claude is marked `"draft": true` until reviewed; `review.html` lists all drafts.
- The **preview is computed live** by a small Grasshopper-style solver (`web/js/engine.js`): data trees, longest-list
  matching, and about 50 components (Point, Polygon with fillet, Divide Curve, Series, Move, Rotate, Scale, Loft,
  Cap Holes, Contour, Isotrim, Graft, Flatten, Flip Matrix, Pipe…). Anything too complex can use baked geometry.
- Each level shows a **goal image**: rendered automatically from the finished definition, or a custom image (`"goal": "goal.png"`).
- Full format reference: `web/levels/README.md`.

### Project files

| Path | Purpose |
| --- | --- |
| `web/index.html`, `web/css/style.css` | Page and styling (fixed 1600×900 stage, scaled to fit) |
| `web/js/game.js` | Game engine: turns, attacks, lifesavers, scoring, difficulties, saves, rendering |
| `web/js/engine.js` | Grasshopper-style solver and preview builder |
| `web/js/loader.js` | Loads and validates levels and difficulties |
| `web/js/data.js` | Component library (inputs, outputs, descriptions, icons) |
| `web/js/components_extra.js` | ~150 more components generated from the Godot build's library, for `.ghx` levels |
| `web/js/monsters.js` | Monsters and attack sets |
| `web/js/preview.js` | Wireframe 3D viewport and goal snapshots |
| `web/js/art.js` | Lifesaver icons, hearts, placeholder SVG monster |
| `web/levels/` | Level data, format README |
| `web/img/` | Web-sized hero and monster art |
| `web/review.html` | Draft text review page |

---

## 10. Team

Made at the AECTech Hackathon 2026. On the About Us page, clicking a name shows that person's title and workplace;
the names also appear on the end-of-game screen. Edit them in `TEAM` in `web/js/game.js`.

| Name | Title | Organisation |
| --- | --- | --- |
| Abhishek Bawiskar | Senior Associate Application Developer | Thornton Tomasetti |
| Garrett Herbst | Director of Emerging Technologies | Little |
| Joel Hills | Senior Digital Design Technologist | Thornton Tomasetti |
| Riku Kanemitsu | Graduate Student | Waseda University & ADL Intern |
| Danny Karas | Associate Computational Designer | Thornton Tomasetti |
| Maya Mashiach | Design Technology Specialist | LPA Design Studios |
| Kazu Tajima | Graduate Student | Waseda University & ADL Intern |

## 11. Open items

- **Hero wire-attack animation:** needs evenly spaced frames on the sheet.
- **Text review:** all hints and explanations are drafts written by Claude.
- **Monster names and lines:** placeholders.
