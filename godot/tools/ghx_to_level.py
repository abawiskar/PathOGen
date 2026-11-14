"""
Convert Grasshopper .ghx quiz canvases into Godot difficulty files.

    python godot/tools/ghx_to_level.py                        # GameLevels/LevelA -> 01-base-shape
    python godot/tools/ghx_to_level.py GameLevels/LevelA 01-base-shape

Each .ghx follows grasshopper_game_structure.md:
  A##              large white group: the working definition (one method)
  A##_Q##          red group: the wired component that answers question Q## (becomes an open node)
  A##_Q##_Correct  green group: locked copy of that component (only checked)
  A##_Q##_Choices  blue group: 12 wrong components (become that node's distractor cards)

Writes, all Godot-only (the web sync never touches them):
  godot/levels_godot/<stage>/A##.json          one level definition per file
  godot/levels_godot/<stage>/difficulties.json the stage's difficulty list (A01 easiest ... A05 hardest)
  godot/data/components_godot.json             card data for components the web library doesn't have

No Grasshopper needed: .ghx is plain XML.
"""
import json
import re
import sys
from pathlib import Path

import ghx

GODOT = Path(__file__).resolve().parent.parent
REPO = GODOT.parent
SCALE = 1.0    # Grasshopper canvas units -> graph view units
ROW = 13.0       # Chip.ROW in scripts/ui/chip.gd
GAP = 6        # minimum space between chips

DIFFICULTY_NAMES = ["Hopper Hatchling", "Shape Scout", "Pattern Pouncer", "Geometry Wizard", "Grasshopper Legend"]
# Game rules per difficulty, easiest first (the web version's Level 1 difficulty settings).
DIFFICULTY_RULES = [
    {"guidance": "guided", "health": 5, "hand": 3, "attacks": 0,
     "lifesavers": {"hint": 3, "potion": 2, "fifty": 2, "clear": 1, "shield": 2, "second": 2}},
    {"guidance": "guided", "health": 4, "hand": 4, "attacks": 0,
     "lifesavers": {"hint": 3, "potion": 1, "fifty": 1, "clear": 1, "shield": 1, "second": 1}},
    {"guidance": "standard", "health": 4, "hand": 5, "attacks": 1,
     "lifesavers": {"hint": 2, "potion": 1, "fifty": 1, "clear": 1, "shield": 1, "second": 1}},
    {"guidance": "independent", "health": 3, "hand": 6, "attacks": 2,
     "lifesavers": {"hint": 1, "potion": 1, "fifty": 1, "clear": 1, "shield": 0, "second": 1}},
    {"guidance": "independent", "health": 3, "hand": 6, "attacks": 3, "timer": 30,
     "lifesavers": {"hint": 0, "potion": 1, "fifty": 1, "clear": 1, "shield": 0, "second": 0}},
]

