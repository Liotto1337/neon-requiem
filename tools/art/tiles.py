"""16x16 tile atlas (shown x4 in game): floors with variants, animated hazards (4 frames),
decor, floor shadows and wall *blocks*. A wall block is drawn in a slight oblique view — the
roof is lifted by BLOCK_UP px and shifted left by BLOCK_SIDE px, so the front face and the
right side face show — and comes in 16 variants by which neighbours are open (front / side
faces, roof rims). Each block variant takes 2x2 atlas cells; the base footprint sits on the
centre of the 32x32 region, so the tile maps onto exactly one grid cell.
Reads data/tiles.json for atlas coordinates; writes assets/tiles/neon_atlas.png."""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

from palette import BRICK, CHROME, CONCRETE, FLOOR, GUNMETAL, MARBLE, MOSS, NEON, OUTLINE, RUST, STEEL, VOID
from pixlib import Canvas, hex_rgb, mix

T = 16
BLOCK_UP = 8
BLOCK_SIDE = 3
SHADOW = 5
SHADOW_ALPHA = 120
OPEN_S, OPEN_E, OPEN_N, OPEN_W = 1, 2, 4, 8


def _rng(seed: int) -> np.random.Generator:
    return np.random.default_rng(seed)


def _base(colors: list[str], seed: int, specks: int = 6) -> Canvas:
    """Flat floor with a few darker / lighter specks (no dithering at 16 px)."""
    c = Canvas(T, T)
    c.rgb[:] = hex_rgb(colors[1])
    c.alpha[:] = True
    rng = _rng(seed)
    for k in range(specks):
        x, y = int(rng.integers(0, T)), int(rng.integers(0, T))
        c.rgb[y, x] = hex_rgb(colors[0] if k % 2 else colors[2])
    return c


def _px(c: Canvas, pts, color: str) -> None:
    for x, y in pts:
        if 0 <= x < c.w and 0 <= y < c.h:
            c.rgb[y, x] = hex_rgb(color)
            c.alpha[y, x] = True


def _rect(c: Canvas, x: int, y: int, w: int, h: int, color: str) -> None:
    c.rgb[y:y + h, x:x + w] = hex_rgb(color)
    c.alpha[y:y + h, x:x + w] = True


# ---------------------------------------------------------------- floors

def floor_asphalt(v: int) -> Image.Image:
    f = FLOOR["slum"]
    c = _base(f, 10 + v, 8)
    if v == 1:
        _px(c, [(4, 5), (5, 6), (6, 6), (7, 7), (8, 8)], f[0])
    if v == 2:  # manhole
        _rect(c, 5, 5, 6, 6, f[0]); _rect(c, 6, 6, 4, 4, f[2])
        _px(c, [(6, 7), (7, 7), (8, 7), (9, 7), (6, 9), (7, 9), (8, 9), (9, 9)], f[0])
    return c.image()


def floor_puddle(v: int) -> Image.Image:
    f = FLOOR["slum"]
    c = _base(f, 20 + v, 4)
    _rect(c, 3, 6, 10, 5, "#0a0716"); _rect(c, 4, 5, 8, 7, "#0a0716")
    col = mix(NEON["magenta"] if v == 0 else NEON["cyan"], "#0a0716", 0.55)
    _px(c, [(5, 7), (6, 7), (7, 7), (8, 9), (9, 9)], col)
    return c.image()


def floor_plate(v: int) -> Image.Image:
    f = FLOOR["core"]
    c = _base(f, 30 + v, 3)
    _rect(c, 0, 0, T, 1, f[3]); _rect(c, 0, 0, 1, T, f[3])
    _rect(c, 0, T - 1, T, 1, f[0]); _rect(c, T - 1, 0, 1, T, f[0])
    _px(c, [(2, 2), (13, 2), (2, 13), (13, 13)], f[3])
    if v == 1:
        _px(c, [(4, 6), (5, 6), (6, 6), (6, 7), (6, 8), (7, 8)], mix(NEON["cyan"], f[1], 0.65))
    if v == 2:
        _rect(c, 9, 9, 4, 1, mix(NEON["cyan"], f[1], 0.7))
    return c.image()


