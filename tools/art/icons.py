"""64x64 icons for items, abilities and skill-tree nodes. Each icon draws the thing it names
(crit lens -> a lens, servo boots -> boots ...). Transparent background: the UI frames them."""
from __future__ import annotations

import math

from palette import (BONE, BRASS, CHROME, COAT, DARKCLOTH, GLASS, GLOW, GUNMETAL, LEATHER, MARBLE, MOSS,
                     NEON, OUTLINE, RUST, SKIN, STEEL, TINT, VOID)
from pixlib import Canvas, mix

TAU = math.tau
S = 64


# ---------------------------------------------------------------- motifs

def chip(c: Canvas, x, y, w, h, col: str, core: bool = True) -> None:
    for k in range(4):
        for side in (0, 1):
            px = x + 6 + k * (w - 12) / 3
            c.paint(c.rect(px - 1.5, y - 5 if side == 0 else y + h, 3, 5), BRASS[1:], style="cylinder")
            py = y + 6 + k * (h - 12) / 3
            c.paint(c.rect(x - 5 if side == 0 else x + w, py - 1.5, 5, 3), BRASS[1:], style="cylinder")
    c.paint(c.rect(x, y, w, h, 3), GUNMETAL, style="bevel", rim=NEON[col], rim_dir=(0.7, 0.7))
    if core:
        c.paint(c.rect(x + w * 0.25, y + h * 0.25, w * 0.5, h * 0.5, 2), GLOW[col], style="bevel", sep=True)


def heart(c: Canvas, cx, cy, r, colors) -> None:
    shape = c.circle(cx - r * 0.5, cy - r * 0.2, r * 0.58) | c.circle(cx + r * 0.5, cy - r * 0.2, r * 0.58) | \
        c.poly([(cx - r * 1.05, cy), (cx + r * 1.05, cy), (cx, cy + r * 1.05)])
    c.paint(shape, colors, style="dome")


def shield(c: Canvas, cx, cy, w, h, colors, rim=None) -> None:
    c.paint(c.poly([(cx - w / 2, cy - h / 2), (cx + w / 2, cy - h / 2), (cx + w / 2, cy), (cx, cy + h / 2), (cx - w / 2, cy)]),
            colors, style="bevel", rim=rim, rim_dir=(0.7, 0.7))


def bolt_sign(c: Canvas, cx, cy, size, colors) -> None:
    k = size / 10
    c.paint(c.poly([(cx + 2 * k, cy - 10 * k), (cx - 6 * k, cy + 1 * k), (cx - 0.5 * k, cy + 1 * k), (cx - 3 * k, cy + 10 * k),
                    (cx + 6 * k, cy - 2 * k), (cx + 0.5 * k, cy - 2 * k)]), colors, style="bevel")


def gear(c: Canvas, cx, cy, r, colors, teeth=8) -> None:
    shape = c.circle(cx, cy, r * 0.78)
    for k in range(teeth):
        a = TAU * k / teeth
        shape = shape | c.rect(cx + math.cos(a) * r * 0.85 - r * 0.15, cy + math.sin(a) * r * 0.85 - r * 0.15, r * 0.3, r * 0.3)
    c.paint(shape, colors, style="bevel")
    c.erase(c.circle(cx, cy, r * 0.3))


def coin(c: Canvas, cx, cy, r, wobble=1.0) -> None:
    c.paint(c.ellipse(cx, cy + 2, r * wobble, r), BRASS[:3], style="flat")
    c.paint(c.ellipse(cx, cy, r * wobble, r), BRASS[1:] + [NEON["amber"]], style="dome")
    c.flat(c.ring(cx, cy, r * 0.65, 1), BRASS[1])
    c.flat(c.rect(cx - 1, cy - r * 0.4, 2, r * 0.8), mix(NEON["amber"], "#ffffff", 0.3))


def magnet(c: Canvas, cx, cy, r, col="lime") -> None:
    c.paint(c.arc(cx, cy, r, r * 0.55, 0, 180), GLOW[col][:4], style="cylinder")
    c.paint(c.rect(cx - r - r * 0.28, cy - r * 0.9, r * 0.56, r * 0.95), GLOW["red"][:4], style="cylinder", sep=True)
    c.paint(c.rect(cx + r - r * 0.28, cy - r * 0.9, r * 0.56, r * 0.95), CHROME[1:], style="cylinder", sep=True)


def boot(c: Canvas, cx, cy, col="cyan") -> None:
    c.paint(c.rect(cx - 12, cy - 22, 16, 26, 4), GUNMETAL, style="bevel")
    c.paint(c.poly([(cx - 14, cy + 2), (cx + 4, cy + 2), (cx + 18, cy + 8), (cx + 18, cy + 14), (cx - 14, cy + 14)]), STEEL, style="bevel", sep=True)
    c.paint(c.rect(cx - 15, cy + 13, 34, 4, 1), GUNMETAL, style="bevel", sep=True)
    for k in range(3):
        c.flat(c.rect(cx - 10, cy - 18 + k * 7, 12, 2), GLOW[col][2])
    c.paint(c.ellipse(cx - 14, cy - 6, 3, 6), GLOW[col], style="dome")


