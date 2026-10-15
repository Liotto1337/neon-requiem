"""16x16 icons for items, abilities, skill-tree nodes and the HUD (shown x3..x4 in the UI).
Each icon draws the thing it names (crit lens -> a lens, servo boots -> a boot ...). One
light direction (top-left), 1 px outline, few colours. Transparent background."""
from __future__ import annotations

import math

from palette import BONE, BRASS, CHROME, GLASS, GLOW, GUNMETAL, MOSS, NEON, OUTLINE, RUST, SKIN, STEEL, TINT, VOID
from pixlib import Canvas, hex_rgb, mix

S = 16
TAU = math.tau
RED = ["#3c0c14", "#7a1a24", "#c03038", NEON["red"]]


def px(c: Canvas, pts, color: str) -> None:
    for x, y in pts:
        x, y = int(round(x)), int(round(y))
        if 0 <= x < c.w and 0 <= y < c.h:
            c.rgb[y, x] = hex_rgb(color)
            c.alpha[y, x] = True


def rect(c: Canvas, x, y, w, h, color: str) -> None:
    px(c, [(x + i, y + j) for i in range(w) for j in range(h)], color)


def hline(c, x, y, w, color):
    rect(c, x, y, w, 1, color)


def vline(c, x, y, h, color):
    rect(c, x, y, 1, h, color)


def ball(c: Canvas, cx, cy, r, ramp) -> None:
    c.paint(c.circle(cx, cy, r), ramp, style="dome", dither=0.0)


def box(c: Canvas, x, y, w, h, ramp) -> None:
    c.paint(c.rect(x, y, w, h, 1), ramp, style="bevel", dither=0.0)


# ---------------------------------------------------------------- motifs

def chip(c, col, core=True):
    for k in range(4):
        px(c, [(4 + k * 2, 2), (4 + k * 2, 13), (2, 4 + k * 2), (13, 4 + k * 2)], BRASS[3])
    box(c, 3, 3, 10, 10, GUNMETAL)
    if core:
        box(c, 5, 5, 6, 6, GLOW[col])


def heart(c, cx, cy, ramp):
    px(c, [(cx - 3, cy - 1), (cx - 2, cy - 2), (cx - 1, cy - 2), (cx, cy - 1), (cx + 1, cy - 2), (cx + 2, cy - 2), (cx + 3, cy - 1)], ramp[2])
    for row in range(5):
        hline(c, cx - 3 + row, cy + row, 7 - row * 2, ramp[2] if row < 2 else ramp[1])
    px(c, [(cx - 2, cy - 1)], ramp[3])


def bolt_sign(c, x, y, col):
    px(c, [(x + 2, y), (x + 1, y + 1), (x, y + 2), (x + 1, y + 2), (x + 2, y + 2), (x + 1, y + 3), (x, y + 4)], col)


def magnet(c, x, y, col):
    vline(c, x, y, 5, NEON["red"]); vline(c, x + 6, y, 5, CHROME[3])
    px(c, [(x, y + 5), (x + 1, y + 6), (x + 2, y + 7), (x + 3, y + 7), (x + 4, y + 7), (x + 5, y + 6), (x + 6, y + 5)], GLOW[col][2])
    px(c, [(x + 1, y + 5), (x + 5, y + 5)], GLOW[col][1])


def boot(c, col):
    box(c, 4, 2, 5, 9, GUNMETAL)
    rect(c, 3, 10, 10, 3, STEEL[2]); hline(c, 3, 12, 10, STEEL[1])
    hline(c, 5, 4, 3, NEON[col]); hline(c, 5, 7, 3, NEON[col])
    px(c, [(2, 6), (2, 7)], GLOW[col][2])


def flask(c, col):
    rect(c, 6, 2, 4, 4, GLASS[2]); hline(c, 5, 1, 6, BRASS[2])
    ball(c, 8, 10, 4.5, GLASS)
    c.paint(c.circle(8, 10, 3.6).clip(c.rect(0, 9, 16, 7)), GLOW[col], style="dome", dither=0.0)
    px(c, [(6, 8)], "#e0f4ff")


