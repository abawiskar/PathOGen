<div align="center">

# PathOGen

**Build the Script. Survive the Monster. Master Grasshopper.**

A browser game that teaches [Grasshopper](https://www.grasshopper3d.com/) by playing it.
Made at the **AECTech Hackathon 2026**.

<img src="docs/screenshots/title.jpg" alt="PathOGen title screen" width="820">

</div>

---

## What is PathOGen?

Every level in PathOGen is a real Grasshopper definition, and a monster guards it. You fill in the definition one card at a time: pick the right **component card** for each empty node, then answer **wire checks** about which input or output a wire connects to. Finish the definition before the monster wears down your health.

Each correct card adds a real component to a working definition, and a **live 3D preview** shows the geometry your script builds. Drag the definition's sliders and the whole thing re-runs. A wrong card lets the monster attack, which can blur your view, hide component names or lock a slot. Every move, right or wrong, comes with an explanation of what the component does.

<img src="docs/screenshots/battle.jpg" alt="A battle: the definition canvas, live 3D preview, health, monster and your hand of component cards" width="100%">

## Features

- **Real Grasshopper definitions.** Each level is transcribed from the team's own `.ghx` files and solved in the browser by a small Grasshopper-style engine. The engine handles data trees, longest-list matching and about 55 component solvers.
- **282 components** with their real inputs, outputs and Grasshopper icons.
- **Live 3D preview** with Perspective, Top and Front views, adjustable sliders and a goal image of the finished result.
- **Monsters and attacks.** Each level has its own monster, and its attacks get stronger along the path: blur, the Icon Curse (component names go missing), locked slots and timers.
- **Six lifesavers:** Hint, Health Potion, 50/50, Clear Vision, Shield and Second Chance.
- **Choose your guide.** The Spaghetti Hero, or any member of the team, stands beside you in every battle and reacts with animations when you attack, take damage, use a card or get defeated.
- **XP, stars and ranks**, saved in the browser. **Free Play** unlocks every level and difficulty at once.
- **Completed definition view.** See the finished graph and its output at any time.

<table>
  <tr>
    <td><img src="docs/screenshots/map.jpg" alt="The campaign map"></td>
    <td><img src="docs/screenshots/guides.jpg" alt="Choosing a guide"></td>
  </tr>
  <tr>
    <td align="center"><sub>The Path: four encounters, each teaching a Grasshopper skill</sub></td>
    <td align="center"><sub>Pick the Spaghetti Hero or one of the team as your guide</sub></td>
  </tr>
</table>

## The Path

The four levels build one twisted tower, from a floor plate up to a detailed facade.

| # | Level | You learn | Monster | Difficulties |
|---|---|---|---|---|
| 1 | **Build the Base Shape** | Sliders, points and planes: how numbers become a located, adjustable shape | The Spaghetti Boss | 5 |
| 2 | **Build the Mass** | Vectors and transforms (Move, Rotate), then Loft and Cap Holes to make a solid | The Twisted Tower | 3 |
| 3 | **Panels & Floors** | Slicing the mass into floors and giving every floor a solid slab | The Voronoi Golem | 3 |
| 4 | **Data Trees & Details** | Running mullions up the tower and cutting its skin into panels | The Branch Tree | 3 |

There are five difficulties, from *Hopper Hatchling* through *Shape Scout*, *Pattern Pouncer* and *Geometry Wizard* to *Grasshopper Legend*. Each one is a different way of building the same result, with fewer hints, bigger hands of cards and tougher monsters as you go up.

## Tech stack

PathOGen runs on its own geometry engine, so **you don't need Rhino or a Rhino.Compute server to play**.

```mermaid
flowchart LR
    A["<b>Level authoring</b><br/>Grasshopper .ghx<br/>Python conversion tools<br/>JSON level data"]
    B["<b>Custom geometry engine</b><br/>Simplified Grasshopper-style solver<br/>Components and data trees<br/>Live 3D wireframe previews<br/><i>JavaScript / GDScript</i>"]
    C["<b>Game clients</b><br/>Web: HTML / CSS / JavaScript<br/>with SVG and HTML Canvas<br/>Desktop: Godot 4 + GDScript"]
    A --> B --> C
```

| Layer | Built with | What it does |
|---|---|---|
| **Level authoring** | Grasshopper `.ghx`, Python conversion tools, JSON | The team builds each level and difficulty as a real Grasshopper definition. Python tools convert it into JSON level data: the component graph that serves as the answer key, the sliders and the card text. |
| **Custom geometry engine** | JavaScript (web), GDScript (desktop) | A simplified Grasshopper-style solver with data trees, longest-list matching and about 55 component solvers. It re-runs the definition after every move and draws a live 3D wireframe preview. |
| **Web client** | HTML, CSS, JavaScript, SVG, HTML Canvas | The browser game, with no framework, build step or dependencies. Its 3D viewport is drawn on a 2D canvas. |
| **Desktop client** | Godot 4, GDScript | The Windows build (`PathOGen.exe`). It reads the same level, component and monster data as the web client. |

Art is painted PNG and WebP images, plus Grasshopper SVG icons for 282 components. Progress is saved locally: in the browser's `localStorage` for the web version, and in a save file for the desktop build.

## Play it locally

### On Windows: run the exe

No install needed:

1. Download the repository (**Code → Download ZIP**, then unzip it) or clone it.
2. Double-click **[`PathOGen.exe`](PathOGen.exe)** in the main folder.

Keep `PathOGen.exe` and `PathOGen.pck` in the same folder, because the `.pck` holds the game's data. The exe isn't code-signed, so Windows SmartScreen may warn you the first time. Click **More info → Run anyway**.

This is the Godot build of the game. It plays the same levels as the browser version and saves your progress on your computer.

> **Not on Windows, or prefer the browser?** You can also play PathOGen through localhost. See [In a browser](#in-a-browser) below.

### In a browser

The browser version is plain HTML, CSS and JavaScript in [`web/`](web/), with no build step and no dependencies. It loads its levels with `fetch()`, so you need to serve the folder over http rather than open the file directly:

```bash
python -m http.server 5173 --directory web
```

Then open <http://localhost:5173>. These URL options are useful for testing:

| URL option | What it does |
|---|---|
| `?all` | Unlocks every level |
| `?inspect` | Testing bar: jump to any level and difficulty and step through its definition stage by stage |
| `?monster=tower` | Shows one monster on every level (`spaghetti`, `tower`, `voronoi` or `tree`) |

**Keyboard:** `1`–`6` select a card, `Enter` places it, `H` uses a hint.

## Repository layout

| Path | What it holds |
|---|---|
| [`PathOGen.exe`](PathOGen.exe) + [`PathOGen.pck`](PathOGen.pck) | The Windows build of the game: double-click the exe to play |
| [`web/`](web/) | The browser version of the game. See [`web/README.md`](web/README.md) for the code structure |
| [`web/levels/`](web/levels/) | One folder per level: `level.json` holds the component graph (the answer key), sliders and card text, plus one JSON file per difficulty |
| [`GameLevels/`](GameLevels/) | The team's Grasshopper files for each level and difficulty (`LevelA/A01.ghx` … `LevelD/D03.ghx`) |
| [`GH definitions/`](GH%20definitions/) | The original Grasshopper definitions the path is based on |
| [`Images/`](Images/) | Source art: monsters, the Spaghetti Hero, team avatars and their animation frames |
| [`godot/`](godot/) | The Godot 4 project behind the Windows build. It plays the same levels from the same data |
| [`VideoDemo/`](VideoDemo/) | Demo videos of the game |
| [`PathOGen-Game-Overview.md`](PathOGen-Game-Overview.md) | Full game design: screens, turns, attacks, lifesavers, scoring, levels |
| [`PathOGen_Level_Builder.md`](PathOGen_Level_Builder.md) | How to turn a Grasshopper definition into a level |

## Adding a level

1. Build the definition in Grasshopper and save it as `.ghx` in `GameLevels/`.
2. Convert it to a level folder in `web/levels/` (see [`PathOGen_Level_Builder.md`](PathOGen_Level_Builder.md) and [`web/levels/README.md`](web/levels/README.md)).
3. Mark the nodes the player has to fill with `"open": true` and write their hints and explanations.
4. Add the folder to `web/levels/index.json`.
5. Check it with `?inspect`, and open `web/review.html` to see any hint text still marked as draft.

## The team

<table>
  <tr>
    <td align="center" width="14%"><img src="web/img/avatars/abhishek.png" width="80" alt=""><br><b>Abhishek Bawiskar</b><br><sub>Senior Associate Application Developer, Thornton Tomasetti</sub></td>
    <td align="center" width="14%"><img src="web/img/avatars/garrett.png" width="80" alt=""><br><b>Garrett Herbst</b><br><sub>Director of Emerging Technologies, Little</sub></td>
    <td align="center" width="14%"><img src="web/img/avatars/joel.png" width="80" alt=""><br><b>Joel Hills</b><br><sub>Senior Digital Design Technologist, Thornton Tomasetti</sub></td>
    <td align="center" width="14%"><img src="web/img/avatars/riku.png" width="80" alt=""><br><b>Riku Kanemitsu</b><br><sub>Graduate Student, Waseda University &amp; ADL Intern</sub></td>
    <td align="center" width="14%"><img src="web/img/avatars/danny.png" width="80" alt=""><br><b>Danny Karas</b><br><sub>Associate Computational Designer, Thornton Tomasetti</sub></td>
    <td align="center" width="14%"><img src="web/img/avatars/maya.png" width="80" alt=""><br><b>Maya Mashiach</b><br><sub>Design Technology Specialist, LPA Design Studios</sub></td>
    <td align="center" width="14%"><img src="web/img/avatars/kazu.png" width="80" alt=""><br><b>Kazu Tajima</b><br><sub>Graduate Student, Waseda University &amp; ADL Intern</sub></td>
  </tr>
</table>

## Credits

- Grasshopper component icons by David Rutten / Robert McNeel &amp; Associates, via [aidannewsome/grasshopper-icons](https://github.com/aidannewsome/grasshopper-icons).
- Fonts: [Cinzel](https://fonts.google.com/specimen/Cinzel) and [Barlow](https://fonts.google.com/specimen/Barlow) (SIL Open Font License).
- Grasshopper and Rhino are products of Robert McNeel &amp; Associates. PathOGen is an independent hackathon project and is not affiliated with McNeel.

## License

[MIT](LICENSE)
