"""Projectiles (near-white, tinted in game by the shot colour), the animated lightning strip,
pickups, powerups, the drop shadow and the cursor — all at 16-px scale (shown x4).
Projectiles face right (+x); the game rotates them."""
from __future__ import annotations

import math

import numpy as np

from palette import BRASS, CHROME, GLOW, GUNMETAL, NEON, OUTLINE
from pixlib import Canvas, hex_rgb, mix

WHITE = ["#4a4a5a", "#8a8a9e", "#c8c8dc", "#ffffff"]
TAU = math.tau


def px(c: Canvas, pts, color: str) -> None:
    for x, y in pts:
        x, y = int(round(x)), int(round(y))
        if 0 <= x < c.w and 0 <= y < c.h:
            c.rgb[y, x] = hex_rgb(color)
            c.alpha[y, x] = True


def bolt(c, f, n):
    px(c, [(1, 1), (2, 1)], WHITE[1]); px(c, [(3 + k, 1) for k in range(4)], WHITE[3])
    px(c, [(2 + k, 0) for k in range(3)] + [(2 + k, 2) for k in range(3)], WHITE[2])


def lance(c, f, n):
    px(c, [(k, 2) for k in range(1, 9)], WHITE[3])
    px(c, [(k, 1) for k in range(2, 8)] + [(k, 3) for k in range(2, 8)], WHITE[2])
    px(c, [(9, 2), (10, 2), (9, 1), (9, 3)], WHITE[3])
    px(c, [(0, 2)], WHITE[1])


def orb(c, f, n):
    c.paint(c.circle(2.5, 2.5, 2.4), WHITE[1:], style="dome", dither=0.0)
    px(c, [(1, 1)], "#ffffff")


def pellet(c, f, n):
    px(c, [(1, 0), (0, 1), (1, 1), (2, 1), (1, 2)], WHITE[3])


def needle(c, f, n):
    px(c, [(k, 1) for k in range(7)], WHITE[3]); px(c, [(1, 0), (2, 0), (1, 2), (2, 2)], WHITE[1])


def rocket(c, f, n):
    px(c, [(0, 2), (1, 2)] + ([(0, 1), (0, 3)] if f % 2 else []), WHITE[3])
    px(c, [(2 + k, 2) for k in range(5)] + [(2 + k, 1) for k in range(4)] + [(2 + k, 3) for k in range(4)], WHITE[1])
    px(c, [(7, 2), (6, 1), (6, 3)], WHITE[2])
    px(c, [(3, 0), (3, 4)], WHITE[0])


def blade(c, f, n):
    s = 4
    for k in range(4):
        a = TAU * k / 4 + f * TAU / 16
        px(c, [(s + math.cos(a) * r, s + math.sin(a) * r) for r in (1, 2, 3, 4)], WHITE[3] if k % 2 else WHITE[2])
    px(c, [(s, s)], WHITE[0])


def slash(c, f, n):
    """Melee crescent (24 x 24): arc of radius ~11 around the centre, +-60 deg."""
    s = 12
    for r, col in ((11, WHITE[3]), (10, WHITE[2]), (9, WHITE[1])):
        for k in range(-30, 31, 2):
            a = math.radians(k * 2)
            px(c, [(s + math.cos(a) * r, s + math.sin(a) * r)], col)


def spark(c, f, n):
    s = 4
    r = 1 + f
    for k in range(8):
        a = TAU * k / 8
        length = r if k % 2 == 0 else r * 0.6
        px(c, [(s + math.cos(a) * length, s + math.sin(a) * length)], WHITE[3] if f < 2 else WHITE[1])
    if f < 2:
        px(c, [(s, s)], "#ffffff")


def lightning(c, f, n):
    """Seamless lightning strip (16 x 7), 4 frames: jagged bright core, dim halo, forks.
    The game tiles it along a Line2D and swaps frames, so the bolt crackles."""
    rng = np.random.default_rng(300 + f)
    ys = [3]
    for _ in range(15):
        ys.append(int(min(5, max(1, ys[-1] + rng.integers(-1, 2)))))
    ys[-1] = 3
    for x, y in enumerate(ys):
        px(c, [(x, y - 1), (x, y + 1)], WHITE[1])
    for x, y in enumerate(ys):
        px(c, [(x, y)], "#ffffff")
    fork = int(rng.integers(4, 11))
    fy = ys[fork]
    for k in range(1, 4):
        py = fy + (k if f % 2 else -k)
        if 0 <= py < c.h:
            px(c, [(fork + k, py)], WHITE[2])


# ---------------------------------------------------------------- pickups

def xp(c, f, n):
    c.paint(c.poly([(2.5, 0.5), (4.5, 3.5), (2.5, 6.5), (0.5, 3.5)]), GLOW["lime"], style="bevel", dither=0.0)
    if f in (1, 2):
        px(c, [(2, 2 + f)], "#ffffff")