def coin(c, cx, cy, r=3):
    ball(c, cx, cy, r, BRASS[1:] + [NEON["amber"]])
    vline(c, cx, cy - 1, 2, mix(NEON["amber"], "#ffffff", 0.4))


def crosshair(c, cx, cy, col):
    c.flat(c.ring(cx, cy, 3.5, 1), NEON[col])
    px(c, [(cx, cy - 5), (cx, cy + 5), (cx - 5, cy), (cx + 5, cy)], NEON[col])
    px(c, [(cx, cy)], "#ffffff")


def drone_m(c, cx, cy, col):
    hline(c, cx - 3, cy - 2, 2, GUNMETAL[3]); hline(c, cx + 2, cy - 2, 2, GUNMETAL[3])
    c.paint(c.poly([(cx, cy - 2), (cx + 3, cy + 2), (cx - 3, cy + 2)]), GUNMETAL, style="bevel", dither=0.0)
    px(c, [(cx, cy + 1)], NEON[col])


def blade_m(c, x0, y0, x1, y1, col):
    c.flat(c.line(x0, y0, x1, y1, 1.6), CHROME[3])
    c.flat(c.line(x0, y0 - 1, x1, y1 - 1, 1), NEON[col])


def card(c, x, y, col):
    box(c, x, y, 5, 7, ["#0c0a16", "#1a1630", "#2a2448", "#3a3460"])
    px(c, [(x + 2, y + 3)], NEON[col])


def chain(c):
    for x, y in ((3, 12), (6, 9)):
        c.flat(c.ring(x, y, 2, 1), CHROME[3])
    c.flat(c.ring(12, 4, 2, 1), CHROME[3])
    px(c, [(9, 7), (10, 6), (8, 5), (11, 8)], NEON["amber"])


def done(c: Canvas) -> None:
    c.outline(OUTLINE)


# ---------------------------------------------------------------- items

def i_damage_chip(c):
    chip(c, "magenta"); px(c, [(7, 6), (7, 7), (7, 8), (6, 7), (8, 7)], "#ffffff")


def i_crit_lens(c):
    c.flat(c.line(9, 9, 13, 13, 2), GUNMETAL[3])
    c.flat(c.ring(6, 6, 4.5, 1.5), CHROME[3])
    c.paint(c.circle(6, 6, 3.3), GLASS, style="dome", dither=0.0)
    px(c, [(6, 4), (6, 8), (4, 6), (8, 6)], NEON["red"]); px(c, [(5, 4)], "#e0f4ff")


def i_servo_boots(c):
    boot(c, "cyan")


def i_regen_gel(c):
    flask(c, "green")


def i_mana_coil(c):
    for k in range(5):
        c.paint(c.ellipse(8, 3 + k * 2.4, 4.5, 1.2), GLOW["cyan"] if k % 2 else GLOW["blue"], style="flat", dither=0.0)
    vline(c, 8, 2, 12, GUNMETAL[2])


def i_magnet_coil(c):
    magnet(c, 4, 3, "lime"); px(c, [(2, 12), (13, 12), (3, 13), (12, 13)], TINT["lime"][3])


def i_thorn_mesh(c):
    for k in range(4):
        vline(c, 3 + k * 3, 3, 10, CHROME[2]); hline(c, 3, 3 + k * 3, 10, CHROME[2])
    px(c, [(3, 2), (9, 2), (6, 5), (12, 5), (3, 8), (9, 8), (6, 11), (12, 11)], NEON["orange"])


def i_leech_fang(c):
    c.paint(c.ellipse(8, 3, 6.5, 2.2), RED[:3], style="dome", dither=0.0)
    for x in (4, 10):
        c.paint(c.poly([(x - 1.5, 4), (x + 2.5, 4), (x + 0.5, 11)]), BONE, style="bevel", dither=0.0)
    px(c, [(4, 12), (10, 12), (4, 13), (10, 14)], NEON["red"])


def i_static_charm(c):
    c.flat(c.line(3, 1, 8, 4, 1), CHROME[2]); c.flat(c.line(12, 1, 8, 4, 1), CHROME[2])
    c.paint(c.poly([(8, 4), (13, 9), (8, 14), (3, 9)]), BRASS, style="bevel", dither=0.0)
    bolt_sign(c, 7, 7, NEON["cyan"])


