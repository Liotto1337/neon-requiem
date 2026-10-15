"""Tile atlas for every location: 64x64 tiles, floors with variants, wall tops and faces
(3/4 view), animated hazards (4 frames) and decor. Reads data/tiles.json for the atlas
coordinates and the art key of every tile; writes assets/tiles/neon_atlas.png."""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

from palette import BRASS, BRICK, CHROME, CONCRETE, GUNMETAL, MARBLE, MOSS, NEON, OUTLINE, RUST, STEEL, VOID, GLOW, TINT
from pixlib import Canvas, fractal_noise, hex_rgb, mix, quantize, ramp, value_noise

T = 64


def _fill_tex(c: Canvas, colors: list[str], seed: int, cells=(16, 8, 4), dither: float = 0.7, lo: float = 0.15, hi: float = 0.85) -> np.ndarray:
    n = fractal_noise(T, T, seed, cells)
    n = (n - n.min()) / max(1e-6, n.max() - n.min())
    n = lo + n * (hi - lo)
    c.rgb[:] = quantize(n, colors, dither)
    c.alpha[:] = True
    return n


def _speckle(c: Canvas, rng: np.random.Generator, color: str, count: int, margin: int = 0) -> None:
    for _ in range(count):
        x, y = rng.integers(margin, T - margin), rng.integers(margin, T - margin)
        c.rgb[y, x] = hex_rgb(color)


def _crack(c: Canvas, rng: np.random.Generator, color: str, length: int, margin: int = 6) -> None:
    x, y = float(rng.integers(margin, T - margin)), float(rng.integers(margin, T - margin))
    ang = rng.random() * math.tau
    for _ in range(length):
        ang += (rng.random() - 0.5) * 0.9
        x = min(T - margin, max(margin, x + math.cos(ang)))
        y = min(T - margin, max(margin, y + math.sin(ang)))
        c.rgb[int(y), int(x)] = hex_rgb(color)


def _seams(c: Canvas, dark: str, light: str, inset: int = 0) -> None:
    c.rgb[inset, :] = hex_rgb(light)
    c.rgb[:, inset] = hex_rgb(light)
    c.rgb[T - 1 - inset, :] = hex_rgb(dark)
    c.rgb[:, T - 1 - inset] = hex_rgb(dark)


def _bolt(c: Canvas, x: int, y: int, colors: list[str]) -> None:
    c.rgb[y, x] = hex_rgb(colors[-1])
    c.rgb[y + 1, x + 1] = hex_rgb(colors[0])
    c.rgb[y, x + 1] = hex_rgb(colors[2])
    c.rgb[y + 1, x] = hex_rgb(colors[2])


# ---------------------------------------------------------------- floors

def floor_asphalt(v: int) -> Image.Image:
    c = Canvas(T, T)
    rng = np.random.default_rng(100 + v)
    _fill_tex(c, ["#120a1e", "#1a1028", "#211534", "#2a1c40"], 11, (16, 8, 4), 0.9, 0.1, 0.8)
    _speckle(c, rng, "#3b2a56", 26)
    _speckle(c, rng, "#0d0716", 18)
    if v == 1:
        _crack(c, rng, "#0a0512", 40)
    if v == 2:  # manhole cover
        c.paint(c.circle(32, 32, 11), GUNMETAL[:4], style="dome", dither=0.3)
        for k in range(-8, 9, 4):
            c.flat(c.rect(24, 32 + k, 16, 1).clip(c.circle(32, 32, 9)), GUNMETAL[0])
    if v == 3:
        c.paint(c.ellipse(40, 22, 6, 4), ["#0c0614", "#160c22"], style="flat")
        _crack(c, rng, "#0a0512", 22)
    return c.image()


def floor_puddle(v: int) -> Image.Image:
    c = Canvas(T, T)
    base = np.array(floor_asphalt(v + 1))
    c.rgb[:] = base[..., :3]
    c.alpha[:] = True
    puddle = c.ellipse(32, 33, 24, 15, 8 if v == 0 else -12) | c.ellipse(20 + v * 20, 40, 10, 7)
    c.paint(puddle, ["#0b0618", "#120a24", "#1a1032", "#22163e"], style="dome", dither=0.8)
    edge = puddle.mask & ~np.roll(puddle.mask, 1, 0)
    c.rgb[edge] = hex_rgb("#3a2a56")
    col = NEON["magenta"] if v == 0 else NEON["cyan"]
    for i, (x, y, w) in enumerate(((18, 30, 14), (24, 34, 18), (30, 38, 10))):
        seg = c.rect(x, y, w, 1).clip(puddle)
        c.flat(seg, mix(col, "#120a24", 0.35 + 0.2 * i))
    c.flat(c.rect(34, 29, 6, 1).clip(puddle), col)
    return c.image()


