#!/usr/bin/env python3
"""Sync PathOGen game data from the web version into the Godot project.

Run from anywhere after pulling web changes:

    python godot/tools/sync_from_web.py

What it does:
  web/levels/**            -> godot/levels/**            (copied as-is)
  web/js/data.js           -> godot/data/components.json  (COMPONENTS, ICONS, FILLER)
  web/js/monsters.js       -> godot/data/monsters.json    (MONSTER_OPTIONS, MONSTER_PHASES)
  web/img/*.png            -> godot/img/                  (monster art, hero sprite frames)

The JS files are plain object literals, so they are converted with a small
tokenizer (no Node.js needed). If the web team changes those files into
something that is not a plain literal, this script stops with an error
instead of writing bad data.
"""
import json
import re
import shutil
import sys
from pathlib import Path

GODOT = Path(__file__).resolve().parent.parent
REPO = GODOT.parent
WEB = REPO / "web"


# ---------------------------------------------------------------- JS literal -> Python
def tokenize(src: str):
    i, n = 0, len(src)
    while i < n:
        c = src[i]
        if c.isspace():
            i += 1
        elif src.startswith("//", i):
            i = src.find("\n", i)
            i = n if i < 0 else i
        elif src.startswith("/*", i):
            i = src.index("*/", i) + 2
        elif c in "'\"`":
            j, buf = i + 1, []
            while src[j] != c:
                if src[j] == "\\":
                    nxt = src[j + 1]
                    buf.append({"n": "\n", "t": "\t", "r": "\r"}.get(nxt, nxt))
                    j += 2
                else:
                    if c == "`" and src.startswith("${", j):
                        raise ValueError("template literal with ${...} is not a plain value")
                    buf.append(src[j])
                    j += 1
            yield ("str", "".join(buf))
            i = j + 1
        elif c.isdigit() or (c in "-." and i + 1 < n and (src[i + 1].isdigit() or src[i + 1] == ".")):
            m = re.match(r"-?(\d+\.?\d*|\.\d+)([eE][-+]?\d+)?", src[i:])
            yield ("num", float(m.group(0)) if any(ch in m.group(0) for ch in ".eE") else int(m.group(0)))
            i += len(m.group(0))
        elif c.isalpha() or c in "_$":
            m = re.match(r"[A-Za-z_$][\w$]*", src[i:])
            yield ("id", m.group(0))
            i += len(m.group(0))
        else:
            yield ("p", c)
            i += 1


class Parser:
    def __init__(self, toks):
        self.t = list(toks)
        self.i = 0

    def peek(self):
        return self.t[self.i] if self.i < len(self.t) else (None, None)

    def take(self, kind=None, val=None):
        tok = self.peek()
        if (kind and tok[0] != kind) or (val is not None and tok[1] != val):
            raise ValueError(f"expected {kind} {val!r}, got {tok!r}")
        self.i += 1
        return tok

    def value(self):
        k, v = self.peek()
        if k == "p" and v == "{":
            return self.obj()
        if k == "p" and v == "[":
            return self.arr()
        if k in ("str", "num"):
            self.i += 1
            return v
        if k == "p" and v == "-":
            self.i += 1
            return -self.take("num")[1]
        if k == "id" and v in ("true", "false", "null"):
            self.i += 1
            return {"true": True, "false": False, "null": None}[v]
        raise ValueError(f"unsupported value at token {self.peek()!r}")

    def obj(self):
        self.take("p", "{")
        out = {}
        while self.peek() != ("p", "}"):
            k, v = self.take()
            if k not in ("id", "str", "num"):
                raise ValueError(f"bad key {v!r}")
            self.take("p", ":")
            out[str(v)] = self.value()
            if self.peek() == ("p", ","):
                self.i += 1
        self.take("p", "}")
        return out

    def arr(self):
        self.take("p", "[")
        out = []
        while self.peek() != ("p", "]"):
            out.append(self.value())
            if self.peek() == ("p", ","):
                self.i += 1
        self.take("p", "]")
        return out


def read_const(src: str, name: str):
    m = re.search(r"\bconst\s+" + re.escape(name) + r"\s*=\s*", src)
    if not m:
        raise ValueError(f"const {name} not found")
    p = Parser(tokenize(src[m.end():]))
    return p.value()


# ---------------------------------------------------------------- main
def main():
    if not WEB.is_dir():
        sys.exit(f"web folder not found at {WEB}")
    data_js = (WEB / "js" / "data.js").read_text(encoding="utf-8")
    monsters_js = (WEB / "js" / "monsters.js").read_text(encoding="utf-8")

    comps = read_const(data_js, "COMPONENTS")
    icons = read_const(data_js, "ICONS")
    filler = read_const(data_js, "FILLER")
    monsters = {"options": read_const(monsters_js, "MONSTER_OPTIONS"),
                "phases": read_const(monsters_js, "MONSTER_PHASES")}

    for cid, c in comps.items():
        for key in ("name", "cat", "ins", "outs", "desc"):
            if key not in c:
                raise ValueError(f"component {cid} has no {key}")

    out_dir = GODOT / "data"
    out_dir.mkdir(exist_ok=True)
    (out_dir / "components.json").write_text(
        json.dumps({"components": comps, "icons": icons, "filler": filler}, indent=1, ensure_ascii=False),
        encoding="utf-8")
    (out_dir / "monsters.json").write_text(json.dumps(monsters, indent=1, ensure_ascii=False), encoding="utf-8")

    # web images: copied as-is, marked "keep" so Godot ships the PNG files unchanged
    img_src, img_dst = WEB / "img", GODOT / "img"
    n_img = 0
    if img_src.is_dir():
        if img_dst.exists():
            shutil.rmtree(img_dst)
        img_dst.mkdir()
        for f in sorted(img_src.iterdir()):
            if f.is_file():
                shutil.copy2(f, img_dst / f.name)
                (img_dst / (f.name + ".import")).write_text('[remap]\n\nimporter="keep"\n', encoding="utf-8")
                n_img += 1

    src, dst = WEB / "levels", GODOT / "levels"
    if dst.exists():
        shutil.rmtree(dst)
    shutil.copytree(src, dst)
    n_levels = len(json.loads((dst / "index.json").read_text(encoding="utf-8"))["levels"])

    for d in dst.iterdir():   # level folders may hold a goal image: keep it as a raw file too
        for f in d.glob("*.png") if d.is_dir() else []:
            (d / (f.name + ".import")).write_text('[remap]\n\nimporter="keep"\n', encoding="utf-8")
    print(f"components: {len(comps)}  icons: {len(icons)}  monsters: {len(monsters['options'])}  "
          f"phases: {len(monsters['phases'])}  images: {n_img}  levels: {n_levels}")
    print(f"written to {out_dir} and {dst}")


if __name__ == "__main__":
    main()
