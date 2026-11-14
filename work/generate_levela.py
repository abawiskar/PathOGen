from __future__ import annotations

import csv
import math
from collections import defaultdict
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "Images" / "GameLevel" / "answer_maps"
TARGET = ROOT / "Images" / "GameLevel" / "LevelA"
LAYOUT = ROOT / "work" / "levela_layout.tsv"
TARGET.mkdir(parents=True, exist_ok=True)

WIDTH, HEIGHT = 1536, 1024
BG = (29, 49, 45)
INK = (30, 47, 43)
CREAM = (241, 240, 231)
WIRE = (208, 222, 208)
GOLD = (231, 211, 159)
MUTED = (148, 174, 164)

CAPTIONS = {
    "A01_Q01": "SET A REFERENCE FOR THE SHAPE TO GROW FROM",
    "A01_Q02": "TURN THE SIZE AND CORNER SETTINGS INTO A CLOSED OUTLINE",
    "A02_Q01": "ESTABLISH THE START OF THE DIRECTED PATH",
    "A02_Q02": "CARRY THE START, DIRECTION, AND LENGTH INTO THE FIRST PATH",
    "A02_Q03": "ARRANGE THE BASE PATH USING A SEQUENCE OF ANGLES",
    "A02_Q04": "FIND THE LOCATIONS NEEDED TO CONNECT THE REPEATED CURVES",
    "A02_Q05": "SOFTEN THE SHARP TRANSITIONS OF THE FINISHED OUTLINE",
    "A03_Q01": "SET THE SPATIAL SEED FOR A REPEATED LAYOUT",
    "A03_Q02": "PLACE A COPY OF THE SEED AT A CONTROLLED OFFSET",
    "A03_Q03": "SPACE THE VALUES THAT WILL DRIVE THE REPEATED LAYOUT",
    "A03_Q04": "ARRANGE THE GEOMETRY AROUND ITS SHARED REFERENCE",
    "A03_Q05": "FIND THE CURVE LOCATIONS THAT NEED FINISHING",
    "A04_Q01": "SET THE REFERENCE FOR THE CIRCULAR GUIDE",
    "A04_Q02": "MARK REGULAR LOCATIONS AROUND THE GUIDE",
    "A04_Q03": "REORDER THE LOCATIONS FOR A NEW PAIRING",
    "A04_Q04": "CONNECT THE PREPARED LOCATIONS INTO AN OUTLINE",
    "A04_Q05": "PREPARE THE GROUPED OUTLINE FOR FINAL REFINEMENT",
    "A05_Q01": "ESTABLISH THE CENTER OF THE GUIDE GEOMETRY",
    "A05_Q02": "LOCATE REGULAR POSITIONS ALONG THE GUIDE",
    "A05_Q03": "KEEP THE PATH SECTIONS THAT FIT THE BOUNDARY",
    "A05_Q04": "CONNECT THE SELECTED LOCATIONS WITH A CURVED SPAN",
    "A05_Q05": "PAIR NEIGHBORING LOCATIONS FOR THE NEXT CONNECTIONS",
    "A05_Q06": "BRING THE PREPARED CURVE SETS TOGETHER FOR FINISHING",
}

TITLES = {
    "A01_Q01": "Anchor the Floor Plate",
    "A01_Q02": "Form the Rounded Outline",
    "A02_Q01": "Start the Radial Path",
    "A02_Q02": "Trace the First Edge",
    "A02_Q03": "Arrange the Repeated Edges",
    "A02_Q04": "Find Connection Locations",
    "A02_Q05": "Refine the Corners",
    "A03_Q01": "Anchor the Pattern",
    "A03_Q02": "Place the Offset Seed",
    "A03_Q03": "Set the Pattern Rhythm",
    "A03_Q04": "Fan Out the Geometry",
    "A03_Q05": "Locate Finishing Spots",
    "A04_Q01": "Center the Guide",
    "A04_Q02": "Lay Out Guide Positions",
    "A04_Q03": "Pair Neighboring Positions",
    "A04_Q04": "Trace the Connected Outline",
    "A04_Q05": "Prepare the Outline for Finishing",
    "A05_Q01": "Anchor the Final Path",
    "A05_Q02": "Space the Guide Positions",
    "A05_Q03": "Select the Interior Path",
    "A05_Q04": "Bridge the Selected Ends",
    "A05_Q05": "Pair the Curved Pieces",
    "A05_Q06": "Assemble the Final Curves",
}