def i_kill_battery(c):
    box(c, 4, 3, 8, 11, GUNMETAL); hline(c, 6, 2, 4, STEEL[2])
    for k in range(3):
        hline(c, 5, 11 - k * 3, 6, NEON["magenta"] if k < 2 else GLOW["magenta"][1])
    px(c, [(7, 4), (8, 4)], BONE[3])


def i_greed_module(c):
    chip(c, "amber", core=False); coin(c, 8, 8)


def i_plasma_rounds(c):
    for k, x in enumerate((4, 8, 12)):
        rect(c, x - 1, 6 + (k % 2), 2, 7, BRASS[2])
        px(c, [(x - 1, 4 + (k % 2)), (x, 4 + (k % 2)), (x - 1, 5 + (k % 2)), (x, 5 + (k % 2))], NEON["orange"])


def i_volatile_core(c):
    c.flat(c.ring(8, 8, 6, 1), STEEL[2])
    ball(c, 8, 8, 4.5, GLOW["orange"])
    px(c, [(6, 6), (7, 7), (7, 8), (9, 8), (10, 9)], "#ffffff")


def i_vital_frame(c):
    for k in range(4):
        hline(c, 3, 4 + k * 2, 10, CHROME[2])
    vline(c, 8, 3, 10, CHROME[3])
    heart(c, 8, 8, RED)


def i_chrono_chip(c):
    chip(c, "cyan", core=False)
    ball(c, 8, 8, 3.5, ["#8c90aa", "#a8acc4", "#c8cce0", "#e0e4f0"])
    px(c, [(8, 6), (8, 7), (8, 8), (9, 8), (10, 8)], OUTLINE)


def i_scope_chip(c):
    rect(c, 2, 6, 12, 4, GUNMETAL[2]); hline(c, 2, 6, 12, GUNMETAL[3])
    rect(c, 6, 4, 3, 2, STEEL[2]); px(c, [(13, 7), (13, 8)], GLASS[3])
    hline(c, 3, 9, 8, NEON["cyan"])


def i_kinetic_wraps(c):
    box(c, 3, 3, 10, 10, SKIN)
    for k in range(3):
        hline(c, 3, 5 + k * 3, 10, "#a8a0c0")
    hline(c, 3, 8, 10, NEON["magenta"])
    px(c, [(14, 4), (14, 7), (14, 10)], NEON["magenta"])


def i_signal_amplifier(c):
    vline(c, 7, 8, 6, GUNMETAL[2]); hline(c, 5, 13, 5, STEEL[2])
    c.paint(c.ellipse(7, 6, 4.5, 2.6), CHROME, style="dome", dither=0.0)
    px(c, [(8, 5)], NEON["lime"])
    px(c, [(12, 2), (13, 3), (14, 4)], NEON["lime"]); px(c, [(11, 1), (14, 1)], TINT["lime"][3])


def i_overclock_core(c):
    chip(c, "orange")
    px(c, [(5, 1), (8, 0), (11, 1), (5, 2), (8, 1), (11, 2)], NEON["orange"])


def i_assassin_module(c):
    blade_m(c, 3, 13, 11, 4, "magenta")
    rect(c, 2, 11, 3, 3, GUNMETAL[2])
    crosshair(c, 11, 11, "red")


def i_vampire_engine(c):
    box(c, 2, 4, 12, 8, RUST)
    heart(c, 8, 6, RED)
    px(c, [(4, 12), (4, 13), (11, 12), (11, 13)], BONE[3])
    rect(c, 4, 2, 2, 2, GUNMETAL[2]); rect(c, 10, 2, 2, 2, GUNMETAL[2])


def i_storm_relay(c):
    c.paint(c.poly([(8, 3), (11, 14), (5, 14)]), GUNMETAL, style="bevel", dither=0.0)
    ball(c, 8, 3, 1.6, GLOW["cyan"])
    bolt_sign(c, 1, 5, NEON["cyan"]); bolt_sign(c, 12, 6, NEON["cyan"])


def i_phase_drive(c):
    c.flat(c.ring(6, 8, 5, 1), TINT["purple"][2])
    c.flat(c.ring(10, 8, 5, 1.6), CHROME[3])
    ball(c, 10, 8, 2.5, VOID[::-1])
    px(c, [(10, 8)], NEON["white"])