def flask(c: Canvas, cx, cy, col, liquid=0.65) -> None:
    body = c.circle(cx, cy + 6, 15) | c.rect(cx - 5, cy - 18, 10, 14)
    c.paint(body, GLASS[:3] + ["#2a4a6a"], style="dome")
    level = c.rect(cx - 20, cy + 6 - 15 + 30 * (1 - liquid), 40, 40).clip(c.circle(cx, cy + 6, 13))
    c.paint(level, GLOW[col], style="dome")
    c.paint(c.rect(cx - 7, cy - 22, 14, 6, 2), LEATHER[1:], style="bevel")
    c.flat(c.ellipse(cx - 6, cy + 1, 2.5, 4), "#e8fbff")


def battery(c: Canvas, cx, cy, w, h, col, bars=3) -> None:
    c.paint(c.rect(cx - w / 2, cy - h / 2, w, h, 3), GUNMETAL, style="bevel", rim=NEON[col], rim_dir=(0.7, 0.7))
    c.paint(c.rect(cx - w / 6, cy - h / 2 - 5, w / 3, 6, 1), STEEL, style="bevel")
    for k in range(bars):
        c.paint(c.rect(cx - w / 2 + 4, cy + h / 2 - 6 - k * (h - 8) / 4, w - 8, (h - 8) / 4 - 2, 1), GLOW[col][1:], style="bevel")


def crosshair(c: Canvas, cx, cy, r, col) -> None:
    c.flat(c.ring(cx, cy, r, 2.4), NEON[col])
    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
        c.flat(c.line(cx + dx * r * 0.45, cy + dy * r * 0.45, cx + dx * r * 1.35, cy + dy * r * 1.35, 2.4), NEON[col])
    c.flat(c.rect(cx - 1.5, cy - 1.5, 3, 3), "#ffffff")


def blade(c: Canvas, x0, y0, x1, y1, w, col) -> None:
    ang = math.atan2(y1 - y0, x1 - x0)
    nx, ny = -math.sin(ang) * w, math.cos(ang) * w
    c.paint(c.poly([(x0 + nx, y0 + ny), (x1, y1), (x0 - nx, y0 - ny)]), CHROME[1:], style="bevel")
    c.flat(c.line(x0, y0, x1, y1, 1), mix(NEON[col], "#ffffff", 0.3))


def hourglass(c: Canvas, cx, cy, col) -> None:
    c.paint(c.rect(cx - 15, cy - 22, 30, 5, 2), BRASS, style="bevel")
    c.paint(c.rect(cx - 15, cy + 17, 30, 5, 2), BRASS, style="bevel")
    glass = c.poly([(cx - 12, cy - 17), (cx + 12, cy - 17), (cx + 2, cy), (cx + 12, cy + 17), (cx - 12, cy + 17), (cx - 2, cy)])
    c.paint(glass, GLASS[:4], style="dome", sep=True)
    c.paint(c.poly([(cx - 9, cy + 16), (cx + 9, cy + 16), (cx, cy + 6)]), GLOW[col], style="bevel")
    c.paint(c.poly([(cx - 6, cy - 12), (cx + 6, cy - 12), (cx, cy - 4)]), GLOW[col], style="bevel")
    c.flat(c.line(cx, cy - 2, cx, cy + 8, 1), NEON[col])


def drone_motif(c: Canvas, cx, cy, r, col) -> None:
    for k in range(3):
        a = TAU * k / 3 - math.pi / 2
        c.paint(c.ellipse(cx + math.cos(a) * r, cy + math.sin(a) * r * 0.8, r * 0.45, r * 0.18), GUNMETAL, style="flat")
    c.paint(c.poly([(cx, cy - r * 0.8), (cx + r * 0.8, cy + r * 0.55), (cx - r * 0.8, cy + r * 0.55)]), GUNMETAL, style="bevel", rim=NEON[col], rim_dir=(0.7, 0.7))
    c.paint(c.circle(cx, cy + r * 0.1, r * 0.25), GLOW[col], style="dome")


def rings(c: Canvas, cx, cy, radii, col, width=2.0) -> None:
    for k, r in enumerate(radii):
        c.flat(c.ring(cx, cy, r, width), mix(NEON[col], "#0b0714", k * 0.25))


def arrow(c: Canvas, x0, y0, x1, y1, w, col) -> None:
    ang = math.atan2(y1 - y0, x1 - x0)
    c.paint(c.capsule(x0, y0, x1 - math.cos(ang) * 6, y1 - math.sin(ang) * 6, w / 2), GLOW[col][1:], style="cylinder")
    nx, ny = -math.sin(ang), math.cos(ang)
    c.paint(c.poly([(x1, y1), (x1 - math.cos(ang) * 10 + nx * 7, y1 - math.sin(ang) * 10 + ny * 7),
                    (x1 - math.cos(ang) * 10 - nx * 7, y1 - math.sin(ang) * 10 - ny * 7)]), GLOW[col][1:], style="bevel")


def crown(c: Canvas, cx, cy, w, colors) -> None:
    h = w * 0.6
    c.paint(c.poly([(cx - w / 2, cy + h / 2), (cx - w / 2, cy - h / 2), (cx - w / 4, cy), (cx, cy - h * 0.7), (cx + w / 4, cy),
                    (cx + w / 2, cy - h / 2), (cx + w / 2, cy + h / 2)]), colors, style="bevel")


def fang(c: Canvas, cx, cy, h, colors) -> None:
    c.paint(c.poly([(cx - h * 0.35, cy - h / 2), (cx + h * 0.35, cy - h / 2), (cx + h * 0.15, cy + h * 0.2), (cx, cy + h / 2), (cx - h * 0.2, cy)]), colors, style="dome")