def font(name: str, size: int) -> ImageFont.FreeTypeFont:
    return ImageFont.truetype(str(Path(r"C:\Windows\Fonts") / name), size)


TITLE_FONT = font("georgiab.ttf", 60)
SUB_FONT = font("segoeuib.ttf", 26)
QUESTION_FONT = font("georgiab.ttf", 82)
LABEL_FONT = font("segoeuib.ttf", 25)
FOOTER_FONT = font("segoeui.ttf", 27)


def parse_layout() -> tuple[dict[str, dict], dict[str, list[dict]], dict[str, list[dict]]]:
    questions: dict[str, dict] = {}
    nodes: dict[str, list[dict]] = defaultdict(list)
    wires: dict[str, list[dict]] = defaultdict(list)
    with LAYOUT.open(encoding="utf-8") as handle:
        for row in csv.reader(handle, delimiter="\t"):
            if row[0] == "Q":
                questions[row[1]] = {
                    "stage": tuple(map(float, row[2:6])),
                    "group": tuple(map(float, row[6:10])),
                    "answer": tuple(map(float, row[10:14])),
                    "inputs": int(row[14]),
                    "outputs": int(row[15]),
                }
            elif row[0] == "N":
                if row[4] != "GH_Group":
                    nodes[row[1]].append({"name": row[3], "type": row[4], "bounds": tuple(map(float, row[5:9]))})
            elif row[0] == "W":
                wires[row[1]].append({"side": row[2], "index": int(row[3]), "pivot": tuple(map(float, row[4:6]))})
    return questions, nodes, wires


def relative_box(bounds: tuple[float, float, float, float], stage: tuple[float, float, float, float]):
    x, y, w, h = bounds
    sx, sy, _, _ = stage
    return (round((x - sx) * 2 + 18), round((y - sy) * 2 + 50), round(w * 2), round(h * 2))


def clipped_box(box, shape):
    x, y, w, h = box
    return (max(0, x), max(0, y), min(shape[1], x + w), min(shape[0], y + h))


def theme_source(source: Image.Image, question: dict, stage_nodes: list[dict]) -> tuple[Image.Image, Image.Image]:
    raw = np.asarray(source.convert("RGB"), dtype=np.float32)
    height, width, _ = raw.shape
    lum = raw.mean(axis=2)
    node_mask = np.zeros((height, width), dtype=bool)

    for node in stage_nodes:
        x, y, w, h = relative_box(node["bounds"], question["stage"])
        left, top, right, bottom = clipped_box((x - 7, y - 7, w + 20, h + 20), raw.shape)
        node_mask[top:bottom, left:right] |= lum[top:bottom, left:right] < 251

    # The original image is a precise record of the wires and ports. Recolor
    # that linework, then warm the existing component faces to match the sample.
    darkness = np.clip((247 - lum) / 220, 0, 1) ** 0.85
    bg = np.asarray(BG, dtype=np.float32)
    wire = np.asarray(WIRE, dtype=np.float32)
    out = bg[None, None, :] + darkness[:, :, None] * (wire - bg)[None, None, :]

    warmth = np.clip(lum / 255, 0, 1) ** 0.30
    ink = np.asarray(INK, dtype=np.float32)
    cream = np.asarray(CREAM, dtype=np.float32)
    warm_nodes = ink[None, None, :] + warmth[:, :, None] * (cream - ink)[None, None, :]
    saturation = raw.max(axis=2) - raw.min(axis=2)
    icon_mask = (saturation > 35) & (lum > 45) & node_mask
    warm_nodes[icon_mask] = (55, 116, 91)
    out[node_mask] = warm_nodes[node_mask]

    # Eliminate the canvas's internal method labels; the new images keep IDs
    # only in filenames, never in the rendered card.
    wipe_labels = np.zeros_like(node_mask)
    wipe_labels[:65] = ~node_mask[:65]
    out[wipe_labels] = bg

    qx, qy, qw, qh = relative_box(question["group"], question["stage"])
    left, top, right, bottom = clipped_box((qx - 26, qy - 100, qw + 52, qh + 120), raw.shape)
    clear_slot = np.zeros_like(node_mask)
    clear_slot[top:bottom, left:right] = True
    clear_slot &= ~node_mask
    out[clear_slot] = bg
    themed = Image.fromarray(np.uint8(np.clip(out, 0, 255)), mode="RGB")
    component_mask = Image.fromarray(np.uint8(node_mask) * 255, mode="L")
    return themed, component_mask