def i_limit_break_ability(c):
    chain(c)
    box(c, 9, 9, 6, 6, GUNMETAL)
    px(c, [(11, 10), (11, 11), (11, 12), (11, 13), (12, 10), (13, 11), (12, 12), (13, 13), (12, 13)], NEON["amber"])


def i_limit_break_item(c):
    chain(c)
    box(c, 9, 9, 6, 6, GUNMETAL)
    px(c, [(10, 10), (11, 10), (12, 10), (13, 10), (12, 11), (12, 12), (11, 13)], NEON["amber"])


def i_nano_heal(c):
    box(c, 2, 4, 12, 9, ["#3a0a1a", "#7a1838", "#b02452", "#d03468"])
    rect(c, 6, 2, 4, 2, STEEL[2])
    rect(c, 7, 6, 2, 5, "#ffffff"); rect(c, 5, 7, 6, 2, "#ffffff")


def i_mana_cell(c):
    box(c, 4, 3, 8, 11, GUNMETAL); hline(c, 6, 2, 4, STEEL[2])
    for k in range(4):
        hline(c, 5, 12 - k * 2, 6, NEON["blue"] if k < 3 else NEON["cyan"])


def i_emp_grenade(c):
    c.flat(c.ring(8, 9, 6, 1), TINT["blue"][3])
    ball(c, 8, 9, 4, GUNMETAL)
    hline(c, 4, 9, 8, NEON["blue"])
    rect(c, 7, 3, 3, 2, STEEL[2]); px(c, [(11, 3), (12, 2)], CHROME[3])


def i_magnet_pulse(c):
    c.flat(c.ring(8, 8, 7, 1), TINT["lime"][2]); magnet(c, 5, 4, "lime")


def i_phase_cloak(c):
    c.paint(c.poly([(8, 1), (13, 6), (14, 14), (2, 14), (3, 6)]), TINT["purple"], style="bevel", dither=0.0)
    c.flat(c.ellipse(8, 7, 3, 3), "#05030a")
    px(c, [(7, 7), (9, 7)], NEON["white"])


def i_holo_barrier(c):
    for cx, cy in ((5, 5), (11, 5), (8, 10), (5, 15 - 4), (11, 11)):
        c.paint(c.poly([(cx + math.cos(TAU * j / 6) * 3, cy + math.sin(TAU * j / 6) * 3) for j in range(6)]), GLOW["blue"], style="bevel", dither=0.0)


def i_orbital_strike(c):
    rect(c, 7, 1, 3, 3, STEEL[2]); hline(c, 3, 2, 4, GLOW["blue"][2]); hline(c, 10, 2, 4, GLOW["blue"][2])
    c.paint(c.poly([(7, 4), (9, 4), (11, 13), (5, 13)]), WHITE_BEAM, style="cylinder", dither=0.0)
    hline(c, 4, 14, 8, NEON["amber"])


WHITE_BEAM = ["#8a8a9e", "#c8c8dc", "#ffffff"]


# ---------------------------------------------------------------- abilities

def a_piercing_shot(c):
    for x in (5, 9):
        rect(c, x, 4, 2, 8, TINT["magenta"][3])
    hline(c, 1, 8, 12, NEON["cyan"]); hline(c, 2, 7, 10, GLOW["cyan"][1])
    px(c, [(13, 8), (12, 7), (12, 9), (14, 8)], NEON["cyan"])


def a_rail_volley(c):
    rect(c, 1, 7, 3, 3, GUNMETAL[2])
    for a in (-0.45, 0, 0.45):
        c.flat(c.line(4, 8, 4 + math.cos(a) * 10, 8 + math.sin(a) * 10, 1.4), NEON["white"])


def a_arc_chain(c):
    pts = [(2, 12), (6, 4), (10, 11), (14, 3)]
    for a, b in zip(pts, pts[1:]):
        c.flat(c.line(*a, *b, 1), NEON["cyan"])
    for p in pts:
        px(c, [p, (p[0] + 1, p[1])], "#ffffff")