def bullet(c: Canvas, cx, cy, h, col) -> None:
    c.paint(c.rect(cx - 4, cy - h / 2 + 8, 8, h - 8, 1), BRASS, style="cylinder")
    c.paint(c.ellipse(cx, cy - h / 2 + 8, 4, 8).clip(c.rect(cx - 5, cy - h / 2, 10, 8)), GLOW[col], style="dome")


def card(c: Canvas, cx, cy, w, h, col, angle_shift=0.0) -> None:
    c.paint(c.rect(cx - w / 2, cy - h / 2, w, h, 3), ["#0c0a16", "#1a1630", "#2a2448", "#3a3460"], style="bevel", rim=NEON[col], rim_dir=(0.7, 0.7))
    c.paint(c.circle(cx, cy, w * 0.22), GLOW[col], style="dome")


def done(c: Canvas) -> None:
    c.outline(OUTLINE)


# ---------------------------------------------------------------- items

def i_damage_chip(c):
    chip(c, 14, 14, 36, 36, "magenta")
    c.flat(c.rect(30, 25, 4, 14), "#ffffff"); c.flat(c.rect(25, 30, 14, 4), "#ffffff")


def i_crit_lens(c):
    c.paint(c.capsule(41, 43, 54, 56, 5, 6), GUNMETAL, style="cylinder")
    c.paint(c.ring(29, 29, 19, 7), CHROME, style="cylinder", rim=NEON["magenta"], rim_dir=(1, 1))
    c.paint(c.circle(29, 29, 15.5), GLASS, style="dome", sep=True)
    c.flat(c.ellipse(23, 23, 4, 2.5, -35), "#e8fbff")
    crosshair(c, 29, 29, 7, "red")


def i_servo_boots(c):
    boot(c, 30, 36, "cyan")


def i_regen_gel(c):
    flask(c, 32, 34, "green", 0.7)
    heart(c, 32, 38, 6, ["#0a3a1a", "#1a8a3a", NEON["green"], "#c0ffd8"])


def i_mana_coil(c):
    for k in range(6):
        c.paint(c.ellipse(32, 14 + k * 7, 15, 4.5), GLOW["blue"][:4] if k % 2 else GLOW["cyan"][:4], style="dome", sep=True)
    c.paint(c.rect(29, 8, 6, 50, 2), GUNMETAL, style="cylinder", under=True)
    c.paint(c.rect(22, 54, 20, 6, 2), STEEL, style="bevel")
    c.paint(c.rect(22, 4, 20, 6, 2), STEEL, style="bevel")


def i_magnet_coil(c):
    magnet(c, 32, 30, 16, "lime")
    for k in range(3):
        c.flat(c.ring(32, 30, 22 + k * 4, 1).clip(c.rect(0, 40, 64, 24)), mix(NEON["lime"], "#0b0714", k * 0.3))


def i_thorn_mesh(c):
    c.paint(c.rect(10, 10, 44, 44, 4), GUNMETAL[:3], style="flat")
    for k in range(5):
        c.flat(c.line(10 + k * 11, 10, 10 + k * 11, 54, 2), CHROME[3])
        c.flat(c.line(10, 10 + k * 11, 54, 10 + k * 11, 2), CHROME[3])
    for k in range(5):
        for j in range(5):
            if (k + j) % 2 == 0:
                c.paint(c.poly([(10 + k * 11, 10 + j * 11 - 5), (10 + k * 11 + 3, 10 + j * 11), (10 + k * 11 - 3, 10 + j * 11)]), GLOW["orange"][1:], style="bevel")


def i_leech_fang(c):
    c.paint(c.arc(32, 14, 22, 8, 20, 160), ["#3a0a14", "#6a1422", "#8a1e2e", "#a82a3a"], style="cylinder")
    for x, h in ((20, 30), (44, 30)):
        c.paint(c.poly([(x - 7, 20), (x + 7, 20), (x + 2, 20 + h * 0.7), (x, 20 + h), (x - 3, 20 + h * 0.6)]), BONE, style="dome", sep=True)
    c.paint(c.capsule(32, 22, 32, 30, 3, 4), BONE, style="dome", sep=True)
    for x in (20, 44):
        c.paint(c.capsule(x, 52, x, 58, 2, 3), GLOW["red"], style="dome")


def i_static_charm(c):
    c.flat(c.line(20, 4, 32, 14, 2), CHROME[2]); c.flat(c.line(44, 4, 32, 14, 2), CHROME[2])
    c.paint(c.poly([(32, 12), (52, 32), (32, 58), (12, 32)]), BRASS, style="bevel", rim=NEON["cyan"], rim_dir=(0.7, 0.7))
    c.paint(c.poly([(32, 20), (44, 32), (32, 50), (20, 32)]), ["#05030a", "#0b0714", "#140c22"], style="flat", sep=True)
    bolt_sign(c, 32, 34, 13, GLOW["cyan"])


def i_kill_battery(c):
    battery(c, 32, 34, 30, 44, "magenta", 3)
    c.paint(c.circle(32, 22, 6), BONE, style="dome", sep=True)
    c.flat(c.rect(29, 21, 2, 2), "#05030a"); c.flat(c.rect(33, 21, 2, 2), "#05030a")


def i_greed_module(c):
    chip(c, 12, 18, 40, 30, "amber", core=False)
    coin(c, 32, 33, 10)


def i_plasma_rounds(c):
    for k, x in enumerate((20, 32, 44)):
        bullet(c, x, 34 + (k % 2) * 4, 40, "orange")
        c.paint(c.ellipse(x, 12 + (k % 2) * 4, 3, 5), GLOW["amber"][2:], style="dome")