def currency(c, f, n):
    w = [2.5, 1.8, 0.8, 1.8][f % 4]
    c.paint(c.ellipse(3, 3, w, 2.6), BRASS[1:] + [NEON["amber"]], style="dome", dither=0.0)
    if w > 1:
        px(c, [(3, 2), (3, 3)], mix(NEON["amber"], "#ffffff", 0.4))


def heal(c, f, n):
    r = 3.2 + (f % 2) * 0.3
    c.paint(c.circle(3.5, 3.5, r), GLOW["magenta"], style="dome", dither=0.0)
    px(c, [(3, 2), (3, 3), (3, 4), (2, 3), (4, 3)], "#ffffff")


def powerup(kind: str):
    col = {"power_damage": "magenta", "power_haste": "cyan", "power_magnet": "lime", "power_shield": "blue", "power_heal": "white"}[kind]

    def painter(c, f, n):
        b = [0, -1, -1, 0][f % 4]
        c.paint(c.circle(6, 6 + b, 5.4), GUNMETAL, style="dome", dither=0.0)
        c.flat(c.ring(6, 6 + b, 5, 1), GLOW[col][2] if f % 2 == 0 else GLOW[col][1])
        y = 6 + b
        if kind == "power_damage":
            px(c, [(7, y - 3), (6, y - 2), (5, y - 1), (6, y - 1), (7, y - 1), (6, y), (5, y + 1), (5, y + 2)], NEON[col])
        elif kind == "power_haste":
            px(c, [(4, y - 2), (5, y - 1), (6, y), (5, y + 1), (4, y + 2), (7, y - 2), (8, y - 1), (9, y), (8, y + 1), (7, y + 2)], NEON[col])
        elif kind == "power_magnet":
            px(c, [(4, y - 2), (4, y - 1), (4, y), (5, y + 1), (6, y + 1), (7, y + 1), (8, y), (8, y - 1), (8, y - 2)], NEON[col])
            px(c, [(4, y - 2), (8, y - 2)], NEON["red"])
        elif kind == "power_shield":
            px(c, [(4, y - 2), (5, y - 2), (6, y - 2), (7, y - 2), (8, y - 2), (4, y - 1), (8, y - 1), (4, y), (8, y), (5, y + 1), (7, y + 1), (6, y + 2)], NEON[col])
        else:
            px(c, [(6, y - 2), (6, y - 1), (6, y), (6, y + 1), (6, y + 2), (4, y), (5, y), (7, y), (8, y)], NEON["red"])
        c.outline(OUTLINE)
    return painter


def shadow(c, f, n):
    c.flat(c.ellipse(c.w / 2, c.h / 2, c.w / 2 - 0.5, c.h / 2 - 0.5), "#020104")


def cursor(c, f, n):
    px(c, [(5, 1), (5, 2), (5, 8), (5, 9), (1, 5), (2, 5), (8, 5), (9, 5)], NEON["cyan"])
    px(c, [(3, 3), (7, 3), (3, 7), (7, 7)], NEON["cyan"])
    px(c, [(5, 5)], NEON["magenta"])
    c.outline(OUTLINE)


def _outlined(painter):
    def wrapped(c, f, n):
        painter(c, f, n)
        c.outline(OUTLINE)
    return wrapped


# id -> (w, h, frames, painter); bullets are drawn near-white for tinting.
FX = {
    "bolt": (8, 3, 1, bolt), "lance": (11, 5, 1, lance), "orb": (5, 5, 1, orb), "pellet": (3, 3, 1, pellet),
    "needle": (7, 3, 1, needle), "rocket": (8, 5, 2, rocket), "blade": (9, 9, 4, blade), "slash": (24, 24, 1, slash),
    "spark": (9, 9, 4, spark), "lightning": (16, 7, 4, lightning),
    "xp": (7, 9, 4, _outlined(lambda c, f, n: _shift(xp, c, f, n))), "currency": (8, 8, 4, _outlined(lambda c, f, n: _shift(currency, c, f, n))),
    "heal": (9, 9, 2, _outlined(lambda c, f, n: _shift(heal, c, f, n))),
    "power_damage": (13, 13, 4, powerup("power_damage")), "power_haste": (13, 13, 4, powerup("power_haste")),
    "power_magnet": (13, 13, 4, powerup("power_magnet")), "power_shield": (13, 13, 4, powerup("power_shield")),
    "power_heal": (13, 13, 4, powerup("power_heal")),
    "shadow": (12, 5, 1, shadow), "cursor": (11, 11, 1, cursor),
}


def _shift(painter, c: Canvas, f: int, n: int) -> None:
    """Paint on a canvas 1 px smaller, then move it in by 1 px so the outline fits."""
    inner = Canvas(c.w - 2, c.h - 2)
    painter(inner, f, n)
    c.rgb[1:-1, 1:-1] = inner.rgb
    c.alpha[1:-1, 1:-1] = inner.alpha
    c.dark[1:-1, 1:-1] = inner.dark


def frames(fx_id: str) -> list:
    w, h, count, painter = FX[fx_id]
    out = []
    for f in range(count):
        c = Canvas(w, h)
        painter(c, f, count)
        out.append(c.image())
    return out