def a_blink_strike(c):
    for k, alpha in enumerate((0.7, 0.45)):
        c.flat(c.ellipse(3 + k * 3, 9, 1.5, 3), mix(NEON["magenta"], OUTLINE, alpha))
    ball(c, 11, 9, 3, GLOW["magenta"])
    px(c, [(11, 4), (15, 9), (11, 14), (7, 5)], "#ffffff")


def a_whirl_slash(c):
    for k in range(3):
        a = TAU * k / 3
        c.flat(c.line(8 + math.cos(a) * 3, 8 + math.sin(a) * 3, 8 + math.cos(a + 0.9) * 6.5, 8 + math.sin(a + 0.9) * 6.5, 1.4), CHROME[3])
    ball(c, 8, 8, 2, GLOW["magenta"])


def a_emp_pulse(c):
    c.flat(c.ring(8, 8, 6.5, 1), GLOW["blue"][2]); c.flat(c.ring(8, 8, 4, 1), GLOW["blue"][1])
    ball(c, 8, 8, 2, GLOW["blue"]); px(c, [(8, 8)], "#ffffff")


def a_deploy_drone(c):
    hline(c, 2, 6, 4, GUNMETAL[3]); hline(c, 9, 6, 4, GUNMETAL[3])
    c.paint(c.poly([(7, 5), (12, 13), (2, 13)]), GUNMETAL, style="bevel", dither=0.0)
    ball(c, 7, 10, 1.6, GLOW["lime"])
    px(c, [(13, 1), (13, 2), (13, 3), (12, 2), (14, 2)], NEON["lime"])


def a_swarm_missiles(c):
    for x, y in ((3, 12), (7, 11), (11, 12)):
        c.flat(c.line(x, y, x + 3, y - 8, 1.2), STEEL[3])
        px(c, [(x + 3, y - 8)], NEON["lime"])
        px(c, [(x, y + 1)], GLOW["lime"][1])


def a_orbit_blades(c):
    c.flat(c.ring(8, 8, 5, 1), TINT["white"][1])
    for k in range(3):
        a = TAU * k / 3
        x, y = 8 + math.cos(a) * 5, 8 + math.sin(a) * 5
        px(c, [(x, y), (x + math.cos(a + 1.6), y + math.sin(a + 1.6)), (x - math.cos(a + 1.6), y - math.sin(a + 1.6))], "#ffffff")
    ball(c, 8, 8, 1.8, GLOW["white"])


def a_nova_burst(c):
    for k in range(8):
        a = TAU * k / 8
        px(c, [(8 + math.cos(a) * 6, 8 + math.sin(a) * 6)], NEON["amber"])
        px(c, [(8 + math.cos(a) * 4, 8 + math.sin(a) * 4)], GLOW["amber"][1])
    ball(c, 8, 8, 2.2, GLOW["amber"])


def a_gravity_well(c):
    for k in range(40):
        t = k / 40
        a = t * TAU * 1.6
        r = 1 + t * 6
        px(c, [(8 + math.cos(a) * r, 8 + math.sin(a) * r)], NEON["purple"] if k % 3 else GLOW["purple"][1])
    px(c, [(8, 8)], "#05030a")


def a_overdrive(c):
    c.flat(c.arc(8, 10, 6, 1.5, 180, 360), GUNMETAL[3])
    px(c, [(3, 9), (13, 9)], NEON["amber"])
    c.flat(c.line(8, 10, 12, 5, 1), NEON["red"])
    ball(c, 8, 10, 1.4, STEEL)
    for k in range(3):
        px(c, [(3 + k * 4, 13), (4 + k * 4, 14), (3 + k * 4, 15)], NEON["amber"])


# ---------------------------------------------------------------- skill tree

def m_o_power(c):
    box(c, 3, 6, 7, 7, SKIN); hline(c, 3, 6, 7, SKIN[3])
    hline(c, 2, 13, 9, NEON["magenta"])
    vline(c, 13, 3, 8, NEON["magenta"]); px(c, [(12, 4), (14, 4), (11, 5), (15, 5)], NEON["magenta"])


def m_o_crit(c):
    crosshair(c, 8, 8, "magenta")


def m_o_tempo(c):
    for k in range(3):
        px(c, [(3 + k * 4, 4), (4 + k * 4, 5), (5 + k * 4, 6), (6 + k * 4, 7), (5 + k * 4, 8), (4 + k * 4, 9), (3 + k * 4, 10)],
           NEON["magenta"] if k == 2 else TINT["magenta"][3])