def i_volatile_core(c):
    c.paint(c.circle(32, 32, 20), GLOW["orange"], style="dome")
    for line in (((20, 22), (28, 30), (24, 40)), ((40, 18), (36, 30), (44, 38)), ((30, 44), (36, 36))):
        for a, b in zip(line, line[1:]):
            c.flat(c.line(*a, *b, 2), "#ffffff")
    c.paint(c.ring(32, 32, 24, 3), STEEL, style="cylinder")
    for k in range(4):
        a = TAU * k / 4 + 0.4
        c.paint(c.rect(32 + math.cos(a) * 24 - 3, 32 + math.sin(a) * 24 - 3, 6, 6, 1), GUNMETAL, style="bevel")


def i_vital_frame(c):
    c.paint(c.rect(18, 10, 28, 44, 8), STEEL, style="bevel", rim=NEON["green"], rim_dir=(0.7, 0.7))
    for k in range(4):
        c.flat(c.rect(14, 18 + k * 8, 36, 3), CHROME[2])
        c.flat(c.rect(14, 21 + k * 8, 36, 1), CHROME[0])
    heart(c, 32, 30, 8, ["#3a0a14", "#8a1428", NEON["red"], "#ffb0b8"])


def i_chrono_chip(c):
    chip(c, 12, 12, 40, 40, "cyan", core=False)
    c.paint(c.circle(32, 32, 13), ["#e0e4f4", "#c4c8dc", "#f0f2ff"], style="dome", sep=True)
    c.flat(c.ring(32, 32, 13, 1.5), NEON["cyan"])
    c.flat(c.line(32, 32, 32, 23, 2), "#0b0714"); c.flat(c.line(32, 32, 39, 35, 2), "#0b0714")


def i_scope_chip(c):
    c.paint(c.capsule(10, 32, 54, 32, 7, 9), GUNMETAL, style="cylinder", rim=NEON["cyan"], rim_dir=(0, 1))
    c.paint(c.rect(26, 18, 10, 8, 2), STEEL, style="bevel")
    c.paint(c.ellipse(54, 32, 4, 9), GLASS, style="dome", sep=True)
    c.paint(c.rect(14, 26, 6, 12, 1), STEEL[1:], style="bevel", sep=True)
    c.flat(c.rect(24, 36, 20, 2), NEON["cyan"])


def i_kinetic_wraps(c):
    c.paint(c.rect(22, 34, 22, 26, 6), SKIN, style="bevel")
    for k in range(4):
        c.paint(c.rect(14 + k * 9, 10 + (k in (1, 2)) * -2, 10, 22, 4), SKIN, style="bevel", sep=True)
    c.paint(c.rect(10, 22, 40, 18, 7), SKIN, style="bevel", sep=True)
    for k in range(3):
        c.paint(c.rect(9, 18 + k * 7, 42, 5, 2), ["#5a5070", "#9a90b0", "#d4cce4"], style="cylinder", sep=True)
    c.paint(c.rect(20, 42, 26, 5, 2), ["#5a5070", "#9a90b0", "#d4cce4"], style="cylinder", sep=True)
    c.flat(c.rect(9, 25, 42, 2), NEON["magenta"])
    for k in range(3):
        c.flat(c.line(52, 16 + k * 10, 62, 12 + k * 10, 2), mix(NEON["magenta"], "#0b0714", 0.2 * k))


def i_signal_amplifier(c):
    c.paint(c.rect(29, 34, 6, 22), GUNMETAL, style="cylinder")
    c.paint(c.rect(18, 54, 28, 6, 2), STEEL, style="bevel")
    c.paint(c.ellipse(32, 26, 16, 10, -20), CHROME, style="dome", rim=NEON["lime"], rim_dir=(0.7, 0.7))
    c.paint(c.circle(34, 24, 3), GLOW["lime"], style="dome")
    for k in range(3):
        c.flat(c.arc(40, 18, 8 + k * 6, 2, 270, 360), mix(NEON["lime"], "#0b0714", k * 0.25))


def i_overclock_core(c):
    chip(c, 14, 20, 36, 32, "orange")
    for k, x in enumerate((20, 32, 44)):
        c.paint(c.poly([(x - 5, 18), (x, 4 + (k % 2) * 4), (x + 5, 18)]), GLOW["orange"], style="dome")


def i_assassin_module(c):
    blade(c, 18, 46, 50, 12, 5, "magenta")
    c.paint(c.rect(12, 44, 14, 6, 2), GUNMETAL, style="bevel", sep=True)
    c.paint(c.capsule(10, 54, 18, 46, 3), LEATHER, style="cylinder")
    crosshair(c, 44, 44, 8, "red")


def i_vampire_engine(c):
    c.paint(c.rect(12, 18, 40, 32, 6), RUST, style="bevel", rim=NEON["red"], rim_dir=(0.7, 0.7))
    heart(c, 32, 32, 10, ["#3a0a14", "#8a1428", NEON["red"], "#ffb0b8"])
    for x in (22, 42):
        fang(c, x, 52, 12, BONE)
    for x in (16, 28, 40):
        c.paint(c.rect(x, 10, 8, 9, 1), GUNMETAL, style="bevel")


