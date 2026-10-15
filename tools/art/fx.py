"""Projectiles (near-white, tinted in game by the shot colour), pickups, powerups, the drop
shadow and the mouse cursor. Projectiles face right (+x); the game rotates them."""
from __future__ import annotations

import math

import numpy as np

from palette import BRASS, CHROME, GLOW, GUNMETAL, NEON, OUTLINE, STEEL
from pixlib import Canvas, mix

WHITE = ["#3a3a48", "#7a7a8e", "#c4c4d4", "#ececff", "#ffffff"]
TAU = math.tau


def bolt(c: Canvas, f: int, n: int) -> None:
    h = c.h / 2
    c.paint(c.capsule(3, h, c.w - 6, h, 1.0, 3.5), WHITE, style="cylinder", dither=0.2)
    c.flat(c.capsule(c.w - 14, h, c.w - 6, h, 0.6, 1.6), "#ffffff")


def lance(c: Canvas, f: int, n: int) -> None:
    h = c.h / 2
    c.paint(c.capsule(4, h, c.w - 14, h, 1.0, 5), WHITE, style="cylinder", dither=0.2)
    c.paint(c.poly([(c.w - 16, h - 6), (c.w - 2, h), (c.w - 16, h + 6)]), WHITE, style="bevel")
    c.flat(c.line(10, h, c.w - 6, h, 1.5), "#ffffff")


def orb(c: Canvas, f: int, n: int) -> None:
    s = c.w / 2
    c.paint(c.circle(s, s, s - 2), WHITE[1:], style="dome", dither=0.2)
    c.flat(c.circle(s - 1, s - 1, (s - 2) * 0.45), "#ffffff")


def pellet(c: Canvas, f: int, n: int) -> None:
    s = c.w / 2
    c.paint(c.circle(s, s, s - 2), WHITE[2:], style="dome", dither=0.0)


def needle(c: Canvas, f: int, n: int) -> None:
    h = c.h / 2
    c.paint(c.poly([(2, h), (c.w * 0.4, h - 2.5), (c.w - 2, h), (c.w * 0.4, h + 2.5)]), WHITE[1:], style="bevel")
    c.flat(c.line(6, h, c.w - 4, h, 1), "#ffffff")


def rocket(c: Canvas, f: int, n: int) -> None:
    h = c.h / 2
    flame = 4 + (f % 2) * 3
    c.paint(c.capsule(2, h, 2 + flame, h, 1, 3), WHITE[2:], style="dome")
    c.paint(c.rect(8, h - 3.5, c.w - 16, 7, 3), WHITE[:4], style="cylinder", sep=True)
    c.paint(c.poly([(c.w - 9, h - 3.5), (c.w - 2, h), (c.w - 9, h + 3.5)]), WHITE, style="bevel", sep=True)
    for side in (-1, 1):
        c.paint(c.poly([(9, h + side * 3), (14, h + side * 3), (9, h + side * 7)]), WHITE[:4], style="flat")
    c.outline(OUTLINE)


def blade(c: Canvas, f: int, n: int) -> None:
    s = c.w / 2
    for k in range(4):
        a = TAU * k / 4 + f / n * TAU / 4
        tip = (s + math.cos(a) * (s - 2), s + math.sin(a) * (s - 2))
        side = (s + math.cos(a + 0.9) * 6, s + math.sin(a + 0.9) * 6)
        c.paint(c.poly([(s, s), side, tip]), WHITE, style="bevel")
    c.paint(c.circle(s, s, 4), WHITE[:3], style="dome", sep=True)
    c.outline(OUTLINE)


def slash(c: Canvas, f: int, n: int) -> None:
    """Crescent for melee arcs: radius ~ canvas/2, opening +-60 deg around +x."""
    s = c.w / 2
    outer = c.circle(s, s, s - 2)
    inner = c.circle(s - 10, s, s - 8)
    cres = outer.minus(inner)
    ang = np.degrees(np.arctan2(c.Y - s, c.X - s))
    keep = np.abs(ang) <= 64
    cres.mask &= keep
    c.paint(cres, WHITE[1:], style="cylinder", dither=0.3)
    edge = c.ring(s, s, s - 3, 1.6)
    edge.mask &= keep
    c.flat(edge, "#ffffff")


def spark_fx(c: Canvas, f: int, n: int) -> None:
    """Hit spark burst: 4 frames growing and fading."""
    s = c.w / 2
    r = 3 + f * 3
    for k in range(8):
        a = TAU * k / 8 + (k % 2) * 0.2
        length = r * (1.0 if k % 2 == 0 else 0.6)
        c.flat(c.line(s + math.cos(a) * r * 0.4, s + math.sin(a) * r * 0.4, s + math.cos(a) * length, s + math.sin(a) * length, 1.5 if f < 2 else 1), "#ffffff" if f < 2 else "#c4c4d4")
    if f < 2:
        c.flat(c.circle(s, s, 3 - f), "#ffffff")


# ---------------------------------------------------------------- pickups

def xp(c: Canvas, f: int, n: int) -> None:
    s = c.w / 2
    pts = [(s, 2), (s + 6, s - 1), (s, c.h - 3), (s - 6, s - 1)]
    c.paint(c.poly(pts), GLOW["lime"][:4] + ["#f0ffd0"], style="bevel")
    c.flat(c.line(s, 4, s, c.h - 5, 1), mix(NEON["lime"], "#ffffff", 0.3))
    if f in (1, 2):
        c.flat(c.pixels([(int(s - 2 + f), 6 + f * 2)]), "#ffffff")
    c.outline(OUTLINE)