def floor_glow(v: int) -> Image.Image:
    f = FLOOR["core"]
    c = _base(f, 40 + v, 0)
    _rect(c, 2, 2, 12, 12, "#08202a")
    col = mix(NEON["cyan"], "#08202a", 0.3)
    _rect(c, 2, 2, 12, 1, col); _rect(c, 2, 13, 12, 1, col); _rect(c, 2, 2, 1, 12, col); _rect(c, 13, 2, 1, 12, col)
    if v:
        _rect(c, 7, 3, 2, 10, mix(NEON["cyan"], "#08202a", 0.6))
    return c.image()


def floor_moss(v: int, bright: bool = False) -> Image.Image:
    f = FLOOR["garden"]
    c = _base(f, 50 + v + (10 if bright else 0), 6)
    rng = _rng(60 + v)
    for _ in range(3):
        x, y = int(rng.integers(1, 15)), int(rng.integers(2, 15))
        _px(c, [(x, y), (x, y - 1)], MOSS[2])
    if bright:
        for _ in range(2 + v):
            x, y = int(rng.integers(1, 15)), int(rng.integers(1, 15))
            _px(c, [(x, y)], NEON["lime"])
    if v == 1:
        _px(c, [(9, 9), (10, 9), (10, 10)], CHROME[2])
    return c.image()