def i_storm_relay(c):
    c.paint(c.poly([(32, 8), (44, 56), (20, 56)]), GUNMETAL, style="bevel")
    for k in range(4):
        c.flat(c.line(26 - k, 20 + k * 10, 38 + k, 20 + k * 10, 1.5), STEEL[3])
    c.paint(c.circle(32, 10, 5), GLOW["cyan"], style="dome")
    bolt_sign(c, 14, 22, 9, GLOW["cyan"]); bolt_sign(c, 50, 26, 9, GLOW["cyan"])


def i_phase_drive(c):
    for k in range(3):
        c.flat(c.ring(26 + k * 6, 32, 18 - k * 2, 3), mix(NEON["purple"], "#0b0714", 0.6 - k * 0.25))
    c.paint(c.ring(44, 32, 14, 6), CHROME, style="cylinder", rim=NEON["purple"], rim_dir=(0.7, 0.7))
    c.paint(c.circle(44, 32, 9), VOID[::-1], style="dome")
    c.paint(c.circle(44, 32, 4), GLOW["white"], style="dome")


def _broken_chain(c, col):
    for k, (x, y) in enumerate(((14, 50), (26, 38))):
        c.paint(c.ring(x, y, 7, 4), CHROME, style="cylinder")
    c.paint(c.ring(46, 18, 7, 4), CHROME, style="cylinder")
    for k in range(4):
        a = TAU * k / 4 + 0.6
        c.flat(c.line(36, 28, 36 + math.cos(a) * 9, 28 + math.sin(a) * 9, 2), NEON[col])


def i_limit_break_ability(c):
    _broken_chain(c, "amber")
    c.paint(c.rect(34, 34, 24, 24, 4), GUNMETAL, style="bevel", rim=NEON["amber"], rim_dir=(0.7, 0.7))
    c.flat(c.rect(42, 39, 3, 14), NEON["amber"]); c.flat(c.rect(42, 39, 8, 3), NEON["amber"])
    c.flat(c.rect(42, 45, 8, 2), NEON["amber"]); c.flat(c.rect(42, 51, 8, 2), NEON["amber"]); c.flat(c.rect(49, 41, 2, 4), NEON["amber"]); c.flat(c.rect(49, 47, 2, 4), NEON["amber"])


def i_limit_break_item(c):
    _broken_chain(c, "amber")
    c.paint(c.rect(34, 34, 24, 24, 4), GUNMETAL, style="bevel", rim=NEON["amber"], rim_dir=(0.7, 0.7))
    c.flat(c.rect(40, 40, 12, 3), NEON["amber"]); c.flat(c.line(51, 42, 44, 54, 3), NEON["amber"])


def i_nano_heal(c):
    c.paint(c.rect(10, 16, 44, 36, 6), ["#3a0a1a", "#7a1838", "#b02452", "#d03468"], style="bevel", rim=NEON["magenta"], rim_dir=(0.7, 0.7))
    c.paint(c.rect(24, 10, 16, 8, 3), STEEL, style="bevel")
    c.flat(c.rect(29, 24, 6, 20), "#ffffff"); c.flat(c.rect(22, 31, 20, 6), "#ffffff")
    for x, y in ((14, 46), (50, 22), (48, 48)):
        c.flat(c.rect(x, y, 2, 2), NEON["cyan"])


def i_mana_cell(c):
    battery(c, 32, 34, 26, 44, "blue", 4)
    c.flat(c.rect(26, 22, 12, 2), NEON["cyan"])


def i_emp_grenade(c):
    rings(c, 32, 36, (24, 28), "blue", 1.5)
    c.paint(c.circle(32, 36, 15), GUNMETAL, style="dome", rim=NEON["blue"], rim_dir=(0.7, 0.7))
    c.flat(c.rect(18, 34, 28, 3), NEON["blue"])
    c.paint(c.rect(26, 14, 12, 8, 2), STEEL, style="bevel")
    c.paint(c.ring(42, 14, 4, 2), CHROME, style="cylinder")


def i_magnet_pulse(c):
    rings(c, 32, 30, (12, 20, 28), "lime", 1.5)
    magnet(c, 32, 30, 11, "lime")


def i_phase_cloak(c):
    c.paint(c.poly([(32, 8), (50, 22), (54, 56), (10, 56), (14, 22)]), GLOW["purple"][:3] + ["#7a4ab8"], style="bevel", rim=NEON["purple"], rim_dir=(0.7, 0.7))
    c.paint(c.ellipse(32, 24, 10, 11), ["#05030a", "#0b0714", "#140c22"], style="flat", sep=True)
    c.flat(c.rect(26, 24, 4, 2), NEON["white"]); c.flat(c.rect(34, 24, 4, 2), NEON["white"])
    for y in range(36, 56, 6):
        c.flat(c.rect(14, y, 36, 1), mix(NEON["purple"], "#0b0714", 0.4))


def i_holo_barrier(c):
    for k in range(7):
        a = TAU * k / 6
        x, y = (32, 32) if k == 6 else (32 + math.cos(a) * 16, 32 + math.sin(a) * 16)
        hexagon = [(x + math.cos(TAU * j / 6 + TAU / 12) * 9, y + math.sin(TAU * j / 6 + TAU / 12) * 9) for j in range(6)]
        c.paint(c.poly(hexagon), GLOW["blue"][:3] + ["#5aa0ff", "#a0d0ff"], style="bevel", sep=True)