def m_o_swarm(c):
    drone_m(c, 4, 4, "magenta"); drone_m(c, 12, 4, "magenta"); drone_m(c, 8, 11, "magenta")


def m_o_lethal(c):
    blade_m(c, 2, 14, 10, 5, "magenta")
    px(c, [(12, 3), (12, 1), (12, 5), (10, 3), (14, 3)], "#ffffff"); px(c, [(11, 2), (13, 4), (13, 2), (11, 4)], NEON["red"])


def m_o_reach(c):
    ball(c, 8, 8, 2, GLOW["magenta"])
    for dx, dy in ((0, -1), (0, 1), (-1, 0), (1, 0)):
        px(c, [(8 + dx * k, 8 + dy * k) for k in range(3, 7)], NEON["magenta"])


def m_o_velocity(c):
    for k in range(3):
        hline(c, 1, 5 + k * 3, 4, TINT["magenta"][3])
    rect(c, 6, 6, 6, 4, BRASS[2]); px(c, [(12, 7), (12, 8), (13, 7), (13, 8), (14, 8)], NEON["magenta"])


def m_o_hunter(c):
    px(c, [(4, 2), (4, 5), (6, 3), (8, 1), (10, 3), (12, 2), (12, 5)], BRASS[3]); hline(c, 4, 5, 9, BRASS[3])
    crosshair(c, 8, 11, "magenta")


def m_o_focus(c):
    c.paint(c.ellipse(8, 8, 6.5, 4), ["#a8acc4", "#c8cce0", "#e0e4f0"], style="dome", dither=0.0)
    ball(c, 8, 8, 2.5, GLOW["magenta"]); px(c, [(8, 8)], OUTLINE)


def m_o_regicide(c):
    px(c, [(3, 6), (3, 9), (5, 7), (7, 5), (9, 7), (11, 6), (11, 9)], BRASS[3]); hline(c, 3, 9, 9, BRASS[3])
    blade_m(c, 2, 14, 14, 2, "red")


def m_d_vitality(c):
    heart(c, 7, 6, RED); px(c, [(13, 1), (13, 2), (13, 3), (12, 2), (14, 2)], NEON["cyan"])


def m_d_plating(c):
    for k in range(3):
        box(c, 2, 2 + k * 4, 12, 4, STEEL)
        px(c, [(3, 3 + k * 4), (12, 3 + k * 4)], CHROME[3])


def m_d_regen(c):
    heart(c, 8, 7, RED)
    c.flat(c.arc(8, 8, 6.5, 1, 200, 500), NEON["cyan"])


def m_d_reservoir(c):
    flask(c, "blue")


def m_d_leech(c):
    heart(c, 8, 4, RED)
    px(c, [(5, 10), (5, 11), (5, 12), (10, 10), (10, 11), (10, 12)], BONE[3])


def m_d_medic(c):
    rect(c, 6, 2, 4, 12, GUNMETAL[2]); rect(c, 2, 6, 12, 4, GUNMETAL[2])
    px(c, [(2, 8), (4, 8), (5, 6), (6, 10), (7, 5), (8, 9), (9, 8), (11, 8), (13, 8)], NEON["green"])


def m_d_spikes(c):
    c.paint(c.poly([(3, 4), (13, 4), (13, 9), (8, 14), (3, 9)]), STEEL, style="bevel", dither=0.0)
    px(c, [(3, 2), (6, 2), (9, 2), (12, 2), (4, 3), (7, 3), (10, 3)], NEON["orange"])


def m_d_barrier(c):
    c.flat(c.ring(8, 8, 6, 1.2), NEON["blue"]); ball(c, 8, 8, 2.5, SKIN)


def m_d_flow(c):
    for k in range(3):
        px(c, [(x, 4 + k * 4 + (1 if (x + k) % 4 < 2 else 0)) for x in range(1, 15)], NEON["cyan"] if k == 1 else TINT["cyan"][3])


def m_d_bulwark(c):
    box(c, 3, 1, 10, 14, STEEL); rect(c, 7, 3, 2, 10, NEON["cyan"]); rect(c, 5, 6, 6, 2, NEON["cyan"])