def floor_plate(v: int) -> Image.Image:
    c = Canvas(T, T)
    c.rgb[:] = hex_rgb("#101834")
    c.alpha[:] = True
    for (x, y) in ((0, 0), (32, 0), (0, 32), (32, 32)):
        c.paint(c.rect(x + 1, y + 1, 30, 30, 2), ["#0b1129", "#121c3e", "#18264c", "#1e2e58"], style="bevel", depth=6, dither=0.3)
    c.rgb[31:33, :] = hex_rgb("#070b1c")
    c.rgb[:, 31:33] = hex_rgb("#070b1c")
    for (x, y) in ((4, 4), (58, 4), (4, 58), (58, 58)):
        _bolt(c, x, y, ["#070b1c", "#2a3a6a", "#3a4c80", "#5a70a8"])
    trace = "#0a5a70"
    if v == 1:
        c.flat(c.rect(8, 16, 18, 1), trace); c.flat(c.rect(25, 16, 1, 10), trace); c.flat(c.rect(25, 26, 4, 1), trace)
        c.flat(c.pixels([(29, 26)]), NEON["cyan"])
    if v == 2:
        c.flat(c.rect(40, 40, 1, 16), trace); c.flat(c.rect(40, 40, 14, 1), trace)
        c.flat(c.pixels([(54, 40), (40, 56)]), NEON["cyan"])
    if v == 3:
        c.paint(c.rect(38, 6, 20, 20, 2), ["#060a18", "#0b1129", "#0e1636"], style="flat")
        for i in range(4):
            c.flat(c.rect(40, 9 + i * 4, 16, 2), "#16224a")
    return c.image()


def floor_glow(v: int) -> Image.Image:
    c = Canvas(T, T)
    c.rgb[:] = np.array(floor_plate(0))[..., :3]
    c.alpha[:] = True
    c.paint(c.rect(8, 8, 48, 48, 3), ["#03202c", "#06303e", "#0a4050"], style="bevel", depth=5, dither=0.4)
    c.flat(c.rect(10, 10, 44, 44).minus(c.rect(11, 11, 42, 42)), NEON["cyan"])
    c.flat(c.rect(14, 14, 36, 36).minus(c.rect(15, 15, 34, 34)), mix(NEON["cyan"], "#03202c", 0.5))
    if v == 1:
        c.flat(c.rect(14, 31, 36, 2), mix(NEON["cyan"], "#03202c", 0.6)); c.flat(c.rect(31, 14, 2, 36), mix(NEON["cyan"], "#03202c", 0.6))
    return c.image()