def i_orbital_strike(c):
    c.paint(c.rect(27, 6, 10, 10, 2), STEEL, style="bevel")
    c.paint(c.rect(10, 9, 15, 5, 1), GLOW["blue"][:3], style="flat"); c.paint(c.rect(39, 9, 15, 5, 1), GLOW["blue"][:3], style="flat")
    c.paint(c.poly([(28, 18), (36, 18), (44, 54), (20, 54)]), GLOW["white"][1:], style="cylinder")
    c.flat(c.rect(30, 18, 4, 36), "#ffffff")
    rings(c, 32, 56, (8,), "amber", 2)


# ---------------------------------------------------------------- abilities

def a_piercing_shot(c):
    for k in range(3):
        c.paint(c.rect(18 + k * 14, 20 + k * 2, 6, 24, 2), TINT["magenta"], style="bevel")
    c.paint(c.capsule(4, 32, 50, 32, 2, 5), GLOW["cyan"], style="cylinder")
    c.paint(c.poly([(48, 24), (62, 32), (48, 40)]), GLOW["cyan"], style="bevel")


def a_rail_volley(c):
    for a in (-0.35, 0, 0.35):
        c.paint(c.capsule(10, 32, 10 + math.cos(a) * 46, 32 + math.sin(a) * 46, 1.5, 4), GLOW["white"][1:], style="cylinder")
    c.paint(c.rect(4, 26, 12, 12, 3), GUNMETAL, style="bevel")


def a_arc_chain(c):
    pts = [(10, 46), (24, 18), (38, 40), (54, 14)]
    for a, b in zip(pts, pts[1:]):
        mid = ((a[0] + b[0]) / 2 + 4, (a[1] + b[1]) / 2 - 3)
        c.flat(c.line(*a, *mid, 2.5), NEON["cyan"]); c.flat(c.line(*mid, *b, 2.5), NEON["cyan"])
    for p in pts:
        c.paint(c.circle(p[0], p[1], 5), GLOW["cyan"], style="dome")


def a_blink_strike(c):
    for k, alpha in enumerate((0.75, 0.5, 0.25)):
        c.flat(c.ellipse(14 + k * 8, 34, 5, 12), mix(NEON["magenta"], "#0b0714", alpha))
    c.paint(c.circle(46, 34, 14), GLOW["magenta"], style="dome")
    for k in range(8):
        a = TAU * k / 8
        c.flat(c.line(46 + math.cos(a) * 14, 34 + math.sin(a) * 14, 46 + math.cos(a) * 20, 34 + math.sin(a) * 20, 2), NEON["white"])


def a_whirl_slash(c):
    for k in range(3):
        a0 = k * 120 + 10
        c.paint(c.arc(32, 32, 20, 6, a0, a0 + 80), CHROME[1:], style="cylinder")
        c.flat(c.arc(32, 32, 23, 1.5, a0, a0 + 80), NEON["magenta"])
    c.paint(c.circle(32, 32, 7), GLOW["magenta"], style="dome")


def a_emp_pulse(c):
    rings(c, 32, 32, (10, 17, 24), "blue", 3)
    c.paint(c.circle(32, 32, 6), GLOW["blue"], style="dome")
    bolt_sign(c, 32, 32, 7, GLOW["white"])


def a_deploy_drone(c):
    drone_motif(c, 30, 36, 24, "lime")
    c.flat(c.rect(50, 4, 5, 16), NEON["lime"]); c.flat(c.rect(44, 10, 17, 5), NEON["lime"])


def a_swarm_missiles(c):
    for k, (x, y, a) in enumerate(((14, 50, -0.9), (30, 46, -1.2), (46, 48, -1.6))):
        tx, ty = x + math.cos(a) * 30, y + math.sin(a) * 30
        c.flat(c.line(x, y + 8, x, y, 2), mix(NEON["lime"], "#0b0714", 0.4))
        c.paint(c.capsule(x, y, tx, ty, 3, 4), STEEL, style="cylinder")
        c.paint(c.circle(tx, ty, 3.5), GLOW["lime"], style="dome")


def a_orbit_blades(c):
    c.flat(c.ring(32, 32, 20, 1), mix(NEON["white"], "#0b0714", 0.5))
    for k in range(3):
        a = TAU * k / 3
        x, y = 32 + math.cos(a) * 20, 32 + math.sin(a) * 20
        tx, ty = -math.sin(a), math.cos(a)
        blade(c, x - tx * 9, y - ty * 9, x + tx * 11, y + ty * 11, 4.5, "white")
    c.paint(c.circle(32, 32, 7), GLOW["white"], style="dome")


def a_nova_burst(c):
    for k in range(10):
        a = TAU * k / 10
        c.paint(c.circle(32 + math.cos(a) * 22, 32 + math.sin(a) * 22, 4), GLOW["amber"], style="dome")
        c.flat(c.line(32 + math.cos(a) * 9, 32 + math.sin(a) * 9, 32 + math.cos(a) * 17, 32 + math.sin(a) * 17, 1.5), mix(NEON["amber"], "#0b0714", 0.3))
    c.paint(c.circle(32, 32, 8), GLOW["amber"], style="dome")


def a_gravity_well(c):
    for k in range(4):
        a0 = k * 90
        c.flat(c.arc(32, 32, 8 + k * 5, 2.5, a0, a0 + 200), mix(NEON["purple"], "#0b0714", k * 0.18))
    c.paint(c.circle(32, 32, 6), VOID[::-1], style="dome")