# Grasshopper tab / panel for each component (ghx files don't store it).
CATEGORY = {}
for cat, names in {
    "Params / Input": "Number Slider|Boolean Toggle",
    "Params / Geometry": "Point|Curve",
    "Params / Primitive": "Data",
    "Maths / Operators": "Addition|Division|Negative",
    "Maths / Util": "Path Mapper",
    "Sets / List": "List Item|Shift List|Cull Index|Cull Nth|Insert Items|Replace Items|Split List|Partition List|"
                   "Dispatch|Longest List|Shortest List|Cross Reference|Combine Data|Weave|Reverse List|Sort List|"
                   "Random Reduce|Duplicate Data|Repeat Data|Stack Data|Sequence|Jitter",
    "Sets / Sets": "Merge",
    "Sets / Sequence": "Series|Range|Fibonacci|Char Sequence|Random|Series Addition",
    "Sets / Tree": "Flatten Tree|Graft Tree|Flip Matrix|Shift Paths|Simplify Tree|Trim Tree|Unflatten Tree|"
                   "Explode Tree|Tree Branch|Tree Item|Prune Tree|Entwine|Split Tree|Relative Item|Stream Filter|Stream Gate",
    "Vector / Point": "Construct Point|Deconstruct|Point Polar|Point Cylindrical|Point Oriented|Numbers to Points|"
                      "Points to Numbers|Closest Point|Distance|Sort Points|Coordinate Mask",
    "Vector / Vector": "Unit Y|Vector XYZ|Vector 2Pt",
    "Vector / Plane": "XY Plane|Plane 3Pt|Align Plane|Flip Plane|Rotate Plane",
    "Curve / Primitive": "Polygon|Circle|Circle CNR|Circle 3Pt|Circle Fit|Circle TanTan|InCircle|Ellipse|InEllipse|"
                         "Rectangle|Rectangle 2Pt|Rectangle 3Pt|Polygon Edge|Line|Line SDL|Line 2Plane|Line 4Pt|"
                         "Fit Line|Arc|Arc 3Pt|Arc SED|BiArc|Modified Arc|Tangent Arcs|Tangent Lines|"
                         "Tangent Lines (Ex)|Tangent Lines (In)",
    "Curve / Spline": "PolyLine|Interpolate|Interpolate (t)|Kinky Curve|Nurbs Curve|Nurbs Curve PWK|Bezier Span|"
                      "PolyArc|Catenary|Swing Arc",
    "Curve / Division": "Divide Curve|Divide Length|Divide Distance|Divide By Deviation|Shatter|Dash Pattern|"
                        "Curve Frames|Horizontal Frames|Perp Frames|Curve Contour",
    "Curve / Analysis": "End Points|Evaluate Curve|Evaluate Length|Discontinuity|Curve Closest Point|Curvature|"
                        "Curve Domain|Curve Frame|Curve Middle|Closed|Control Points|Control Polygon|Length|"
                        "Segment Lengths|Polygon Center|Deconstruct Arc",
    "Curve / Util": "Fillet|Fillet Distance|Join Curves|Offset Curve|Offset Curve Loose|Offset Polyline|Explode|"
                    "Flip Curve|Extend Curve|Rebuild Curve|Simplify Curve|Smooth Polyline|Reduce|Curve To Polyline|"
                    "Connect Curves|Line + Line|Line + Pt",
    "Intersect / Region": "Trim with Region|Region Union|Region Intersection|Region Difference|Region Slits",
    "Intersect / Physical": "Trim with Brep|Trim with Breps|Split with Brep|Split with Breps",
    "Intersect / Shape": "Split Brep|Trim Solid",
    "Surface / Util": "Copy Trim|Retrim|Fillet Edge",
    "Transform / Euclidean": "Move|Rotate|Rotate 3D|Rotate Axis|Orient|Orient Direction|Mirror|Move Away From|"
                             "Move To Plane",
    "Transform / Affine": "Scale|Scale NU|Shear|Shear Angle",
    "Transform / Array": "Linear Array|Polar Array",
}.items():
    for n in names.split("|"):
        CATEGORY[n] = cat

# Floating parameters map onto the game's parameter components.
PARAM_IDS = {"Number Slider": "slider", "Boolean Toggle": "toggle", "Point": "pointParam", "Curve": "curveParam",
             "Data": "dataParam"}
# Icon to borrow (from the web icon set) when a component has none of its own.
ICON_FOR_CAT = {"Params": "pointParam", "Maths": "addition", "Sets": "listItem", "Vector": "constructPoint",
                "Curve": "polygon", "Intersect": "contour", "Surface": "loft", "Transform": "move"}