def dashed_line(draw: ImageDraw.ImageDraw, start, end, fill, width=4, dash=15, gap=11):
    x1, y1 = start
    x2, y2 = end
    length = math.hypot(x2 - x1, y2 - y1)
    if length == 0:
        return
    dx, dy = (x2 - x1) / length, (y2 - y1) / length
    step = 0.0
    while step < length:
        finish = min(step + dash, length)
        draw.line((x1 + dx * step, y1 + dy * step, x1 + dx * finish, y1 + dy * finish), fill=fill, width=width)
        step += dash + gap


def draw_connection(draw: ImageDraw.ImageDraw, start, end, *, dashed: bool):
    x0, y0 = start
    x1, y1 = end
    dx = x1 - x0
    bend = max(48, abs(dx) * 0.45)
    direction = 1 if dx >= 0 else -1
    c1 = (x0 + bend * direction, y0)
    c2 = (x1 - bend * direction, y1)
    points = []
    for i in range(101):
        t = i / 100
        u = 1 - t
        x = u**3 * x0 + 3 * u**2 * t * c1[0] + 3 * u * t**2 * c2[0] + t**3 * x1
        y = u**3 * y0 + 3 * u**2 * t * c1[1] + 3 * u * t**2 * c2[1] + t**3 * y1
        points.append((x, y))
    if dashed:
        distance = 0.0
        on = True
        run = 0.0
        for a, b in zip(points, points[1:]):
            segment = math.dist(a, b)
            if segment == 0:
                continue
            traversed = 0.0
            while traversed < segment:
                amount = min(segment - traversed, (19 if on else 13) - run)
                s = traversed / segment
                e = (traversed + amount) / segment
                p0 = (a[0] + (b[0] - a[0]) * s, a[1] + (b[1] - a[1]) * s)
                p1 = (a[0] + (b[0] - a[0]) * e, a[1] + (b[1] - a[1]) * e)
                if on:
                    draw.line((p0, p1), fill=(160, 185, 170), width=5)
                traversed += amount
                run += amount
                if run >= (19 if on else 13) - 0.001:
                    run = 0.0
                    on = not on
    else:
        draw.line(points, fill=(181, 205, 187), width=5, joint="curve")