def a_overdrive(c):
    c.paint(c.arc(32, 40, 22, 8, 180, 360), GUNMETAL, style="cylinder")
    for k in range(5):
        a = math.pi + k * math.pi / 4
        c.flat(c.line(32 + math.cos(a) * 16, 40 + math.sin(a) * 16, 32 + math.cos(a) * 21, 40 + math.sin(a) * 21, 2), NEON["amber"] if k > 2 else CHROME[3])
    c.paint(c.capsule(32, 40, 50, 24, 2.5, 1), GLOW["red"], style="cylinder")
    c.paint(c.circle(32, 40, 5), STEEL, style="dome")
    for k in range(3):
        c.paint(c.poly([(14 + k * 12, 50), (20 + k * 12, 56), (14 + k * 12, 62), (18 + k * 12, 56)]), GLOW["amber"], style="bevel")


# ---------------------------------------------------------------- skill tree

def m_o_power(c):
    c.paint(c.rect(18, 26, 28, 26, 8), SKIN, style="bevel")
    for k in range(4):
        c.paint(c.rect(18 + k * 7, 20, 7, 12, 3), SKIN, style="bevel", sep=True)
    c.paint(c.rect(14, 46, 36, 8, 2), GLOW["magenta"][:4], style="bevel", sep=True)
    arrow(c, 52, 40, 52, 8, 5, "magenta")


def m_o_crit(c):
    crosshair(c, 32, 32, 16, "magenta")
    c.paint(c.circle(32, 32, 5), GLOW["red"], style="dome")


def m_o_tempo(c):
    for k in range(3):
        c.paint(c.poly([(10 + k * 14, 14), (26 + k * 14, 32), (10 + k * 14, 50), (16 + k * 14, 32)]), GLOW["magenta"] if k == 2 else TINT["magenta"], style="bevel")


def m_o_swarm(c):
    for x, y, r in ((18, 20, 15), (46, 20, 15), (32, 44, 17)):
        drone_motif(c, x, y, r, "magenta")


def m_o_lethal(c):
    blade(c, 14, 50, 50, 14, 5, "magenta")
    for k in range(8):
        a = TAU * k / 8
        r = 12 if k % 2 else 18
        c.flat(c.line(46, 18, 46 + math.cos(a) * r, 18 + math.sin(a) * r, 2), NEON["red"] if k % 2 else NEON["white"])


def m_o_reach(c):
    c.paint(c.circle(32, 32, 7), GLOW["magenta"], style="dome")
    for a in (0, 90, 180, 270):
        r = math.radians(a)
        arrow(c, 32 + math.cos(r) * 11, 32 + math.sin(r) * 11, 32 + math.cos(r) * 28, 32 + math.sin(r) * 28, 4, "magenta")


def m_o_velocity(c):
    for k in range(3):
        c.flat(c.line(4, 22 + k * 10, 26, 22 + k * 10, 2), mix(NEON["magenta"], "#0b0714", 0.2 + k * 0.2))
    c.paint(c.capsule(24, 32, 52, 32, 7), BRASS, style="cylinder")
    c.paint(c.ellipse(52, 32, 9, 7).clip(c.rect(52, 20, 14, 24)), GLOW["magenta"], style="dome")


def m_o_hunter(c):
    crown(c, 32, 22, 30, BRASS[1:] + [NEON["amber"]])
    crosshair(c, 32, 42, 12, "magenta")


def m_o_focus(c):
    c.paint(c.ellipse(32, 32, 24, 14), ["#e0e4f4", "#c4c8dc", "#f0f2ff"], style="dome")
    c.paint(c.circle(32, 32, 10), GLOW["magenta"], style="dome", sep=True)
    c.flat(c.circle(32, 32, 4), "#05030a")
    c.flat(c.arc(32, 32, 28, 2, 200, 340), NEON["magenta"])


def m_o_regicide(c):
    crown(c, 30, 30, 34, BRASS[1:] + [NEON["amber"]])
    blade(c, 8, 56, 56, 8, 4, "red")


def m_d_vitality(c):
    heart(c, 30, 34, 18, ["#3a0a14", "#8a1428", "#c41e3a", NEON["red"], "#ffb0b8"])
    c.flat(c.rect(46, 6, 4, 14), NEON["cyan"]); c.flat(c.rect(41, 11, 14, 4), NEON["cyan"])


def m_d_plating(c):
    for k in range(3):
        c.paint(c.rect(12, 12 + k * 13, 40, 14, 4), STEEL, style="bevel", sep=True, rim=NEON["cyan"], rim_dir=(0.5, 1))
        for x in (16, 46):
            c.flat(c.rect(x, 17 + k * 13, 2, 2), CHROME[4])


def m_d_regen(c):
    heart(c, 32, 34, 13, ["#3a0a14", "#8a1428", NEON["red"], "#ffb0b8"])
    c.flat(c.arc(32, 32, 25, 3, 200, 520), NEON["cyan"])
    c.paint(c.poly([(54, 22), (60, 34), (48, 32)]), GLOW["cyan"], style="bevel")


def m_d_reservoir(c):
    flask(c, 32, 34, "blue", 0.85)


def m_d_leech(c):
    heart(c, 32, 30, 14, ["#3a0a14", "#8a1428", NEON["red"], "#ffb0b8"])
    fang(c, 24, 46, 16, BONE); fang(c, 40, 46, 16, BONE)


def m_d_medic(c):
    c.paint(c.rect(25, 8, 14, 48, 3), GUNMETAL, style="bevel", rim=NEON["cyan"], rim_dir=(0.7, 0.7))
    c.paint(c.rect(8, 25, 48, 14, 3), GUNMETAL, style="bevel", rim=NEON["cyan"], rim_dir=(0.7, 0.7))
    pts = [(10, 32), (22, 32), (26, 24), (31, 42), (36, 20), (40, 32), (54, 32)]
    for a, b in zip(pts, pts[1:]):
        c.flat(c.line(*a, *b, 2), NEON["green"])