ICON_FOR = {"Circle CNR": "circle", "Circle 3Pt": "circle", "InCircle": "circle", "Line 2Plane": "line",
            "Line 4Pt": "line", "Fit Line": "line", "Rectangle 2Pt": "rectangle", "Rectangle 3Pt": "rectangle",
            "Unit Y": "unitX", "Vector XYZ": "vector2pt", "Division": "multiplication", "Negative": "multiplication",
            "Merge": "flipMatrix", "Graft Tree": "graft", "Divide Length": "divideLength", "Divide Distance": "divideLength",
            "Divide By Deviation": "divideCurve", "Evaluate Curve": "divideCurve", "Evaluate Length": "divideLength",
            "Fillet": "offset", "Fillet Distance": "offset", "Join Curves": "shatter", "Explode": "shatter",
            "PolyLine": "interpolate", "Kinky Curve": "interpolate", "Nurbs Curve": "interpolate",
            "Interpolate (t)": "interpolate", "Rotate 3D": "rotate", "Rotate Axis": "rotate", "Rotate Plane": "rotate",
            "Scale NU": "scale", "Plane 3Pt": "xyPlane", "Align Plane": "xyPlane", "Flip Plane": "xyPlane",
            "Polar Array": "rotate", "Linear Array": "move", "Move Away From": "move", "Move To Plane": "move",
            "Cull Index": "cullPattern", "Cull Nth": "cullPattern", "Random Reduce": "cullPattern",
            "Sequence": "series", "Fibonacci": "series", "Series Addition": "series", "Random": "range",
            "Char Sequence": "series", "Shift Paths": "flipMatrix", "Simplify Tree": "flatten",
            "Unflatten Tree": "graft", "Explode Tree": "flatten", "Trim Tree": "flatten"}


def camel(name):
    words = re.findall(r"[A-Za-z0-9]+", name)
    return words[0].lower() + "".join(w[:1].upper() + w[1:] for w in words[1:]) if words else "comp"


def port(p):
    return [p["nick"], p["name"], (p["desc"] or p["name"]).rstrip(".")]


class Library:
    """The web component library plus Godot-only additions, keyed by game id."""

    def __init__(self):
        web = json.loads((GODOT / "data" / "components.json").read_text(encoding="utf-8"))
        self.web = web["components"]
        self.icons = web["icons"]
        self.extra = {}
        self.extra_icons = {}
        self.by_name = {v["name"]: k for k, v in self.web.items()}

    def comp(self, cid):
        return self.extra.get(cid) or self.web.get(cid)

    def id_for(self, c, wired):
        """Game id for a ghx component. Wired components need matching port nicks; cards only need a name."""
        name = c["type"]
        ins, outs = [p["nick"] for p in c["ins"]], [p["nick"] for p in c["outs"]]
        if name in PARAM_IDS:
            pid = PARAM_IDS[name]
            if pid == "dataParam" and pid not in self.web:
                self._add(pid, c, ins=[["D", "Data", "any data"]], outs=[["D", "Data", "the stored data"]])
            return pid
        k = self.by_name.get(name)
        if k:
            same = [p[0] for p in self.web[k]["ins"]] == ins and [p[0] for p in self.web[k]["outs"]] == outs
            if same or not wired:
                return k
        cid = camel(name)
        if cid in self.web or (cid in self.extra and [p[0] for p in self.extra[cid]["ins"]] != ins):
            cid = camel(name + " " + "".join(ins))
        if cid not in self.extra:
            self._add(cid, c)
        return cid

    def _add(self, cid, c, ins=None, outs=None):
        name = c["type"]
        cat = CATEGORY.get(name, "Grasshopper / Other")
        if name not in CATEGORY:
            print(f"  note: no category for {name!r}, add it to CATEGORY")
        self.extra[cid] = {
            "name": name, "cat": cat, "tier": 2,
            "ins": ins if ins is not None else [port(p) for p in c["ins"]],
            "outs": outs if outs is not None else [port(p) for p in c["outs"]],
            "desc": (c["desc"] or name).rstrip(".") + ".",
        }
        icon = ICON_FOR.get(name) or ICON_FOR_CAT.get(cat.split(" /")[0], "polygon")
        self.extra_icons[cid] = icon