def floor_moss(v: int, bright: bool = False) -> Image.Image:
    c = Canvas(T, T)
    rng = np.random.default_rng(300 + v + (10 if bright else 0))
    _fill_tex(c, ["#07120a", "#0c1c10", "#122a16", "#1a3a1c", "#244a22"], 31, (16, 8, 4), 0.9, 0.05, 0.85)
    for _ in range(14):  # grass tufts
        x, y = rng.integers(4, T - 6), rng.integers(6, T - 4)
        for dx, h in ((-1, 2), (0, 4), (1, 3)):
            c.rgb[y - h:y, x + dx] = hex_rgb("#3a6a26" if dx == 0 else "#2a5420")
            c.rgb[y - h, x + dx] = hex_rgb("#5a9a34")
    if v == 1:
        c.paint(c.ellipse(40, 40, 7, 4), CHROME[:4], style="dome")  # chrome shard in the moss
    if v == 2:
        c.paint(c.ellipse(20, 22, 9, 6), ["#05100a", "#0a1a0e", "#10261a"], style="flat")
    if bright:
        for _ in range(6 + v * 2):
            x, y = rng.integers(5, T - 5), rng.integers(5, T - 5)
            c.flat(c.pixels([(x, y)]), NEON["lime"])
            c.flat(c.pixels([(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]), "#4a7a10")
        c.paint(c.ellipse(46, 18, 4, 3), ["#2a5a10", "#6aa018", NEON["lime"]], style="dome")
    return c.image()


def floor_rust(v: int) -> Image.Image:
    c = Canvas(T, T)
    rng = np.random.default_rng(400 + v)
    _fill_tex(c, ["#160c08", "#24140c", "#2e1a10", "#3a2214"], 41, (16, 8), 0.8, 0.15, 0.85)
    for y in range(4, T, 8):  # diamond tread
        for x in range((y // 8 % 2) * 4 + 2, T, 8):
            c.rgb[y, x] = hex_rgb("#4e3020"); c.rgb[y + 1, x + 1] = hex_rgb("#4e3020")
            c.rgb[y + 1, x] = hex_rgb("#120806")
    _seams(c, "#0c0604", "#4a2e1c")
    for (x, y) in ((3, 3), (59, 3), (3, 59), (59, 59)):
        _bolt(c, x, y, RUST)
    if v >= 2:
        n = value_noise(T, T, 8, 77 + v)
        stain = (n > 0.72)
        c.rgb[stain] = (c.rgb[stain] * 0.6 + np.array(hex_rgb("#6a3214")) * 0.4).astype(np.uint8)
    if v == 1:
        _crack(c, rng, "#0c0604", 30)
    return c.image()


def floor_track(v: int) -> Image.Image:
    c = Canvas(T, T)
    _fill_tex(c, ["#120a08", "#1a100a", "#22160e"], 43, (8, 4), 0.9)
    for x in (4, 20, 36, 52):  # sleepers
        c.paint(c.rect(x, 10, 9, 44, 1), ["#1c100a", "#3a2214", "#5a3a20", "#6e4a2a"], style="bevel", depth=3, dither=0.3)
    for y in (18, 42):  # rails
        c.paint(c.rect(0, y, T, 5), STEEL, style="cylinder", depth=3, dither=0.2)
        c.rgb[y, :] = hex_rgb("#a8acc4")
    return c.image()


def floor_marble(v: int) -> Image.Image:
    c = Canvas(T, T)
    n = fractal_noise(T, T, 51 + v, (32, 16, 8, 4))
    veins = np.abs(np.sin((n * 9.0 + np.linspace(0, 3, T)[None, :]) * math.pi))
    val = 0.25 + 0.55 * fractal_noise(T, T, 52, (16, 8))
    val = np.where(veins < 0.12, 0.85, val)
    c.rgb[:] = quantize(val, ["#1c1830", "#262040", "#30294e", "#3c345e", "#5a5280"], 0.5)
    c.alpha[:] = True
    _seams(c, "#120e22", "#4a4270")
    return c.image()


def floor_rune(v: int) -> Image.Image:
    c = Canvas(T, T)
    c.rgb[:] = np.array(floor_marble(v))[..., :3]
    c.alpha[:] = True
    col = mix(NEON["purple"], "#1c1830", 0.45)
    c.flat(c.ring(32, 32, 20, 1.2), col)
    for k in range(8 if v else 4):
        a = math.tau * k / (8 if v else 4) + v * 0.4
        c.flat(c.line(32 + math.cos(a) * 13, 32 + math.sin(a) * 13, 32 + math.cos(a) * 18, 32 + math.sin(a) * 18, 1.2), col)
    c.flat(c.rect(31, 31, 2, 2), NEON["purple"])
    return c.image()


def floor_hub(v: int) -> Image.Image:
    c = Canvas(T, T)
    c.rgb[:] = hex_rgb("#0e0c1c")
    c.alpha[:] = True
    c.paint(c.rect(1, 1, 62, 62, 3), ["#100e20", "#16142a", "#1c1a34", "#242240"], style="bevel", depth=8, dither=0.35)
    c.flat(c.rect(1, 1, 62, 1), "#2e2c4c")
    if v == 1:
        c.flat(c.rect(0, 31, T, 2), mix(NEON["cyan"], "#0e0c1c", 0.55))
    if v == 2:
        c.flat(c.ring(32, 32, 10, 1.5), mix(NEON["magenta"], "#0e0c1c", 0.5))
    if v == 3:
        for i in range(5):
            c.flat(c.rect(8 + i * 10, 52, 6, 2), "#2a2846")
    return c.image()


def floor_hub_line(v: int) -> Image.Image:
    c = Canvas(T, T)
    c.rgb[:] = np.array(floor_hub(0))[..., :3]
    c.alpha[:] = True
    col = NEON["cyan"] if v == 0 else NEON["magenta"]
    c.flat(c.rect(0, 29, T, 6), mix(col, "#0e0c1c", 0.6))
    c.flat(c.rect(0, 31, T, 2), col)
    return c.image()


def floor_hub_line_v(v: int) -> Image.Image:
    return floor_hub_line(v).transpose(Image.Transpose.TRANSPOSE)


# ---------------------------------------------------------------- walls (top = cap seen from above)

def _wall_cap(c: Canvas, top: list[str], accent: str | None, y0: int = 0, h: int = T) -> None:
    c.paint(c.rect(0, y0, T, h), top, style="bevel", depth=10, dither=0.4)
    if accent:
        c.flat(c.rect(0, y0 + h - 2, T, 2), accent)


def wall_top(kind: str, v: int) -> Image.Image:
    c = Canvas(T, T)
    if kind == "slum":
        _wall_cap(c, ["#1a0a1c", "#2a1230", "#3a1a40", "#4a2450"], None)
        rng = np.random.default_rng(60 + v)
        _speckle(c, rng, "#5a2e60", 30)
        c.paint(c.rect(10 + v * 20, 12, 18, 14, 2), GUNMETAL, style="bevel", sep=True)  # roof vent / AC
        c.flat(c.rect(13 + v * 20, 16, 12, 1), "#0c0a14"); c.flat(c.rect(13 + v * 20, 20, 12, 1), "#0c0a14")
    elif kind == "core":
        _wall_cap(c, ["#080c1e", "#0e1430", "#141c40", "#1c2650"], None)
        for x in range(6, 60, 8):
            c.flat(c.rect(x, 6, 4, 52), "#0a0f24")
        c.flat(c.rect(2, 30, 60, 2), mix(NEON["cyan"], "#080c1e", 0.5))
    elif kind == "garden":
        _wall_cap(c, CHROME[:5], None)
        _vines(c, v + 1, 6)
    elif kind == "rail":
        _wall_cap(c, RUST[:4], None)
        for x in (8, 28, 48):
            c.paint(c.rect(x, 0, 8, T), RUST, style="cylinder", depth=4, sep=True)
    elif kind == "spire":
        _wall_cap(c, MARBLE[1:], None)
        c.flat(c.rect(6, 6, 52, 52).minus(c.rect(8, 8, 48, 48)), mix(NEON["purple"], "#16122a", 0.35))
        c.paint(c.rect(26, 26, 12, 12, 2), GLOW["purple"], style="dome")
        if v:
            c.flat(c.line(8, 8, 26, 26, 1), mix(NEON["purple"], "#16122a", 0.5))
    elif kind == "edge":
        _wall_cap(c, ["#07040e", "#0e0818", "#160c24", "#1e1230"], None)
        c.flat(c.rect(0, 0, T, 2), NEON["cyan"]); c.flat(c.rect(0, 62, T, 2), mix(NEON["cyan"], "#07040e", 0.5))
    elif kind == "barrier":
        _wall_cap(c, ["#0d0618", "#1a0b2e", "#24103f", "#2e1650"], None)
        for x in range(-T, T, 16):
            c.flat(c.line(x, 64, x + 64, 0, 4), mix(NEON["magenta"], "#1a0b2e", 0.55))
        c.flat(c.rect(0, 0, T, 2), NEON["magenta"])
    elif kind == "crate":
        _crate(c, 0)
    elif kind == "hub":
        _wall_cap(c, ["#0a0916", "#121024", "#1a1832", "#24223e"], None)
        c.flat(c.rect(0, 0, T, 2), mix(NEON["cyan"], "#121024", 0.3))
        c.paint(c.rect(12, 12, 40, 40, 4), GUNMETAL, style="bevel", sep=True)
    return c.image()


def wall_face(kind: str, v: int) -> Image.Image:
    """Bottom row of a wall block: 18 px cap, then the front face facing the camera."""
    c = Canvas(T, T)
    cap = 18
    top = np.array(wall_top(kind, v))[:cap]
    if kind == "spire":
        top = np.array(wall_top("edge", v))[:cap]
    c.rgb[:cap] = top[..., :3]
    c.alpha[:] = True
    face = c.rect(0, cap, T, T - cap)
    if kind == "slum":
        c.paint(face, BRICK, style="flat")
        _bricks(c, cap, BRICK)
        if v == 1:
            _neon_sign(c, 8, cap + 10, 48, 18, NEON["magenta"], "ОТЕЛЬ")
        if v == 2:
            c.paint(c.rect(20, cap + 8, 24, 20, 1), ["#0a0614", "#140a24", "#1e1034"], style="flat")
            c.flat(c.rect(22, cap + 10, 20, 16), mix(NEON["amber"], "#140a24", 0.55))
            c.flat(c.rect(31, cap + 10, 2, 16), "#0a0614"); c.flat(c.rect(22, cap + 17, 20, 2), "#0a0614")
    elif kind == "core":
        c.paint(face, ["#060a18", "#0b1129", "#101834", "#16204a"], style="flat")
        for y in range(cap + 3, T - 2, 7):  # server blades
            c.paint(c.rect(4, y, 56, 5, 1), STEEL[:4], style="bevel", depth=2, dither=0.2)
            for k in range(5):
                on = (k * 7 + y + v * 3) % 5 != 0
                c.flat(c.rect(8 + k * 5, y + 2, 2, 1), NEON["cyan"] if on else "#0a3a48")
            c.flat(c.rect(46, y + 2, 2, 1), NEON["lime"] if (y + v) % 3 else NEON["amber"])
    elif kind == "garden":
        c.paint(face, CHROME[:5], style="cylinder", depth=20)
        for x in (10, 30, 50):
            c.flat(c.rect(x, cap, 2, T - cap), CHROME[0])
        _vines(c, v + 4, 9, y0=cap)
    elif kind == "rail":
        c.paint(face, RUST[:4], style="flat")
        c.paint(c.rect(0, cap + 4, T, 8), RUST, style="cylinder", sep=True)
        c.paint(c.rect(0, T - 12, T, 8), RUST, style="cylinder", sep=True)
        for x in range(0, T, 16):  # truss
            c.flat(c.line(x, cap + 12, x + 16, T - 12, 3), RUST[2])
        for x in (6, 38):
            _bolt(c, x, cap + 7, RUST)
        c.flat(c.rect(0, T - 3, T, 2), mix(NEON["amber"], "#140a06", 0.4 if v else 0.0))
    elif kind in ("spire", "edge"):
        col = NEON["purple"] if kind == "spire" else NEON["cyan"]
        c.paint(face, ["#07040e", "#0e0818", "#160c24", "#1e1230"], style="flat")
        for y in range(cap + 6, T, 12):
            c.flat(c.rect(0, y, T, 1), "#24183a")
        c.flat(c.rect(0, cap, T, 2), col)
        c.flat(c.rect(0, T - 2, T, 2), mix(col, "#07040e", 0.5))
        if v == 1:
            c.flat(c.rect(28, cap + 8, 8, 30), mix(col, "#07040e", 0.3))
    elif kind == "barrier":
        c.paint(face, ["#0d0618", "#1a0b2e", "#24103f"], style="flat")
        for x in range(-T, T, 16):
            c.flat(c.line(x, T, x + 46, cap, 4), mix(NEON["magenta"], "#1a0b2e", 0.45))
        c.flat(c.rect(0, cap, T, 2), NEON["magenta"])
    elif kind == "crate":
        _crate(c, cap)
    elif kind == "hub":
        c.paint(face, ["#0a0916", "#121024", "#1a1832", "#22203c"], style="flat")
        c.flat(c.rect(0, cap, T, 2), NEON["cyan"])
        c.paint(c.rect(8, cap + 8, 48, 26, 2), ["#03141c", "#06222e", "#0a3444"], style="flat")
        for i in range(4):
            c.flat(c.rect(12, cap + 12 + i * 6, 14 + (i * 13 + v * 7) % 26, 2), mix(NEON["cyan"], "#06222e", 0.3 + 0.15 * i))
    return c.image()


def _bricks(c: Canvas, y0: int, colors: list[str]) -> None:
    for row, y in enumerate(range(y0, T, 7)):
        off = 0 if row % 2 == 0 else 8
        c.flat(c.rect(0, y, T, 1), colors[0])
        for x in range(off - 16, T, 16):
            c.flat(c.rect(x, y, 1, 7), colors[0])
            c.flat(c.rect(x + 1, y + 1, 14, 1), colors[3])


FONT = {
    "Б": ["111", "100", "111", "101", "111"], "А": ["010", "101", "111", "101", "101"],
    "Р": ["110", "101", "110", "100", "100"], "Н": ["101", "101", "111", "101", "101"],
    "Е": ["111", "100", "110", "100", "111"], "О": ["111", "101", "101", "101", "111"],
    "Т": ["111", "010", "010", "010", "010"], "Л": ["011", "101", "101", "101", "101"],
    "Ь": ["100", "100", "111", "101", "111"], "К": ["101", "110", "100", "110", "101"],
    "И": ["101", "101", "111", "111", "101"], "2": ["111", "001", "111", "100", "111"],
    "4": ["101", "101", "111", "001", "001"], "7": ["111", "001", "010", "010", "010"],
    "/": ["001", "001", "010", "100", "100"], "С": ["111", "100", "100", "100", "111"],
}


def text(c: Canvas, word: str, x: int, y: int, col: str, scale: int = 1) -> None:
    for ch in word:
        glyph = FONT.get(ch)
        if glyph:
            for gy, row in enumerate(glyph):
                for gx, bit in enumerate(row):
                    if bit == "1":
                        c.flat(c.rect(x + gx * scale, y + gy * scale, scale, scale), col)
        x += 4 * scale


def _neon_sign(c: Canvas, x: int, y: int, w: int, h: int, col: str, word: str = "БАР") -> None:
    c.paint(c.rect(x, y, w, h, 2), ["#07040e", "#0e0818", "#160c24"], style="flat")
    c.flat(c.rect(x, y, w, 1), col); c.flat(c.rect(x, y + h - 1, w, 1), col)
    c.flat(c.rect(x, y, 1, h), col); c.flat(c.rect(x + w - 1, y, 1, h), col)
    scale = 2 if len(word) * 8 <= w - 4 and h >= 14 else 1
    tw = len(word) * 4 * scale - scale
    text(c, word, x + (w - tw) // 2, y + (h - 5 * scale) // 2, col, scale)


def _vines(c: Canvas, seed: int, count: int, y0: int = 0) -> None:
    rng = np.random.default_rng(seed)
    for _ in range(count):
        x, y = float(rng.integers(2, T - 2)), float(rng.integers(y0, T - 4))
        ang = rng.random() * math.tau
        for _ in range(int(rng.integers(10, 24))):
            ang += (rng.random() - 0.5) * 0.8
            x = min(T - 2, max(1, x + math.cos(ang)))
            y = min(T - 2, max(y0, y + math.sin(ang)))
            c.rgb[int(y), int(x)] = hex_rgb("#2a5a1a")
            c.rgb[int(y) + 1, int(x)] = hex_rgb("#122a0c")
        if rng.random() < 0.6:
            c.rgb[int(y), int(x)] = hex_rgb(NEON["lime"])


def _crate(c: Canvas, y0: int) -> None:
    wood = ["#1a0f06", "#3a2412", "#5a3a1c", "#74502a"]
    c.paint(c.rect(0, y0, T, T - y0), wood, style="bevel", depth=6)
    for y in range(y0 + 2, T, 10):
        c.flat(c.rect(2, y, T - 4, 1), wood[0])
    c.flat(c.line(2, y0 + 2, T - 2, T - 2, 3), wood[1])
    c.flat(c.rect(0, y0, T, 3), BRASS[2])
    c.flat(c.rect(6, y0 + 8, 10, 3), NEON["amber"])


# ---------------------------------------------------------------- hazards (4 frames)

def hazard(kind: str, frame: int) -> Image.Image:
    c = Canvas(T, T)
    ph = frame / 4.0 * math.tau
    if kind == "toxic":
        n = fractal_noise(T, T, 71, (32, 16, 8))
        wave = 0.5 + 0.5 * np.sin((c.X + c.Y) * 0.2 + ph + n * 6.0)
        c.rgb[:] = quantize(0.15 + 0.55 * n + 0.2 * wave, ["#0c1c06", "#14300a", "#20440c", "#2e5a10", "#40761a"], 0.8)
        c.alpha[:] = True
        rng = np.random.default_rng(7)
        for k in range(6):
            bx, by = rng.integers(6, 58), rng.integers(6, 58)
            r = 1.0 + 2.5 * ((math.sin(ph + k * 1.7) + 1) / 2)
            c.paint(c.circle(bx, by, r), ["#2e5a10", "#6aa018", NEON["lime"]], style="dome")
        foam = fractal_noise(T, T, 73 + frame, (16, 8)) > 0.78
        c.rgb[foam] = hex_rgb("#4e8a18")
    elif kind == "static":
        c.rgb[:] = np.array(floor_plate(0))[..., :3]
        c.alpha[:] = True
        c.paint(c.rect(4, 4, 56, 56, 4), ["#0a1630", "#102048", "#16305e"], style="bevel", depth=6)
        rng = np.random.default_rng(100 + frame)
        for _ in range(3):
            x, y = float(rng.integers(8, 56)), float(rng.integers(8, 56))
            for _ in range(14):
                nx, ny = x + rng.integers(-4, 5), y + rng.integers(-4, 5)
                nx, ny = min(58, max(6, nx)), min(58, max(6, ny))
                c.flat(c.line(x, y, nx, ny, 1.2), NEON["cyan"] if rng.random() < 0.7 else NEON["white"])
                x, y = nx, ny
    elif kind == "vines":
        c.rgb[:] = np.array(floor_moss(0))[..., :3]
        c.alpha[:] = True
        rng = np.random.default_rng(55)
        for k in range(9):
            x0, y0 = rng.integers(4, 60), rng.integers(4, 60)
            ang = rng.random() * math.tau + 0.25 * math.sin(ph + k)
            pts = [(x0, y0)]
            for _ in range(6):
                ang += (rng.random() - 0.5) * 0.9
                pts.append((pts[-1][0] + math.cos(ang) * 5, pts[-1][1] + math.sin(ang) * 5))
            for a, b in zip(pts, pts[1:]):
                c.paint(c.line(*a, *b, 3), MOSS, style="cylinder")
                c.flat(c.pixels([(int(b[0]) + 2, int(b[1]))]), "#c8ffa0")
            tip = pts[-1]
            c.flat(c.circle(tip[0], tip[1], 1.6), NEON["lime"] if (frame + k) % 2 else "#6a9a20")
    elif kind in ("rail_h", "rail_v"):
        img = floor_track(0)
        if kind == "rail_v":
            img = img.transpose(Image.Transpose.ROTATE_90)
        c.rgb[:] = np.array(img)[..., :3]
        c.alpha[:] = True
        rng = np.random.default_rng(200 + frame)
        for rail in (20, 44):
            x = 0.0
            pts = []
            while x <= T:
                pts.append((x, rail + rng.integers(-3, 4)))
                x += 6
            for a, b in zip(pts, pts[1:]):
                p, q = (a, b) if kind == "rail_h" else ((a[1], a[0]), (b[1], b[0]))
                c.flat(c.line(*p, *q, 1.3), NEON["amber"] if rng.random() < 0.6 else NEON["white"])
    elif kind == "void":
        n = fractal_noise(T, T, 91, (32, 16, 8))
        swirl = 0.5 + 0.5 * np.sin(n * 10.0 - ph + (c.X - c.Y) * 0.05)
        c.rgb[:] = quantize(0.1 + 0.5 * n + 0.35 * swirl ** 4, VOID, 0.8)
        c.alpha[:] = True
        rng = np.random.default_rng(30 + frame)
        for _ in range(5):
            x, y = rng.integers(2, 62), rng.integers(2, 62)
            c.flat(c.pixels([(x, y)]), NEON["purple"] if rng.random() < 0.6 else NEON["white"])
    return c.image()


# ---------------------------------------------------------------- decor (transparent)

def decor(kind: str) -> Image.Image:
    c = Canvas(T, T)
    if kind in ("sign_cyan", "sign_magenta"):
        col = NEON["cyan"] if kind == "sign_cyan" else NEON["magenta"]
        c.paint(c.rect(18, 50, 28, 6, 2), GUNMETAL, style="bevel")  # fallen sign lying on the ground
        _neon_sign(c, 10, 22, 44, 26, col, "БАР" if kind == "sign_cyan" else "24/7")
        c.flat(c.line(14, 48, 18, 54, 2), GUNMETAL[2])
        c.flat(c.line(50, 48, 46, 54, 2), GUNMETAL[2])
    elif kind == "cable":
        for k, col in enumerate(("#141024", "#1e1834", "#2a2246")):
            pts = [(2, 20 + k * 8), (20, 30 + k * 6), (40, 26 + k * 7), (62, 38 + k * 5)]
            for a, b in zip(pts, pts[1:]):
                c.paint(c.line(*a, *b, 4), [col, mix(col, "#5a5280", 0.4), mix(col, "#8a84b0", 0.5)], style="cylinder")
        c.flat(c.circle(40, 33, 2), NEON["blue"])
    elif kind == "vent":
        c.paint(c.rect(12, 12, 40, 40, 3), STEEL, style="bevel", depth=5)
        for y in range(18, 48, 5):
            c.flat(c.rect(16, y, 32, 2), STEEL[0])
        c.flat(c.rect(14, 46, 36, 1), mix(NEON["cyan"], "#0f0d1a", 0.4))
    elif kind == "plant":
        for k in range(7):
            a = -math.pi / 2 + (k - 3) * 0.42
            x1, y1 = 32 + math.cos(a) * 24, 50 + math.sin(a) * 26
            c.paint(c.capsule(32, 50, x1, y1, 3, 1), CHROME[1:6], style="cylinder", sep=True)
            c.flat(c.circle(x1, y1, 1.5), NEON["lime"])
        c.paint(c.ellipse(32, 52, 9, 4), MOSS, style="dome")
    elif kind == "debris":
        c.paint(c.poly([(10, 44), (26, 36), (34, 48), (20, 54)]), CONCRETE, style="bevel")
        c.paint(c.poly([(32, 30), (46, 26), (52, 38), (40, 42)]), RUST, style="bevel")
        c.paint(c.capsule(18, 30, 30, 22, 2), STEEL, style="cylinder")
        c.flat(c.pixels([(44, 33), (45, 33)]), NEON["amber"])
    elif kind == "rune":
        col = NEON["purple"]
        c.flat(c.ring(32, 32, 18, 2), col)
        c.flat(c.ring(32, 32, 11, 1), mix(col, "#16122a", 0.35))
        for k in range(3):
            a = math.tau * k / 3 - math.pi / 2
            c.flat(c.line(32 + math.cos(a) * 11, 32 + math.sin(a) * 11, 32 + math.cos(a) * 22, 32 + math.sin(a) * 22, 1.5), mix(col, "#ffffff", 0.3))
        c.flat(c.rect(30, 30, 4, 4), "#ffffff")
    elif kind == "lamp":
        c.paint(c.ellipse(32, 56, 9, 4), GUNMETAL, style="dome")
        c.paint(c.rect(30, 14, 4, 42), GUNMETAL, style="cylinder")
        c.paint(c.rect(22, 8, 20, 8, 3), STEEL, style="bevel", sep=True)
        c.paint(c.rect(24, 15, 16, 3), GLOW["amber"], style="cylinder")
    elif kind == "hub_planter":
        c.paint(c.rect(14, 36, 36, 20, 3), GUNMETAL, style="bevel")
        c.flat(c.rect(14, 36, 36, 2), NEON["cyan"])
        for k in range(5):
            a = -math.pi / 2 + (k - 2) * 0.5
            c.paint(c.capsule(32, 38, 32 + math.cos(a) * 20, 38 + math.sin(a) * 26, 3, 1), MOSS, style="cylinder", sep=True)
    elif kind == "hub_screen":
        c.paint(c.rect(8, 10, 48, 32, 3), GUNMETAL, style="bevel")
        c.paint(c.rect(11, 13, 42, 26, 2), ["#03141c", "#06222e", "#0a3444"], style="flat")
        for i in range(4):
            c.flat(c.rect(14, 16 + i * 5, 10 + (i * 11) % 28, 2), mix(NEON["magenta"], "#06222e", 0.2 * i))
        c.paint(c.rect(28, 42, 8, 12), GUNMETAL, style="cylinder")
        c.paint(c.ellipse(32, 56, 12, 3), GUNMETAL, style="dome")
    c.outline(OUTLINE)
    return c.image()


# ---------------------------------------------------------------- atlas

def paint(tile: dict, index: int) -> Image.Image:
    art = tile["art"]
    if art.startswith("wall_top:"):
        return wall_top(art.split(":")[1], index)
    if art.startswith("wall_face:"):
        return wall_face(art.split(":")[1], index)
    if art.startswith("hazard:"):
        return hazard(art.split(":")[1], index)
    if art.startswith("decor:"):
        return decor(art.split(":")[1])
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
        count = max(int(tile.get("variants", 1)), int(tile.get("frames", 1)))
        for k in range(count):
            cell = (x + k, y)
            if cell in used or x + k >= cols or y >= rows:
                raise SystemExit("tiles: atlas cell %s of %s overlaps or is outside" % (cell, tile["id"]))
            used.add(cell)
            atlas.paste(paint(tile, k), (cell[0] * T, cell[1] * T))
    return atlas