def currency(c: Canvas, f: int, n: int) -> None:
    s = c.w / 2
    wid = [6.5, 4.5, 1.6, 4.5][f % 4]
    c.paint(c.ellipse(s, s, wid, 6.5), BRASS[1:] + [NEON["amber"]], style="dome", dither=0.2)
    if wid > 3:
        c.flat(c.rect(s - 0.5, s - 3.5, 1.5, 7), mix(NEON["amber"], "#ffffff", 0.4))
    c.outline(OUTLINE)


def heal(c: Canvas, f: int, n: int) -> None:
    s = c.w / 2
    r = 7.5 + (f % 2) * 0.8
    c.paint(c.circle(s, s, r), GLOW["magenta"], style="dome", dither=0.3)
    c.flat(c.rect(s - 1.5, s - 5, 3, 10), "#ffffff")
    c.flat(c.rect(s - 5, s - 1.5, 10, 3), "#ffffff")
    c.outline(OUTLINE)


def _powerup_base(c: Canvas, f: int, col: str) -> float:
    s = c.w / 2
    b = [0, -1, -2, -1][f % 4]
    c.paint(c.circle(s, s + b, 15), GUNMETAL, style="dome")
    c.paint(c.ring(s, s + b, 14, 3), GLOW[col][:4], style="cylinder")
    c.paint(c.circle(s, s + b, 10), ["#0b0714", "#140c22", "#1e1430"], style="flat")
    return b


def powerup(kind: str):
    col = {"power_damage": "magenta", "power_haste": "cyan", "power_magnet": "lime", "power_shield": "blue", "power_heal": "white"}[kind]

    def painter(c: Canvas, f: int, n: int) -> None:
        s = c.w / 2
        b = _powerup_base(c, f, col)
        y = s + b
        if kind == "power_damage":
            c.paint(c.poly([(s + 2, y - 9), (s - 5, y + 1), (s, y + 1), (s - 2, y + 9), (s + 5, y - 2), (s, y - 2)]), GLOW[col], style="bevel")
        elif kind == "power_haste":
            for k in range(3):
                c.paint(c.poly([(s - 6 + k * 5, y - 7), (s - 1 + k * 5, y), (s - 6 + k * 5, y + 7), (s - 4 + k * 5, y)]), GLOW[col], style="bevel")
        elif kind == "power_magnet":
            c.paint(c.arc(s, y - 1, 6, 4, 0, 180), GLOW[col][1:], style="cylinder")
            c.paint(c.rect(s - 8, y - 8, 4, 7), GLOW["red"][1:], style="cylinder")
            c.paint(c.rect(s + 4, y - 8, 4, 7), CHROME[1:], style="cylinder")
        elif kind == "power_shield":
            c.paint(c.poly([(s - 7, y - 7), (s + 7, y - 7), (s + 6, y + 2), (s, y + 8), (s - 6, y + 2)]), GLOW[col], style="bevel")
            c.flat(c.line(s, y - 6, s, y + 6, 1), "#ffffff")
        else:
            c.paint(c.rect(s - 7, y - 5, 14, 11, 2), CHROME[1:], style="bevel")
            c.flat(c.rect(s - 1.5, y - 3.5, 3, 8), NEON["red"]); c.flat(c.rect(s - 4, y - 1, 8, 3), NEON["red"])
        c.outline(OUTLINE)
    return painter


def shadow(c: Canvas, f: int, n: int) -> None:
    c.flat(c.ellipse(c.w / 2, c.h / 2, c.w / 2 - 1, c.h / 2 - 1), "#05030a")


def cursor(c: Canvas, f: int, n: int) -> None:
    s = c.w / 2
    c.flat(c.ring(s, s, 9, 2), NEON["cyan"])
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        c.flat(c.line(s + dx * 5, s + dy * 5, s + dx * 14, s + dy * 14, 2), NEON["cyan"])
    c.flat(c.rect(s - 1, s - 1, 2, 2), NEON["magenta"])
    c.outline(OUTLINE)


# id -> (w, h, frames, painter); projectile sprites are drawn near-white for tinting.
FX = {
    "bolt": (32, 12, 1, bolt), "lance": (52, 18, 1, lance), "orb": (20, 20, 1, orb), "pellet": (12, 12, 1, pellet),
    "needle": (26, 9, 1, needle), "rocket": (30, 16, 2, rocket), "blade": (34, 34, 4, blade), "slash": (96, 96, 1, slash),
    "spark": (32, 32, 4, spark_fx),
    "xp": (16, 22, 4, xp), "currency": (18, 18, 4, currency), "heal": (22, 22, 2, heal),
    "power_damage": (40, 40, 4, powerup("power_damage")), "power_haste": (40, 40, 4, powerup("power_haste")),
    "power_magnet": (40, 40, 4, powerup("power_magnet")), "power_shield": (40, 40, 4, powerup("power_shield")),
    "power_heal": (40, 40, 4, powerup("power_heal")),
    "shadow": (32, 12, 1, shadow), "cursor": (36, 36, 1, cursor),
}


def frames(fx_id: str) -> list:
    w, h, count, painter = FX[fx_id]
    out = []
    for f in range(count):
        c = Canvas(w, h)
        painter(c, f, count)
        out.append(c.image())
    return out