def convert(path, lib):
    doc = ghx.read(path)
    C = doc["comps"]
    named = {g["name"]: g for g in doc["groups"] if g["name"]}
    method = next(n for n in named if re.fullmatch(r"A\d\d", n))
    members = set(ghx.group_members(doc, named[method]))
    links = [w for w in ghx.wires(doc) if w[0] in members and w[2] in members]

    questions = sorted(n for n in named if re.fullmatch(method + r"_Q\d\d", n))
    answer_of = {}
    problems = []
    for q in questions:
        red = [i for i in ghx.group_members(doc, named[q]) if i in members]
        if len(red) != 1:
            problems.append(f"{q}: red group should hold exactly one working component, has {len(red)}")
            continue
        answer_of[red[0]] = q
        green = ghx.group_members(doc, named.get(q + "_Correct", {"ids": []}))
        if not green:
            problems.append(f"{q}: no {q}_Correct group")
        elif C[green[0]]["type"] != C[red[0]]["type"]:
            problems.append(f"{q}: green copy is {C[green[0]]['type']}, red answer is {C[red[0]]['type']}")
        n_choices = len(ghx.group_members(doc, named.get(q + "_Choices", {"ids": []})))
        if n_choices != 12:
            problems.append(f"{q}_Choices has {n_choices} components (guide: 12)")

    # node ids: short, readable, unique
    ids, used = {}, set()
    for i in sorted(members, key=lambda i: (C[i]["pivot"] or (0, 0))[0]):
        base = camel(C[i]["type"] if C[i]["type"] != "Number Slider" else "slider")[:10]
        n, k = base, 2
        while n in used:
            n, k = f"{base}{k}", k + 1
        used.add(n)
        ids[i] = n

    xs = [C[i]["pivot"][0] for i in members if C[i]["pivot"]]
    ys = [C[i]["pivot"][1] for i in members if C[i]["pivot"]]
    x0, y0 = min(xs), min(ys)

    params, nodes = [], []
    for i in sorted(members, key=lambda i: ids[i]):
        c = C[i]
        cid = lib.id_for(c, wired=True)
        px, py = c["pivot"] or (x0, y0)
        node = {"id": ids[i], "comp": cid, "open": i in answer_of, "x": round((px - x0) * SCALE), "y": round((py - y0) * SCALE)}
        if c.get("slider"):
            s = c["slider"]
            targets = [C[b]["ins"][k]["name"] for a, _, b, k in links if a == i and C[b]["ins"]]
            label = c["nick"] or (targets[0] if targets else "Value")
            key = f"s{len(params) + 1}"
            step = 1 if s["interval"] in (1, 2, 3) else round(10 ** -max(1, min(s["digits"], 3)), 3)
            params.append({"key": key, "label": label, "min": s["Min"], "max": s["Max"], "step": step, "value": s["Value"]})
            node.update(param=key, label=label)
        if "toggle" in c:
            node["value"] = c["toggle"]
        sets = {}
        for p in c["ins"]:
            if p["persist"] and not any(b == i and C[b]["ins"][k] is p for a, _, b, k in links):
                v = p["persist"][0]
                if isinstance(v, str) and re.fullmatch(r"\{[\d;]+\}", v):
                    continue   # a data path like {0}
                sets[p["nick"]] = v
            if p["degrees"]:
                node["degrees"] = True
        if sets:
            node["set"] = sets
        maps = {p["nick"]: {1: "flatten", 2: "graft"}[p["mapping"]] for p in c["ins"] if p["mapping"] in (1, 2)}
        if maps:
            node["in_map"] = maps
        if c["type"] in ("Point", "Curve", "Data") and c["nick"] not in ("Pt", "Crv", None, c["type"]):
            node["label"] = c["nick"]
        if i in answer_of:
            q = answer_of[i]
            comp = lib.comp(cid)
            choices = ghx.group_members(doc, named.get(q + "_Choices", {"ids": []}))
            distractors = []
            for d in choices:
                did = lib.id_for(C[d], wired=False)
                if did != cid and did not in distractors:
                    distractors.append(did)
            ins = [p[1] for p in comp["ins"]]
            outs = [p[1] for p in comp["outs"]]
            node.update(
                question=q,
                need=("a component that turns " + ", ".join(ins[:-1]) + (" and " if len(ins) > 1 else "") + ins[-1]
                      + " into " + outs[0]) if ins else "a component that outputs " + outs[0],
                hint="Look in %s." % comp["cat"].replace(" / ", " › "),
                correct="%s is the component this method uses here. %s" % (comp["name"], comp["desc"]),
                distractors=distractors, draft=True)
        nodes.append(node)

    _untangle(nodes, lib)

    wires = []
    for a, o, b, k in links:
        ca, cb = C[a], C[b]
        out_nick = ca["outs"][o]["nick"] if ca["outs"] else lib.comp(ids_comp(lib, ca))["outs"][0][0]
        in_nick = cb["ins"][k]["nick"] if cb["ins"] else lib.comp(ids_comp(lib, cb))["ins"][0][0]
        wires.append({"from": f"{ids[a]}.{out_nick}", "to": f"{ids[b]}.{in_nick}"})

    order = [ids[i] for q in questions for i, qq in answer_of.items() if qq == q]
    steps = " → ".join(C[i]["type"] for q in questions for i, qq in answer_of.items() if qq == q)
    level = {"source": f"GameLevels/{Path(path).parent.name}/{Path(path).name}",
             "method": method, "params": params, "nodes": nodes, "wires": wires, "order": order}
    return level, steps, problems