def m_d_spikes(c):
    shield(c, 32, 34, 34, 40, STEEL, NEON["cyan"])
    for k in range(5):
        x = 16 + k * 8
        c.paint(c.poly([(x - 3, 16), (x, 4), (x + 3, 16)]), GLOW["orange"][1:], style="bevel")


def m_d_barrier(c):
    c.paint(c.circle(32, 34, 24), GLOW["blue"][:3], style="dome", dither=0.6)
    c.erase(c.circle(32, 34, 20))
    c.flat(c.ring(32, 34, 24, 1.5), NEON["blue"])
    c.paint(c.circle(32, 34, 9), SKIN, style="dome")


def m_d_flow(c):
    for k in range(3):
        y = 20 + k * 12
        pts = [(6 + j * 4, y + math.sin(j * 0.7 + k) * 4) for j in range(14)]
        for a, b in zip(pts, pts[1:]):
            c.flat(c.line(*a, *b, 3), mix(NEON["cyan"], "#0b0714", k * 0.25))


def m_d_bulwark(c):
    c.paint(c.rect(12, 6, 40, 52, 6), STEEL, style="bevel", rim=NEON["cyan"], rim_dir=(0.7, 0.7))
    c.paint(c.rect(18, 12, 28, 40, 4), GUNMETAL, style="bevel", sep=True)
    c.flat(c.rect(30, 14, 4, 36), NEON["cyan"]); c.flat(c.rect(20, 26, 24, 4), NEON["cyan"])


def m_u_stride(c):
    boot(c, 30, 36, "lime")


def m_u_magnet(c):
    magnet(c, 32, 32, 17, "lime")


def m_u_chrono(c):
    hourglass(c, 32, 32, "lime")


def m_u_scholar(c):
    c.paint(c.poly([(8, 16), (32, 22), (56, 16), (56, 52), (32, 58), (8, 52)]), ["#0c1a0c", "#1a3a1a", "#2a5a2a", "#3a7a3a"], style="bevel", rim=NEON["lime"], rim_dir=(0.7, 0.7))
    c.flat(c.line(32, 22, 32, 58, 2), "#0b0714")
    for k in range(4):
        c.flat(c.rect(13, 26 + k * 6, 14, 2), mix(NEON["lime"], "#1a3a1a", 0.3))
        c.flat(c.rect(37, 26 + k * 6, 14, 2), mix(NEON["lime"], "#1a3a1a", 0.3))


def m_u_greed(c):
    for k in range(4):
        coin(c, 26, 50 - k * 8, 13, 1.0)
    coin(c, 44, 46, 11)


def m_u_choice(c):
    for k, (x, y) in enumerate(((12, 30), (32, 26), (52, 30))):
        card(c, x, y, 17, 28, "lime" if k == 1 else "white")
    c.flat(c.rect(26, 46, 12, 3), NEON["lime"])


def m_u_luck(c):
    c.paint(c.rect(12, 18, 30, 30, 6), ["#d0d4e4", "#e8ecf8", "#f4f6ff"], style="bevel")
    for x, y in ((19, 25), (35, 41), (27, 33)):
        c.flat(c.circle(x, y, 3), "#0b0714")
    c.paint(c.rect(32, 8, 24, 24, 5), GLOW["lime"][:4], style="bevel")
    for x, y in ((38, 14), (50, 26)):
        c.flat(c.circle(x, y, 2.5), "#0b0714")


def m_u_capital(c):
    c.paint(c.rect(8, 14, 48, 40, 5), GUNMETAL, style="bevel", rim=NEON["lime"], rim_dir=(0.7, 0.7))
    c.paint(c.circle(32, 34, 12), STEEL, style="dome", sep=True)
    for k in range(6):
        a = TAU * k / 6
        c.flat(c.line(32, 34, 32 + math.cos(a) * 10, 34 + math.sin(a) * 10, 1.5), STEEL[0])
    c.paint(c.circle(32, 34, 4), GLOW["lime"], style="dome")


def m_u_overclock(c):
    gear(c, 30, 36, 20, STEEL)
    for k, x in enumerate((44, 52)):
        c.paint(c.poly([(x - 5, 22), (x, 6 + k * 4), (x + 5, 22)]), GLOW["orange"], style="dome")


def m_u_pathfinder(c):
    c.paint(c.circle(32, 32, 24), BRASS, style="dome")
    c.paint(c.circle(32, 32, 19), ["#0c1a0c", "#16261a", "#203424"], style="flat", sep=True)
    c.paint(c.poly([(32, 12), (37, 32), (32, 52), (27, 32)]), CHROME[1:], style="bevel")
    c.paint(c.poly([(32, 12), (37, 32), (27, 32)]), GLOW["lime"], style="bevel")
    c.flat(c.rect(31, 31, 2, 2), "#0b0714")


ITEMS = {k[2:]: v for k, v in globals().items() if k.startswith("i_")}
ABILITIES = {k[2:]: v for k, v in globals().items() if k.startswith("a_")}
META = {k[2:]: v for k, v in globals().items() if k.startswith("m_")}


def render(painter) -> object:
    c = Canvas(S, S)
    painter(c)
    done(c)
    return c.image()