def floor_rust(v: int) -> Image.Image:
    f = FLOOR["rail"]
    c = _base(f, 70 + v, 5)
    for y in range(2, T, 5):
        for x in range((y // 5 % 2) * 2 + 1, T, 5):
            _px(c, [(x, y)], f[3])
    _rect(c, 0, T - 1, T, 1, f[0]); _rect(c, T - 1, 0, 1, T, f[0])
    if v >= 2:
        _rect(c, 4 + v, 5, 4, 3, mix(RUST[2], f[1], 0.5))
    return c.image()


def floor_track(v: int) -> Image.Image:
    f = FLOOR["rail"]
    c = _base(f, 80, 3)
    for x in (1, 6, 11):
        _rect(c, x, 2, 3, 12, RUST[1])
        _px(c, [(x, 2), (x + 1, 2)], RUST[2])
    for y in (4, 11):
        _rect(c, 0, y, T, 1, STEEL[2]); _rect(c, 0, y + 1, T, 1, STEEL[1])
    return c.image()


def floor_marble(v: int) -> Image.Image:
    f = FLOOR["spire"]
    c = _base(f, 90 + v, 4)
    rng = _rng(91 + v)
    x, y = int(rng.integers(0, 6)), 0
    while y < T:
        _px(c, [(x % T, y)], f[3])
        x += int(rng.integers(0, 2)); y += 1
    _rect(c, 0, T - 1, T, 1, f[0])
    return c.image()


def floor_rune(v: int) -> Image.Image:
    f = FLOOR["spire"]
    c = Canvas(T, T)
    c.rgb[:] = np.array(floor_marble(v))[..., :3]
    c.alpha[:] = True
    col = mix(NEON["purple"], f[1], 0.45)
    c.flat(c.ring(8, 8, 5, 1.2), col)
    _px(c, [(7, 7), (8, 8), (7, 8), (8, 7)], NEON["purple"] if v else col)
    return c.image()


def floor_hub(v: int) -> Image.Image:
    f = FLOOR["hub"]
    c = _base(f, 100 + v, 2)
    _rect(c, 0, 0, T, 1, f[3]); _rect(c, 0, 0, 1, T, f[3]); _rect(c, 0, T - 1, T, 1, f[0]); _rect(c, T - 1, 0, 1, T, f[0])
    if v == 1:
        _px(c, [(7, 7), (8, 7), (7, 8), (8, 8)], f[3])
    if v == 3:
        _rect(c, 3, 12, 10, 1, f[2])
    return c.image()


def floor_hub_line(v: int) -> Image.Image:
    c = Canvas(T, T)
    c.rgb[:] = np.array(floor_hub(0))[..., :3]
    c.alpha[:] = True
    col = NEON["cyan"] if v == 0 else NEON["magenta"]
    _rect(c, 0, 7, T, 2, mix(col, FLOOR["hub"][1], 0.55))
    _rect(c, 0, 7, T, 1, mix(col, FLOOR["hub"][1], 0.2))
    return c.image()


def floor_hub_line_v(v: int) -> Image.Image:
    return floor_hub_line(v).transpose(Image.Transpose.TRANSPOSE)


# ---------------------------------------------------------------- hazards (4 frames)

def _hazard_toxic(c: Canvas, frame: int) -> None:
    c.rgb[:] = hex_rgb("#0f2208"); c.alpha[:] = True
    rng = _rng(7)
    for _ in range(10):
        _px(c, [(int(rng.integers(0, T)), int(rng.integers(0, T)))], "#1a3a0c")
    for k, (x, y) in enumerate(((4, 5), (11, 9), (7, 12))):
        r = (frame + k) % 4
        if r == 1:
            _px(c, [(x, y)], "#4a8a1a")
        elif r == 2:
            _px(c, [(x, y), (x + 1, y), (x, y - 1), (x + 1, y - 1)], "#4a8a1a"); _px(c, [(x, y - 1)], NEON["lime"])
        elif r == 3:
            _px(c, [(x - 1, y), (x + 2, y), (x, y - 2), (x + 1, y + 1)], "#2a5a10")


def _hazard_static(c: Canvas, frame: int) -> None:
    c.rgb[:] = np.array(floor_plate(0))[..., :3]; c.alpha[:] = True
    _rect(c, 1, 1, 14, 14, "#0a1638")
    rng = _rng(100 + frame)
    x, y = int(rng.integers(1, 4)), int(rng.integers(2, 14))
    for _ in range(12):
        _px(c, [(x, y)], NEON["cyan"] if rng.random() < 0.75 else NEON["white"])
        x = min(14, x + 1); y = int(min(14, max(1, y + rng.integers(-1, 2))))


def _hazard_vines(c: Canvas, frame: int) -> None:
    c.rgb[:] = np.array(floor_moss(0))[..., :3]; c.alpha[:] = True
    rng = _rng(55)
    for k in range(4):
        x, y = int(rng.integers(1, 15)), int(rng.integers(1, 15))
        for _ in range(5):
            _px(c, [(x, y)], MOSS[2])
            x = int(min(15, max(0, x + rng.integers(-1, 2)))); y = int(min(15, max(0, y + rng.integers(-1, 2))))
        _px(c, [(x, y)], NEON["lime"] if (frame + k) % 2 else MOSS[3])
        _px(c, [(x + 1, y - 1)], "#c8e8a0")


def _hazard_rail(c: Canvas, frame: int, vertical: bool) -> None:
    img = floor_track(0)
    if vertical:
        img = img.transpose(Image.Transpose.TRANSPOSE)
    c.rgb[:] = np.array(img)[..., :3]; c.alpha[:] = True
    rng = _rng(200 + frame)
    for rail in (4, 11):
        for x in range(T):
            if rng.random() < 0.45:
                y = rail + int(rng.integers(-1, 2))
                _px(c, [(y, x) if vertical else (x, y)], NEON["amber"] if rng.random() < 0.7 else NEON["white"])


def _hazard_void(c: Canvas, frame: int) -> None:
    c.rgb[:] = hex_rgb(VOID[1]); c.alpha[:] = True
    ph = frame * math.pi / 2
    for y in range(T):
        for x in range(T):
            a = math.atan2(y - 7.5, x - 7.5)
            d = math.hypot(x - 7.5, y - 7.5)
            if math.sin(a * 2 + d * 0.8 - ph) > 0.6:
                c.rgb[y, x] = hex_rgb(VOID[3])
            elif d < 2:
                c.rgb[y, x] = hex_rgb(VOID[0])
    _px(c, [(3 + frame * 3, 2), (12 - frame * 2, 13)], NEON["purple"])


def hazard(kind: str, frame: int) -> Image.Image:
    c = Canvas(T, T)
    if kind == "toxic":
        _hazard_toxic(c, frame)
    elif kind == "static":
        _hazard_static(c, frame)
    elif kind == "vines":
        _hazard_vines(c, frame)
    elif kind in ("rail_h", "rail_v"):
        _hazard_rail(c, frame, kind == "rail_v")
    elif kind == "void":
        _hazard_void(c, frame)
    return c.image()


# ---------------------------------------------------------------- decor (transparent)

FONT = {"Б": ["111", "100", "111", "101", "111"], "А": ["010", "101", "111", "101", "101"],
        "Р": ["110", "101", "110", "100", "100"], "2": ["110", "001", "010", "100", "111"],
        "4": ["101", "101", "111", "001", "001"]}


def _sign(c: Canvas, kind: str) -> None:
    col = NEON["cyan"] if kind == "sign_cyan" else NEON["magenta"]
    _rect(c, 1, 4, 14, 8, "#0a0614")
    _rect(c, 1, 4, 14, 1, col); _rect(c, 1, 11, 14, 1, col); _rect(c, 1, 4, 1, 8, col); _rect(c, 14, 4, 1, 8, col)
    word = "БАР" if kind == "sign_cyan" else "24"
    x = 3 if len(word) == 3 else 5
    for ch in word:
        for gy, row in enumerate(FONT[ch]):
            for gx, bit in enumerate(row):
                if bit == "1":
                    _px(c, [(x + gx, 6 + gy)], col)
        x += 4
    _rect(c, 4, 12, 1, 2, GUNMETAL[2]); _rect(c, 11, 12, 1, 2, GUNMETAL[2])


def decor(kind: str) -> Image.Image:
    c = Canvas(T, T)
    if kind in ("sign_cyan", "sign_magenta"):
        _sign(c, kind)
    elif kind == "cable":
        for k, y in enumerate((6, 9)):
            for x in range(T):
                _px(c, [(x, y + (1 if 4 < x < 11 else 0))], GUNMETAL[2 + (k % 2)])
        _px(c, [(8, 10)], NEON["blue"])
    elif kind == "vent":
        _rect(c, 3, 3, 10, 10, STEEL[1])
        for y in range(4, 12, 2):
            _rect(c, 4, y, 8, 1, STEEL[0])
        _rect(c, 3, 3, 10, 1, STEEL[2])
    elif kind == "plant":
        for k in range(5):
            x1 = 3 + k * 2.5
            c.flat(c.line(8, 13, x1, 4 + abs(k - 2), 1), CHROME[2])
            _px(c, [(int(x1), 4 + abs(k - 2))], NEON["lime"])
        _rect(c, 6, 12, 5, 2, MOSS[2])
    elif kind == "debris":
        _rect(c, 3, 9, 4, 3, CONCRETE[2]); _rect(c, 9, 6, 4, 3, RUST[2]); _px(c, [(11, 7)], NEON["amber"])
        _rect(c, 5, 5, 3, 1, STEEL[2])
    elif kind == "rune":
        c.flat(c.ring(8, 8, 5.5, 1.2), mix(NEON["purple"], "#120f20", 0.25))
        _px(c, [(8, 3), (8, 13), (3, 8), (13, 8)], NEON["purple"])
        _px(c, [(7, 7), (8, 7), (7, 8), (8, 8)], NEON["white"])
    elif kind == "lamp":
        _rect(c, 7, 4, 2, 10, GUNMETAL[2]); _rect(c, 5, 13, 6, 2, GUNMETAL[1])
        _rect(c, 5, 2, 6, 2, STEEL[2]); _rect(c, 6, 4, 4, 1, NEON["amber"])
    elif kind == "hub_planter":
        _rect(c, 3, 9, 10, 5, GUNMETAL[2]); _rect(c, 3, 9, 10, 1, NEON["cyan"])
        for k in range(3):
            c.flat(c.line(8, 9, 4 + k * 4, 3 + (k % 2) * 2, 1), MOSS[3])
    elif kind == "hub_screen":
        _rect(c, 2, 2, 12, 8, GUNMETAL[2]); _rect(c, 3, 3, 10, 6, "#06202a")
        _rect(c, 4, 4, 5, 1, NEON["magenta"]); _rect(c, 4, 6, 7, 1, mix(NEON["cyan"], "#06202a", 0.3))
        _rect(c, 7, 10, 2, 3, GUNMETAL[1]); _rect(c, 5, 13, 6, 1, GUNMETAL[2])
    c.outline(OUTLINE)
    return c.image()


# ---------------------------------------------------------------- floor shadows

def shadow(mask: int) -> Image.Image:
    """Shadow cast towards the bottom-left by walls at E (bit 1), N (bit 2), NE (bit 4)."""
    a = np.zeros((T, T), np.uint8)
    if mask & 1:
        a[SHADOW:T, T - SHADOW:T] = SHADOW_ALPHA
    if mask & 2:
        a[0:SHADOW, 0:T - SHADOW] = SHADOW_ALPHA
    if mask & 4:
        a[0:SHADOW, T - SHADOW:T] = SHADOW_ALPHA
    out = np.zeros((T, T, 4), np.uint8)
    out[..., :3] = hex_rgb("#020104")
    out[..., 3] = a
    return Image.fromarray(out, "RGBA")


# ---------------------------------------------------------------- wall blocks

WALLS = {
    "slum": {"top": ["#1a0c1e", "#24122a", "#2e1836"], "front": BRICK, "side": ["#0c050a", "#1a0a16", "#2a1222"], "trim": None},
    "core": {"top": ["#0a1024", "#101a36", "#162444"], "front": ["#05081a", "#0a1028", "#101a36", "#18264a"], "side": ["#04060e", "#080c1c", "#0e1428"], "trim": "cyan"},
    "garden": {"top": CHROME[:3], "front": CHROME, "side": ["#0c0b14", "#1e1f2c", "#2e3040"], "trim": "lime"},
    "rail": {"top": RUST[:3], "front": RUST, "side": ["#0a0503", "#1c0f08", "#2e180e"], "trim": "amber"},
    "spire": {"top": MARBLE[:3], "front": MARBLE, "side": ["#0a0814", "#1a1630", "#2a2448"], "trim": "purple"},
    "edge": {"top": ["#07040e", "#0e0818", "#160c24"], "front": ["#04020a", "#0a0614", "#120a20", "#1a1030"], "side": ["#030108", "#07040e", "#0e0818"], "trim": "cyan"},
    "crate": {"top": ["#2a1a0a", "#3a2410", "#4a3018"], "front": ["#160c04", "#2a1a0a", "#3a2410", "#4a3018"], "side": ["#0c0602", "#1a0f06", "#2a1a0a"], "trim": "amber"},
    "barrier": {"top": ["#0d0618", "#1a0b2e", "#24103f"], "front": ["#06030c", "#0d0618", "#1a0b2e", "#24103f"], "side": ["#030108", "#0a0514", "#140a24"], "trim": "magenta"},
    "hub": {"top": ["#0c0b18", "#141226", "#1c1a32"], "front": ["#06050c", "#0c0b18", "#141226", "#1c1a32"], "side": ["#030208", "#08070f", "#0e0c18"], "trim": "cyan"},
}


def _front_x(row: int) -> int:
    """Horizontal shift of a front-face row (the face leans right as it goes down)."""
    return (row * BLOCK_SIDE + BLOCK_UP // 2) // BLOCK_UP


def _front_detail(c: Canvas, kind: str, v: int) -> None:
    f = WALLS[kind]["front"]
    if kind == "slum":
        for row in range(1, BLOCK_UP, 3):
            off = 0 if row // 3 % 2 == 0 else 2
            for x in range(off, T, 5):
                _px(c, [(x + _front_x(row), T + row)], f[0])
    elif kind == "core":
        for row in (2, 5):
            for k in range(4):
                _px(c, [(2 + k * 4 + _front_x(row), T + row)], NEON["cyan"] if (k + row + v) % 3 else NEON["lime"])
    elif kind == "garden":
        _px(c, [(4 + _front_x(4), T + 4), (5 + _front_x(5), T + 5), (12 + _front_x(3), T + 3)], MOSS[3])
    elif kind == "rail":
        for x in range(1, T, 6):
            _px(c, [(x + _front_x(4), T + 4)], RUST[0])
    elif kind == "crate":
        for row in (2, 5):
            for x in range(T):
                _px(c, [(x + _front_x(row), T + row)], f[1])
    elif kind in ("edge", "hub", "barrier"):
        trim = NEON[WALLS[kind]["trim"]]
        for x in range(T):
            _px(c, [(x + _front_x(BLOCK_UP - 2), T + BLOCK_UP - 2)], mix(trim, f[1], 0.45))


def _faces(c: Canvas, wall: dict, kind: str, variant: int) -> None:
    if variant & OPEN_E:  # right side face: roof right edge -> base right edge
        for row in range(T + BLOCK_UP):
            for dx in range(BLOCK_SIDE):
                x = T + dx
                y_top = dx * BLOCK_UP // BLOCK_SIDE
                if y_top <= row < y_top + T:
                    shade = wall["side"][1] if row - y_top < T - 3 else wall["side"][0]
                    _px(c, [(x, row)], shade)
    if variant & OPEN_S:  # front face: roof bottom edge -> base bottom edge
        for row in range(BLOCK_UP):
            shade = wall["front"][2] if row < 2 else (wall["front"][1] if row < BLOCK_UP - 2 else wall["front"][0])
            for x in range(T):
                _px(c, [(x + _front_x(row), T + row)], shade)
        _front_detail(c, kind, variant)


def wall_block(kind: str, variant: int) -> Image.Image:
    """(16 + BLOCK_SIDE) x (16 + BLOCK_UP) block: roof at (0, 0, 16, 16); base footprint at
    (BLOCK_SIDE, BLOCK_UP) .. (16 + BLOCK_SIDE, 16 + BLOCK_UP)."""
    wall = WALLS[kind]
    c = Canvas(T + BLOCK_SIDE, T + BLOCK_UP)
    _faces(c, wall, kind, variant)
    _rect(c, 0, 0, T, T, wall["top"][1])
    rng = _rng(sum(map(ord, kind)) + variant)
    for _ in range(5):
        x, y = int(rng.integers(1, 15)), int(rng.integers(1, 15))
        c.rgb[y, x] = hex_rgb(wall["top"][0] if rng.random() < 0.5 else wall["top"][2])
    trim = wall["trim"]
    if variant & OPEN_N:
        _rect(c, 0, 0, T, 1, wall["top"][2])
    if variant & OPEN_W:
        _rect(c, 0, 0, 1, T, wall["top"][2])
    if variant & OPEN_E:
        _rect(c, T - 1, 0, 1, T, wall["top"][0])
    if variant & OPEN_S:
        _rect(c, 0, T - 1, T, 1, mix(NEON[trim], wall["top"][1], 0.35) if trim else wall["top"][0])
    if kind == "crate":
        for k in range(1, 15):
            _px(c, [(k, k)], wall["top"][0])
    if kind == "spire":
        _px(c, [(7, 7), (8, 7), (7, 8), (8, 8)], NEON["purple"])
    return c.image()


def block_region(kind: str, variant: int) -> Image.Image:
    """2x2-cell atlas region with the block's base footprint on the region centre."""
    region = Image.new("RGBA", (2 * T, 2 * T), (0, 0, 0, 0))
    block = wall_block(kind, variant)
    region.paste(block, (T - (BLOCK_SIDE + T // 2), T - (BLOCK_UP + T // 2)))
    return region


# ---------------------------------------------------------------- atlas

def paint(tile: dict, index: int) -> Image.Image:
    art = tile["art"]
    if art.startswith("hazard:"):
        return hazard(art.split(":")[1], index)
    if art.startswith("decor:"):
        return decor(art.split(":")[1])
    if art == "shadow":
        return shadow(index + 1)
    floors = {
        "asphalt": floor_asphalt, "puddle": floor_puddle, "plate": floor_plate, "glow": floor_glow,
        "moss": floor_moss, "moss_bright": lambda v: floor_moss(v, True), "rust": floor_rust,
        "track": floor_track, "marble": floor_marble, "rune": floor_rune, "hub": floor_hub,
        "hub_line": floor_hub_line, "hub_line_v": floor_hub_line_v,
    }
    return floors[art](index)


def build_atlas(table: dict) -> Image.Image:
    cols, rows = table["atlas_columns"], table["atlas_rows"]
    atlas = Image.new("RGBA", (cols * T, rows * T), (0, 0, 0, 0))
    used: set[tuple[int, int]] = set()
    for tile in table["tiles"]:
        x, y = tile["atlas"]
        if tile["art"].startswith("block:"):
            for k in range(16):
                _claim(used, [(x + 2 * k + dx, y + dy) for dx in (0, 1) for dy in (0, 1)], cols, rows, tile["id"])
                atlas.paste(block_region(tile["art"].split(":")[1], k), ((x + 2 * k) * T, y * T))
            continue
        for k in range(max(int(tile.get("variants", 1)), int(tile.get("frames", 1)))):
            _claim(used, [(x + k, y)], cols, rows, tile["id"])
            atlas.paste(paint(tile, k), ((x + k) * T, y * T))
    return atlas


def _claim(used: set, cells: list, cols: int, rows: int, tile_id: str) -> None:
    for cell in cells:
        if cell in used or cell[0] >= cols or cell[1] >= rows:
            raise SystemExit("tiles: atlas cell %s of %s overlaps or is outside" % (cell, tile_id))
        used.add(cell)


# ---------------------------------------------------------------- backdrop (beyond the map)

def backdrop() -> Image.Image:
    """64x64 tileable night backdrop for the parallax layer: far towers with a few lit
    windows over a starless haze. Shown behind the map edges, scrolling slower than the map."""
    size = 64
    c = Canvas(size, size)
    c.rgb[:] = hex_rgb("#040209"); c.alpha[:] = True
    rng = _rng(4242)
    x = 0
    while x < size:
        w = int(rng.integers(5, 11))
        h = int(rng.integers(16, 46))
        col = "#0a0614" if rng.random() < 0.5 else "#0d0818"
        for xx in range(x, min(size, x + w)):
            c.rgb[size - h:size, xx] = hex_rgb(col)
        for _ in range(int(rng.integers(1, 4))):
            wx = x + int(rng.integers(1, max(2, w - 1)))
            wy = size - int(rng.integers(3, h - 1))
            if wx < size:
                c.rgb[wy, wx] = hex_rgb(mix(NEON["magenta"] if rng.random() < 0.5 else NEON["cyan"], "#0a0614", 0.45))
        x += w + int(rng.integers(0, 3))
    for _ in range(10):
        c.rgb[int(rng.integers(0, 30)), int(rng.integers(0, size))] = hex_rgb("#1e1830")
    return c.image()