def m_u_stride(c):
    boot(c, "lime")


def m_u_magnet(c):
    magnet(c, 4, 4, "lime")


def m_u_chrono(c):
    hline(c, 4, 1, 8, BRASS[3]); hline(c, 4, 14, 8, BRASS[3])
    c.paint(c.poly([(5, 2), (11, 2), (8, 8), (11, 14), (5, 14), (8, 8)]), GLASS, style="flat", dither=0.0)
    px(c, [(7, 12), (8, 12), (9, 12), (6, 13), (7, 13), (8, 13), (9, 13), (10, 13), (7, 4), (8, 4), (9, 4), (8, 5)], NEON["lime"])


def m_u_scholar(c):
    c.paint(c.poly([(1, 4), (8, 6), (15, 4), (15, 13), (8, 15), (1, 13)]), MOSS, style="bevel", dither=0.0)
    vline(c, 8, 6, 9, OUTLINE)
    for k in range(3):
        hline(c, 3, 8 + k * 2, 3, NEON["lime"]); hline(c, 10, 8 + k * 2, 3, NEON["lime"])


def m_u_greed(c):
    for k in range(3):
        coin(c, 6, 12 - k * 3, 3)
    coin(c, 11, 11, 3)


def m_u_choice(c):
    card(c, 1, 5, "white"); card(c, 6, 3, "lime"); card(c, 11, 5, "white")


def m_u_luck(c):
    box(c, 2, 5, 8, 8, ["#8c90aa", "#a8acc4", "#c8cce0", "#e0e4f0"])
    px(c, [(4, 7), (6, 9), (8, 11)], OUTLINE)
    box(c, 9, 2, 6, 6, GLOW["lime"]); px(c, [(11, 4), (13, 6)], OUTLINE)


def m_u_capital(c):
    box(c, 2, 3, 12, 11, GUNMETAL)
    c.flat(c.ring(8, 8, 3, 1), STEEL[3]); px(c, [(8, 8)], NEON["lime"])
    vline(c, 13, 6, 4, NEON["lime"])


def m_u_overclock(c):
    for k in range(8):
        a = TAU * k / 8
        px(c, [(7 + math.cos(a) * 6, 9 + math.sin(a) * 6)], STEEL[3])
    c.flat(c.ring(7, 9, 4, 2), STEEL[2])
    px(c, [(12, 2), (13, 1), (14, 2), (13, 3)], NEON["orange"])


def m_u_pathfinder(c):
    ball(c, 8, 8, 6.5, BRASS)
    c.paint(c.circle(8, 8, 5), ["#0c1a0c", "#16261a", "#203424"], style="flat", dither=0.0)
    px(c, [(8, 4), (8, 5), (8, 6), (7, 7), (9, 7)], NEON["lime"]); px(c, [(8, 9), (8, 10), (8, 11)], CHROME[3])


# ---------------------------------------------------------------- ui

def u_threat(c):
    ball(c, 8, 7, 5.5, BONE)
    rect(c, 5, 11, 6, 3, BONE[2])
    px(c, [(6, 7), (10, 7)], NEON["red"]); px(c, [(5, 7), (9, 7)], "#05030a")
    px(c, [(8, 9)], "#05030a"); vline(c, 6, 12, 2, OUTLINE); vline(c, 8, 12, 2, OUTLINE); vline(c, 10, 12, 2, OUTLINE)


def u_credits(c):
    coin(c, 8, 8, 6)


def u_level(c):
    for k in range(3):
        y = 11 - k * 4
        px(c, [(3 + j, y + abs(j - 5) // 2) for j in range(11)], NEON["lime"] if k == 2 else TINT["lime"][3])


ITEMS = {k[2:]: v for k, v in globals().items() if k.startswith("i_")}
ABILITIES = {k[2:]: v for k, v in globals().items() if k.startswith("a_")}
META = {k[2:]: v for k, v in globals().items() if k.startswith("m_")}
UI = {k[2:]: v for k, v in globals().items() if k.startswith("u_")}


def render(painter) -> object:
    c = Canvas(S, S)
    painter(c)
    done(c)
    return c.image()