def draw_slot(draw: ImageDraw.ImageDraw, box, inputs: int, outputs: int):
    x, y, w, h = box
    radius = min(29, int(h * 0.17))
    draw.rounded_rectangle((x, y, x + w, y + h), radius=radius, fill=(70, 83, 72), outline=(119, 125, 96), width=10)
    inset = 18
    ix, iy, iw, ih = x + inset, y + inset, w - 2 * inset, h - 2 * inset
    r = max(9, radius - inset // 2)
    dash_color = (236, 218, 166)
    dashed_line(draw, (ix + r, iy), (ix + iw - r, iy), dash_color)
    dashed_line(draw, (ix + r, iy + ih), (ix + iw - r, iy + ih), dash_color)
    dashed_line(draw, (ix, iy + r), (ix, iy + ih - r), dash_color)
    dashed_line(draw, (ix + iw, iy + r), (ix + iw, iy + ih - r), dash_color)
    draw.arc((ix, iy, ix + 2 * r, iy + 2 * r), 180, 270, fill=dash_color, width=4)
    draw.arc((ix + iw - 2 * r, iy, ix + iw, iy + 2 * r), 270, 360, fill=dash_color, width=4)
    draw.arc((ix, iy + ih - 2 * r, ix + 2 * r, iy + ih), 90, 180, fill=dash_color, width=4)
    draw.arc((ix + iw - 2 * r, iy + ih - 2 * r, ix + iw, iy + ih), 0, 90, fill=dash_color, width=4)
    for guide_x in (x + w * 0.25, x + w * 0.75):
        draw.line((guide_x, y + h * 0.20, guide_x, y + h * 0.80), fill=(126, 145, 130), width=2)
    question_font = font("georgiab.ttf", max(50, min(126, round(h * 0.55))))
    draw.text((x + w / 2, y + h / 2 - 3), "?", font=question_font, fill=(249, 248, 233), anchor="mm")
    dot_r = max(7, round(min(w, h) * 0.033))
    for count, side_x in ((inputs, x + 1), (outputs, x + w - 1)):
        for i in range(count):
            dot_y = y + h * (i + 1) / (count + 1)
            draw.ellipse((side_x - dot_r, dot_y - dot_r, side_x + dot_r, dot_y + dot_r), fill=(227, 198, 116))


def fit_diagram(size: tuple[int, int]):
    src_w, src_h = size
    max_w, max_h = 1430, 590
    scale = min(2.2, max_w / src_w, max_h / src_h)
    w, h = round(src_w * scale), round(src_h * scale)
    return (round((WIDTH - w) / 2), round(232 + (590 - h) / 2), w, h, scale)


def make_card(key: str, question: dict, stage_nodes: list[dict], target_wires: list[dict]):
    source = Image.open(SOURCE / f"{key}.png").convert("RGB")
    themed, component_mask = theme_source(source, question, stage_nodes)
    px, py, pw, ph, scale = fit_diagram(source.size)
    themed = themed.resize((pw, ph), Image.Resampling.LANCZOS)
    component_mask = component_mask.resize((pw, ph), Image.Resampling.NEAREST)

    card = Image.new("RGB", (WIDTH, HEIGHT), BG)
    card.paste(themed, (px, py))
    draw = ImageDraw.Draw(card)

    # Quiet frame and rule follow the source card's restrained game UI.
    draw.rounded_rectangle((2, 2, WIDTH - 3, HEIGHT - 3), radius=13, outline=(60, 86, 77), width=4)
    draw.line((43, 204, WIDTH - 43, 204), fill=(55, 80, 73), width=2)
    draw.line((43, 927, WIDTH - 43, 927), fill=(55, 80, 73), width=2)
    draw.text((44, 38), TITLES[key].upper(), font=TITLE_FONT, fill=GOLD)
    draw.text((44, 123), CAPTIONS[key], font=SUB_FONT, fill=MUTED)

    qx, qy, qw, qh = relative_box(question["group"], question["stage"])
    slot = (round(px + qx * scale), round(py + qy * scale), round(qw * scale), round(qh * scale))

    for wire in target_wires:
        raw_x = (wire["pivot"][0] - question["stage"][0]) * 2 + 18
        raw_y = (wire["pivot"][1] - question["stage"][1]) * 2 + 50
        anchor = (
            round(px + max(0, min(source.width, raw_x)) * scale),
            round(py + max(0, min(source.height, raw_y)) * scale),
        )
        side, index = wire["side"], wire["index"]
        if side == "I":
            port = (slot[0], round(slot[1] + slot[3] * (index + 1) / (question["inputs"] + 1)))
            draw_connection(draw, anchor, port, dashed=True)
        else:
            port = (slot[0] + slot[2], round(slot[1] + slot[3] * (index + 1) / (question["outputs"] + 1)))
            if 0 <= raw_x <= source.width and 0 <= raw_y <= source.height and anchor[0] > port[0] + 48:
                draw_connection(draw, port, anchor, dashed=False)
            else:
                stub_end = (port[0] + min(44, max(18, anchor[0] - port[0])), port[1])
                draw.line((port, stub_end), fill=(181, 205, 187), width=5)

    # Existing cards stay above the newly traced wires, just as they would on
    # the Grasshopper canvas.
    card.paste(themed, (px, py), component_mask)
    draw = ImageDraw.Draw(card)

    draw_slot(draw, slot, question["inputs"], question["outputs"])

    label = "MISSING NODE"
    label_width = draw.textbbox((0, 0), label, font=LABEL_FONT)[2]
    lx = slot[0] + (slot[2] - label_width) / 2
    ly = slot[1] + slot[3] + 10
    if ly < 885:
        draw.text((lx, ly), label, font=LABEL_FONT, fill=GOLD)

    draw.text((44, 950), "SELECTED SLOT", font=LABEL_FONT, fill=GOLD)
    draw.text((246, 947), "• Choose the component that moves this definition forward.", font=FOOTER_FONT, fill=(211, 223, 212))
    card.save(TARGET / f"{key}.png", optimize=True)


def main():
    questions, nodes, wires = parse_layout()
    expected = {p.stem for p in SOURCE.glob("A??_Q??.png")}
    assert expected == set(questions) == set(CAPTIONS) == set(TITLES), (len(expected), len(questions), len(CAPTIONS), len(TITLES))
    for key in sorted(questions):
        make_card(key, questions[key], nodes[key], wires[key])
    print(f"Created {len(questions)} styled level images in {TARGET}")


if __name__ == "__main__":
    main()