def _size(node, lib):
    """Chip size in the game's graph view (Chip.chip_size), plus room for the label underneath."""
    comp = lib.comp(node["comp"])
    if node["comp"] == "slider":
        return 108, 22 + 6
    rows = max(len(comp["ins"]), len(comp["outs"]), 1)
    return 92, max(rows * ROW + 12, 30) + 16


def _untangle(nodes, lib):
    """Grasshopper's own components are smaller than the game's chips: push overlapping nodes down."""
    placed = []
    for n in sorted(nodes, key=lambda n: (n["y"], n["x"])):
        w, h = _size(n, lib)
        moved = True
        while moved:
            moved = False
            for m, mw, mh in placed:
                if abs(n["x"] - m["x"]) < (w + mw) / 2 + GAP and abs(n["y"] - m["y"]) < (h + mh) / 2 + GAP:
                    n["y"] = m["y"] + (h + mh) / 2 + GAP
                    moved = True
        n["y"] = round(n["y"])
        placed.append((n, w, h))


def ids_comp(lib, c):
    return lib.id_for(c, wired=True)


def main():
    src = Path(sys.argv[1]) if len(sys.argv) > 1 else REPO / "GameLevels" / "LevelA"
    stage = sys.argv[2] if len(sys.argv) > 2 else "01-base-shape"
    files = sorted(src.glob("*.ghx"))
    if not files:
        sys.exit(f"no .ghx files in {src}")
    lib = Library()
    out = GODOT / "levels_godot" / stage
    out.mkdir(parents=True, exist_ok=True)
    diffs = []
    for i, f in enumerate(files):
        level, steps, problems = convert(f, lib)
        name = f.stem + ".json"
        (out / name).write_text(json.dumps(level, indent=1, ensure_ascii=False), encoding="utf-8")
        rules = DIFFICULTY_RULES[min(i, len(DIFFICULTY_RULES) - 1)]
        diffs.append({"id": f.stem, "name": DIFFICULTY_NAMES[i] if i < len(DIFFICULTY_NAMES) else f.stem,
                      "description": f"Method {f.stem}: {steps}.", "file": name, **rules})
        print(f"{f.name}: {len(level['nodes'])} nodes, {len(level['wires'])} wires, questions: {steps}")
        for p in problems:
            print("  check:", p)
    (out / "difficulties.json").write_text(json.dumps({
        "_note": "Generated by tools/ghx_to_level.py from " + src.name + ". Replaces this level's difficulty list in Godot only.",
        "difficulties": diffs}, indent=1, ensure_ascii=False), encoding="utf-8")
    comp_file = GODOT / "data" / "components_godot.json"
    (comp_file).write_text(json.dumps({
        "_note": "Generated by tools/ghx_to_level.py: components the web library doesn't have. Merged over components.json.",
        "components": dict(sorted(lib.extra.items())), "icon_alias": dict(sorted(lib.extra_icons.items()))},
        indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"{len(lib.extra)} new components -> {comp_file.relative_to(REPO) if REPO in comp_file.parents else comp_file}")
    print(f"levels -> {out}")


if __name__ == "__main__":
    main()
