"""Enemies, bosses, the Chorus drone, the train and hub props at 16-px scale (shown x4).
Soul Knight style: oval, amorphous bodies with directional light (top-left), a 1 px dark
outline and three facings — "side" (faces right, mirrored in game), "down" (towards the
camera) and "up" (away). Each facing has a 4-frame move loop. Bosses use larger canvases."""
from __future__ import annotations

import math

from palette import BONE, BRASS, CHROME, COAT, DARKCLOTH, GLOW, GUNMETAL, LEATHER, MARBLE, MOSS, NEON, OUTLINE, RUST, SKIN, STEEL, TINT, VOID
from pixlib import Canvas, hex_rgb, mix

TAU = math.tau
DIRS = ("side", "down", "up")
BOB = [0, -1, 0, 1]


# ---------------------------------------------------------------- helpers

def px(c: Canvas, pts, color: str) -> None:
    for x, y in pts:
        x, y = int(round(x)), int(round(y))
        if 0 <= x < c.w and 0 <= y < c.h:
            c.rgb[y, x] = hex_rgb(color)
            c.alpha[y, x] = True


def blob(c: Canvas, cx: float, cy: float, rx: float, ry: float, ramp: list[str]) -> None:
    """Oval body lit from the top-left (no dithering: every pixel is a choice at 16 px)."""
    c.paint(c.ellipse(cx, cy, rx, ry), ramp, style="dome", dither=0.0)


def eyes(c: Canvas, cx: float, cy: float, d: str, color: str, gap: int = 3, tall: int = 1) -> None:
    """Two eyes: centred facing down, shifted to the right facing side, hidden facing up."""
    if d == "up":
        return
    xs = (cx - gap / 2, cx + gap / 2) if d == "down" else (cx + 1, cx + 1 + gap * 0.7)
    for x in xs:
        px(c, [(x, cy + k) for k in range(tall)], color)


def feet(c: Canvas, cx: float, y: float, f: int, d: str, color: str, spread: float = 2.5, walk: bool = True) -> None:
    step = [0, 1, 0, -1][f % 4] if walk else 0
    if d == "side":
        px(c, [(cx - 1 + step, y), (cx + 1 - step, y)], color)
        px(c, [(cx + step, y), (cx + 2 - step, y)], color)
    else:
        px(c, [(cx - spread, y - (1 if step > 0 else 0)), (cx - spread + 1, y - (1 if step > 0 else 0))], color)
        px(c, [(cx + spread - 1, y - (1 if step < 0 else 0)), (cx + spread, y - (1 if step < 0 else 0))], color)


def finish(c: Canvas) -> None:
    c.outline(OUTLINE)


def walker(c: Canvas, f: int, d: str, ramp: list[str], eye: str, rx: float = 5.0, ry: float = 4.5,
           foot: str | None = None, cy: float | None = None) -> tuple[float, float]:
    """Generic oval walker: feet, body, eyes. Returns the body centre for extras."""
    cx = c.w / 2
    cy = (c.h / 2 + 0.5 if cy is None else cy) + BOB[f % 4] * 0.5
    feet(c, cx, c.h - 2, f, d, foot or ramp[0])
    blob(c, cx, cy, rx, ry, ramp)
    eyes(c, cx, cy - 1, d, eye)
    return cx, cy


def hover(c: Canvas, f: int, d: str, ramp: list[str], eye: str, rx: float = 5.0, ry: float = 4.5) -> tuple[float, float]:
    cx = c.w / 2
    cy = c.h / 2 + BOB[f % 4] * 0.6
    blob(c, cx, cy, rx, ry, ramp)
    eyes(c, cx, cy - 1, d, eye)
    return cx, cy


def side_x(d: str, value: float) -> float:
    """x offset that only applies to the side facing (things that stick out in front)."""
    return value if d == "side" else 0.0


# ---------------------------------------------------------------- common enemies (16 px)

def grunt(c, f, n, d):
    """Громила-дрон: boxy brawler blob with fists."""
    cx = c.w / 2
    cy = 8 + BOB[f % 4] * 0.5
    swing = [0, 1, 0, -1][f % 4]
    if d != "up":
        for side in (-1, 1):
            blob(c, cx + side * 6 + side_x(d, 1), cy + 2 + side * swing * 0.5, 1.8, 1.8, STEEL)
    c.paint(c.rect(cx - 5, cy - 4, 10, 9, 3), TINT["magenta"], style="bevel", dither=0.0)
    if d != "up":
        px(c, [(cx - 3 + side_x(d, 1) + k, cy - 1) for k in range(6 if d == "down" else 5)], NEON["magenta"])
    else:
        px(c, [(cx - 2, cy - 2), (cx + 2, cy - 2)], TINT["magenta"][0])
    px(c, [(cx - 1, cy + 6), (cx, cy + 6)], GLOW["magenta"][2])
    finish(c)


def glitch_rat(c, f, n, d):
    """Глюк-крыса: tiny lime robo-rat, tail and glitch pixels."""
    cx, cy = c.w / 2, 10 + BOB[f % 4] * 0.5
    if d == "side":
        px(c, [(cx - 5 - k, cy + 1 + (k + f) % 2) for k in range(3)], GUNMETAL[2])
    feet(c, cx, c.h - 3, f, d, GUNMETAL[1], spread=2)
    blob(c, cx + side_x(d, 0.5), cy, 4.5 if d == "side" else 3.5, 3, TINT["lime"])
    px(c, [(cx - 2, cy - 3), (cx + 2, cy - 3)] if d != "side" else [(cx, cy - 3)], STEEL[2])
    eyes(c, cx + side_x(d, 1), cy - 1, d, NEON["lime"], gap=2)
    px(c, [(cx + (f % 3) - 1, cy + 1)], NEON["magenta"] if f % 2 else NEON["cyan"])
    finish(c)


def turret_bot(c, f, n, d):
    """Турель-бот: amber dome on tripod with a barrel."""
    cx = c.w / 2
    lift = [0, 1, 0, 1][f % 4]
    for side in (-1, 1):
        px(c, [(cx + side * 4, 12 + lift * (side > 0)), (cx + side * 5, 13 + lift * (side > 0)), (cx + side * 5, 14)], GUNMETAL[2])
    blob(c, cx, 9, 5, 4, TINT["amber"])
    if d == "side":
        c.paint(c.rect(cx + 2, 6, 6, 2), GUNMETAL, style="flat")
    elif d == "down":
        c.paint(c.rect(cx - 1, 9, 2, 4), GUNMETAL, style="flat")
    else:
        c.paint(c.rect(cx - 1, 3, 2, 4), GUNMETAL, style="flat")
    if d != "up":
        px(c, [(cx + side_x(d, 1), 8)], NEON["amber"])
    finish(c)


def spark(c, f, n, d):
    """Искра: crackling spark ball (same from every side)."""
    cx, cy = c.w / 2, c.h / 2
    for k in range(6):
        a = TAU * k / 6 + f * 0.5
        r = 5 + (k + f) % 2
        px(c, [(cx + math.cos(a) * r, cy + math.sin(a) * r)], NEON["cyan"] if k % 2 else NEON["white"])
    blob(c, cx, cy, 3.5, 3.5, GLOW["cyan"])
    px(c, [(cx - 1, cy - 1)], "#ffffff")
    finish(c)


def brute(c, f, n, d):
    """Бугай (24 px): heavy purple brute with big fists."""
    cx = c.w / 2
    cy = 12 + BOB[f % 4] * 0.5
    swing = [0, 1, 0, -1][f % 4]
    feet(c, cx, c.h - 2, f, d, GUNMETAL[2], spread=4)
    if d != "up":
        for side in (-1, 1):
            blob(c, cx + side * 9 + side_x(d, 1), cy + 3 + side * swing, 2.6, 2.6, STEEL)
    blob(c, cx, cy, 8, 7.5, TINT["purple"])
    if d != "up":
        px(c, [(cx - 3 + side_x(d, 2) + k, cy - 3) for k in range(7 if d == "down" else 5)], NEON["purple"])
        c.paint(c.rect(cx - 3 + side_x(d, 1), cy + 1, 6, 3, 1), STEEL, style="flat")
    else:
        px(c, [(cx, cy - 4 + k) for k in range(7)], TINT["purple"][0])
    finish(c)


# ---------------------------------------------------------------- neon slums

def thug(c, f, n, d):
    """Бандит: hoodie punk with a mohawk."""
    cx, cy = walker(c, f, d, LEATHER, "#e8e0e0", rx=4.5, ry=5, foot=DARKCLOTH[2])
    mx = cx + side_x(d, -1)
    px(c, [(mx, cy - 7), (mx - 1, cy - 6), (mx, cy - 6), (mx + 1, cy - 6)], NEON["magenta"])
    if d == "side":
        c.flat(c.line(cx + 4, cy + 2, cx + 7, cy - 5, 1.2), LEATHER[3])
        px(c, [(cx + 7, cy - 5), (cx + 7, cy - 4)], NEON["magenta"])
    finish(c)


def neon_sniper(c, f, n, d):
    """Неон-снайпер: hooded figure with a cyan visor (holds a separate rifle in game)."""
    cx, cy = walker(c, f, d, COAT, NEON["cyan"], rx=4.5, ry=5.2, foot=COAT[0])
    if d != "up":
        px(c, [(cx - 2 + side_x(d, 2) + k, cy - 1) for k in range(4 if d == "down" else 3)], NEON["cyan"])
    px(c, [(cx + side_x(d, -2), cy - 6)], COAT[2])
    finish(c)


def graffiti_bomber(c, f, n, d):
    """Граффити-бомбер: round amber bomb-bot with paint drips."""
    cx, cy = walker(c, f, d, TINT["amber"], NEON["amber"], rx=5.5, ry=5)
    if d != "up":
        for k, col in enumerate(("magenta", "cyan", "lime")):
            px(c, [(cx - 3 + k * 3, cy + 1 + (k + f) % 2)], NEON[col])
    px(c, [(cx, cy - 6), (cx, cy - 7)], STEEL[2])
    px(c, [(cx + (1 if f % 2 else 0), cy - 8)], NEON["red"] if f % 2 else NEON["amber"])
    finish(c)


# ---------------------------------------------------------------- data core

def packet(c, f, n, d):
    """Пакет: rotating data cube."""
    cx, cy = c.w / 2, c.h / 2 + BOB[f % 4] * 0.5
    a = f * TAU / 16
    pts = [(cx + math.cos(a + TAU * k / 4) * 4.5, cy + math.sin(a + TAU * k / 4) * 4.5) for k in range(4)]
    c.paint(c.poly(pts), TINT["cyan"], style="bevel", dither=0.0)
    px(c, [(cx, cy), (cx - 1, cy)], NEON["cyan"])
    finish(c)


def firewall(c, f, n, d):
    """Файрвол: hex shield emitter with a flame core."""
    cx, cy = c.w / 2, c.h / 2
    hexagon = [(cx + math.cos(TAU * k / 6 + TAU / 12) * 6, cy + math.sin(TAU * k / 6 + TAU / 12) * 5.5) for k in range(6)]
    c.paint(c.poly(hexagon), STEEL, style="bevel", dither=0.0)
    flame = [(cx - 2, cy + 2), (cx - 2, cy - 1), (cx, cy - 3 - f % 2), (cx + 2, cy - 1), (cx + 2, cy + 2)]
    c.paint(c.poly(flame), GLOW["magenta"], style="dome", dither=0.0)
    for k in range(3):
        a = TAU * k / 3 + f * 0.5
        px(c, [(cx + math.cos(a) * 7, cy + math.sin(a) * 6.5)], NEON["magenta"])
    finish(c)


def daemon(c, f, n, d):
    """Демон: horned white digital demon."""
    cx, cy = c.w / 2, 9 + BOB[f % 4] * 0.5
    c.paint(c.poly([(cx - 5, cy - 3), (cx + 5, cy - 3), (cx, cy + 5)]), GUNMETAL, style="bevel", dither=0.0)
    for side in (-1, 1):
        px(c, [(cx + side * 4, cy - 4), (cx + side * 5, cy - 5), (cx + side * 5, cy - 6)], BONE[2])
    if d != "up":
        px(c, [(cx - 2 + side_x(d, 2), cy - 1), (cx + 1 + side_x(d, 1), cy - 1)], NEON["red"])
    tail = [0, 1, 0, -1][f % 4]
    px(c, [(cx + tail, cy + 6), (cx + tail, cy + 7)], TINT["white"][2])
    finish(c)


# ---------------------------------------------------------------- chrome gardens

def vine_crawler(c, f, n, d):
    """Лозоползун: chrome beetle tangled in vines, six legs."""
    cx, cy = c.w / 2, 9
    for k in range(3):
        off = [0, 1][(f + k) % 2]
        for side in (-1, 1):
            px(c, [(cx + side * 5, cy - 2 + k * 2 + off), (cx + side * 6, cy - 1 + k * 2 + off)], GUNMETAL[2])
    blob(c, cx, cy, 4.5, 5, CHROME)
    px(c, [(cx, cy - 4 + k) for k in range(9)], CHROME[0])
    px(c, [(cx - 3, cy), (cx - 2, cy + 1), (cx + 2, cy - 2), (cx + 3, cy - 1)], MOSS[3])
    eyes(c, cx + side_x(d, 1), cy - 4, d, NEON["lime"], gap=2)
    finish(c)


def spore_pod(c, f, n, d):
    """Спорокапсула: pulsing magenta pod with lime spores."""
    cx, cy = c.w / 2, 8
    pulse = [0, 0.5, 1, 0.5][f % 4]
    px(c, [(cx - 3, 14), (cx - 2, 13), (cx + 2, 13), (cx + 3, 14)], MOSS[2])
    blob(c, cx, cy, 5 + pulse, 5.5 + pulse, TINT["magenta"])
    for k in range(4):
        a = TAU * k / 4 + 0.6
        px(c, [(cx + math.cos(a) * 3, cy + math.sin(a) * 3)], NEON["lime"])
    finish(c)


def mantis(c, f, n, d):
    """Хром-богомол: slim chrome mantis with lime scythes."""
    cx, cy = walker(c, f, d, CHROME, NEON["lime"], rx=3.5, ry=5)
    lift = [0, -1, 0, 1][f % 4]
    for side in (-1, 1):
        if d == "side" and side < 0:
            continue
        x = cx + side * 4 + side_x(d, 2)
        tip = x + (1 if d == "side" else side)
        px(c, [(x, cy - 3 + lift), (tip, cy - 4 + lift), (tip, cy - 2 + lift)], NEON["lime"])
    finish(c)


# ---------------------------------------------------------------- ashen rail

def rail_jumper(c, f, n, d):
    """Рельсовый прыгун: amber diamond on a spring."""
    cx = c.w / 2
    squash = [0, 1, 0, -1][f % 4]
    for k in range(3):
        px(c, [(cx - 2, 11 + k + squash * 0.3), (cx + 2, 11 + k + squash * 0.3)], CHROME[2] if k % 2 else CHROME[1])
    c.paint(c.poly([(cx, 2 - squash), (cx + 6, 7), (cx, 11), (cx - 6, 7)]), TINT["amber"], style="bevel", dither=0.0)
    eyes(c, cx, 6, d, NEON["amber"], gap=2)
    px(c, [(cx - 2, 15), (cx + 2, 15)], STEEL[2])
    finish(c)


def ember_drone(c, f, n, d):
    """Угольный дрон: rusty furnace drone with a rotor."""
    cx, cy = hover(c, f, d, RUST, NEON["amber"], rx=5, ry=4.5)
    blade = [6, 3, 6, 3][f % 4]
    px(c, [(cx - blade + k, cy - 6) for k in range(blade * 2 + 1)], STEEL[2])
    px(c, [(cx, cy - 5)], GUNMETAL[2])
    if d != "up":
        px(c, [(cx - 1 + side_x(d, 1), cy + 1), (cx + side_x(d, 1), cy + 1)], NEON["orange"])
    px(c, [(cx + (f % 3) - 1, cy + 6)], NEON["orange"])
    finish(c)


def coal_golem(c, f, n, d):
    """Угольный голем (24 px): lumpy coal body with glowing cracks."""
    cx = c.w / 2
    cy = 12 + BOB[f % 4] * 0.5
    coal = ["#060408", "#120e16", "#201a26", "#302838"]
    feet(c, cx, c.h - 2, f, d, coal[2], spread=4)
    for side in (-1, 1):
        blob(c, cx + side * 8, cy + 2, 3, 4, coal)
    blob(c, cx, cy, 8, 8, coal)
    crack = NEON["orange"] if f % 2 else NEON["amber"]
    px(c, [(cx - 3, cy), (cx - 2, cy + 1), (cx - 2, cy + 2), (cx + 2, cy - 2), (cx + 3, cy - 1), (cx + 3, cy)], crack)
    eyes(c, cx + side_x(d, 1), cy - 4, d, NEON["amber"], gap=4)
    finish(c)


# ---------------------------------------------------------------- requiem spire

def choir_wisp(c, f, n, d):
    """Хоровой огонёк: little ghost with a halo."""
    cx, cy = c.w / 2, 8 + BOB[f % 4] * 0.6
    tail = [0, 1, 0, -1][f % 4]
    px(c, [(cx + tail, cy + 5), (cx - 1 + tail, cy + 6)], GLOW["white"][2])
    blob(c, cx, cy, 4, 4.5, GLOW["white"])
    if d != "up":
        px(c, [(cx - 1 + side_x(d, 1), cy - 1), (cx + 1 + side_x(d, 1), cy - 1), (cx + side_x(d, 1), cy + 1 + f % 2)], OUTLINE)
    px(c, [(cx - 1, cy - 6), (cx, cy - 6), (cx + 1, cy - 6)], NEON["amber"])
    finish(c)


def seraph_lance(c, f, n, d):
    """Серафим-копьё: winged marble angel-drone (holds a spear in game)."""
    cx, cy = c.w / 2, 8 + BOB[f % 4] * 0.6
    flap = [0, -1, 0, 1][f % 4]
    for side in (-1, 1):
        px(c, [(cx + side * 5, cy - 1 + flap), (cx + side * 6, cy - 2 + flap), (cx + side * 7, cy - 2 + flap), (cx + side * 6, cy + flap)], MARBLE[3])
    blob(c, cx, cy, 3.5, 5, MARBLE)
    eyes(c, cx, cy - 2, d, NEON["white"], gap=2)
    px(c, [(cx - 1, cy - 7), (cx, cy - 7), (cx + 1, cy - 7)], NEON["amber"])
    finish(c)


def requiem_knight(c, f, n, d):
    """Рыцарь реквиема (24 px): armoured knight, purple glowing visor."""
    plate = ["#0a0814", "#1c1830", "#34304e", "#524c74"]
    cx = c.w / 2
    cy = 12 + BOB[f % 4] * 0.5
    feet(c, cx, c.h - 2, f, d, plate[2], spread=4)
    blob(c, cx, cy + 1, 8, 7.5, plate)
    for side in (-1, 1):
        blob(c, cx + side * 7, cy - 3, 3, 2.5, plate)
    c.paint(c.rect(cx - 3, cy - 9, 6, 6, 2), plate, style="bevel", dither=0.0)
    if d != "up":
        px(c, [(cx - 2 + side_x(d, 1) + k, cy - 6) for k in range(4 if d == "down" else 3)], NEON["purple"])
    if d == "side":
        px(c, [(cx + 9, cy - 6 + k) for k in range(12)], GLOW["purple"][2])
    finish(c)


# ---------------------------------------------------------------- bosses (32 / 40 / 48 px)

def slum_enforcer(c, f, n, d):
    """Вышибала трущоб (32): bouncer blob with brass knuckles and visor."""
    cx = c.w / 2
    cy = 16 + BOB[f % 4] * 0.5
    swing = [0, 1, 0, -1][f % 4]
    feet(c, cx, c.h - 2, f, d, DARKCLOTH[2], spread=6)
    if d != "up":
        for side in (-1, 1):
            blob(c, cx + side * 12 + side_x(d, 1), cy + 4 + side * swing, 3.5, 3.5, BRASS)
    blob(c, cx, cy, 11, 10.5, LEATHER)
    if d != "up":
        c.paint(c.rect(cx - 6 + side_x(d, 2), cy - 5, 12, 3, 1), GLOW["magenta"], style="flat")
        px(c, [(cx - 4 + k * 3 + side_x(d, 2), cy + 3) for k in range(4)], GLOW["magenta"][1])
    else:
        px(c, [(cx, cy - 8 + k) for k in range(16)], LEATHER[0])
    finish(c)


def slum_king(c, f, n, d):
    """Король трущоб (40): crowned king on a hovering throne."""
    cx = c.w / 2
    cy = 22 + BOB[f % 4] * 0.5
    robe = ["#1a0614", "#3a0a24", "#5e1238", "#7c1e4a"]
    c.paint(c.ellipse(cx, cy + 9, 16, 6), TINT["magenta"], style="bevel", dither=0.0)
    for k in range(5):
        px(c, [(cx - 12 + k * 6, cy + 9)], NEON["amber"] if (k + f) % 2 else NEON["magenta"])
    blob(c, cx, cy, 10, 10, robe)
    if d != "up":
        blob(c, cx + side_x(d, 2), cy - 7, 5.5, 5, SKIN)
        px(c, [(cx - 2 + side_x(d, 3), cy - 7), (cx + 2 + side_x(d, 2), cy - 7)], NEON["amber"])
    else:
        blob(c, cx, cy - 7, 5.5, 5, robe)
    crown = [(cx - 5, cy - 11), (cx - 5, cy - 16), (cx - 2, cy - 13), (cx, cy - 17), (cx + 2, cy - 13), (cx + 5, cy - 16), (cx + 5, cy - 11)]
    c.paint(c.poly(crown), BRASS, style="bevel", dither=0.0)
    px(c, [(cx, cy - 14)], NEON["magenta"])
    finish(c)


def core_sentinel(c, f, n, d):
    """Страж ядра (32): diamond eye with orbiting shields."""
    cx, cy = c.w / 2, c.h / 2
    for k in range(4):
        a = TAU * k / 4 + f * TAU / 16
        x, y = cx + math.cos(a) * 13, cy + math.sin(a) * 11
        c.paint(c.poly([(x, y - 3), (x + 2, y), (x, y + 3), (x - 2, y)]), STEEL, style="bevel", dither=0.0)
    c.paint(c.poly([(cx, cy - 10), (cx + 8, cy), (cx, cy + 10), (cx - 8, cy)]), TINT["cyan"], style="bevel", dither=0.0)
    if d == "up":
        px(c, [(cx, cy - 6 + k) for k in range(12)], TINT["cyan"][0])
    else:
        blob(c, cx, cy, 3.5, 3, ["#8c90aa", "#a8acc4", "#c8cce0", "#e0e4f0"])
        look = [(-1, 0), (0, -1), (1, 0), (0, 1)][f % 4]
        px(c, [(cx + look[0] + side_x(d, 1), cy + look[1]), (cx + look[0] + side_x(d, 1) + 1, cy + look[1])], NEON["cyan"])
    finish(c)


def core_overseer(c, f, n, d):
    """Надзиратель ядра (40): floating head with a scan visor and cables."""
    cx = c.w / 2
    cy = 16 + BOB[f % 4] * 0.5
    for k in range(5):
        sway = [0, 1, 0, -1][(f + k) % 4]
        x = cx - 10 + k * 5
        px(c, [(x + sway * (j // 3), cy + 10 + j) for j in range(10)], GUNMETAL[2])
        px(c, [(x + sway * 3, cy + 20)], NEON["cyan"])
    blob(c, cx, cy, 14, 11, STEEL)
    if d != "up":
        c.paint(c.rect(cx - 10, cy - 1, 20, 4, 1), ["#020608", "#04121a", "#06202e"], style="flat")
        scan = int(f * 5) % 18
        px(c, [(cx - 9 + k, cy) for k in range(18)], GLOW["cyan"][2])
        px(c, [(cx - 9 + scan, cy), (cx - 9 + scan, cy + 1)], "#ffffff")
    c.paint(c.ellipse(cx, cy - 7, 8, 3), ["#030a14", "#06202e", "#0a3444"], style="flat")
    px(c, [(cx - 5 + k * 3, cy - 7) for k in range(4)], NEON["cyan"])
    finish(c)


def thorn_matriarch(c, f, n, d):
    """Терновая матрона (32): thorn queen rising from a flower."""
    cx = c.w / 2
    cy = 14 + BOB[f % 4] * 0.5
    for k in range(6):
        a = TAU * k / 6
        blob(c, cx + math.cos(a) * 9, 26 + math.sin(a) * 3, 4, 2, TINT["magenta"])
    sway = [0, 1, 0, -1][f % 4]
    for side in (-1, 1):
        px(c, [(cx + side * (6 + k), cy - 2 + k // 2 + sway * side) for k in range(8)], MOSS[3])
        px(c, [(cx + side * 13, cy + 2 + sway * side)], NEON["lime"])
    blob(c, cx, cy + 4, 6, 9, MOSS)
    blob(c, cx, cy - 6, 4.5, 4.5, ["#142408", "#2a4a12", "#3e6a1e", "#5a8a2a"])
    for k in range(5):
        px(c, [(cx - 4 + k * 2, cy - 11 - (k % 2))], NEON["magenta"])
    eyes(c, cx + side_x(d, 1), cy - 6, d, NEON["lime"], gap=3)
    finish(c)


def gardener_prime(c, f, n, d):
    """Садовник-прайм (40): round chrome mech with shears and a flower core."""
    cx, cy = c.w / 2, 20 + BOB[f % 4] * 0.5
    snip = [2, 1, 0, 1][f % 4]
    for k in range(5):
        a = TAU * k / 5 + math.pi / 2
        px(c, [(cx + math.cos(a) * r, cy + math.sin(a) * r * 0.8) for r in range(10, 18)], CHROME[2])
        px(c, [(cx + math.cos(a) * 18, cy + math.sin(a) * 14)], NEON["lime"])
    blob(c, cx, cy, 11, 10, CHROME)
    if d != "up":
        blob(c, cx + side_x(d, 2), cy, 6, 6, MOSS)
        px(c, [(cx + side_x(d, 2), cy)], NEON["lime"])
        for k in range(4):
            px(c, [(cx + side_x(d, 2) + math.cos(TAU * k / 4 + f) * 3, cy + math.sin(TAU * k / 4 + f) * 3)], NEON["magenta"])
    for side in (-1, 1):
        px(c, [(cx + side * (4 + k * 0.6 + snip * 0.3), cy - 10 - k) for k in range(8)], STEEL[3])
    finish(c)


def furnace_drone(c, f, n, d):
    """Печной дрон (32): rusty furnace with twin rotors."""
    cx, cy = c.w / 2, 16 + BOB[f % 4] * 0.6
    for side in (-1, 1):
        w = [5, 2, 5, 2][f % 4]
        px(c, [(cx + side * 10 - w + k, cy - 12) for k in range(w * 2 + 1)], STEEL[2])
        px(c, [(cx + side * 10, cy - 11), (cx + side * 9, cy - 10)], GUNMETAL[2])
    c.paint(c.rect(cx - 10, cy - 9, 20, 18, 4), RUST, style="bevel", dither=0.0)
    if d != "up":
        c.paint(c.rect(cx - 6 + side_x(d, 1), cy - 2, 12, 7, 1), ["#140402", "#2a0804", "#4a1006"], style="flat")
        px(c, [(cx - 4 + k + side_x(d, 1), cy + 1 + (k + f) % 2) for k in range(9)], NEON["orange"])
        eyes(c, cx + side_x(d, 1), cy - 6, d, NEON["amber"], gap=6)
    px(c, [(cx - 6, cy + 10 + f % 2), (cx + 6, cy + 10 + (f + 1) % 2)], NEON["orange"])
    finish(c)


def rail_baron(c, f, n, d):
    """Рельсовый барон (40): locomotive blob in a top hat."""
    cx, cy = c.w / 2, 22 + BOB[f % 4] * 0.4
    for k, x in enumerate((-12, -6, 6, 12)):
        blob(c, cx + x, 35, 3, 3, GUNMETAL)
        px(c, [(cx + x + [1, 0, -1, 0][(f + k) % 4], 35)], BRASS[3])
    c.paint(c.rect(cx - 16, 27, 32, 6, 2), RUST, style="bevel", dither=0.0)
    blob(c, cx, cy - 2, 10, 9, RUST)
    if d != "up":
        blob(c, cx + side_x(d, 2), cy - 2, 5, 5, BRASS)
        px(c, [(cx - 2 + side_x(d, 2), cy - 3), (cx + 2 + side_x(d, 2), cy - 3)], NEON["red"])
    c.paint(c.rect(cx - 5, cy - 21, 10, 9, 1), ["#05030a", "#0b0714", "#16101e", "#221a2c"], style="bevel", dither=0.0)
    c.paint(c.rect(cx - 8, cy - 13, 16, 2), ["#05030a", "#0b0714", "#16101e"], style="flat")
    px(c, [(cx - 5 + k, cy - 15) for k in range(10)], NEON["amber"])
    px(c, [(cx + 8, cy - 22 - f % 2), (cx + 9, cy - 24 - f % 2)], "#2a2430")
    finish(c)


def spire_herald(c, f, n, d):
    """Глашатай шпиля (32): winged marble herald with a halo and horn."""
    cx, cy = c.w / 2, 16 + BOB[f % 4] * 0.6
    flap = [0, -1, 0, 1][f % 4]
    for side in (-1, 1):
        for k in range(4):
            px(c, [(cx + side * (6 + j), cy - 6 + k * 3 + flap - j // 3) for j in range(9 - k)], MARBLE[3] if k % 2 else MARBLE[2])
    c.paint(c.poly([(cx - 4, cy - 5), (cx + 4, cy - 5), (cx + 7, cy + 13), (cx - 7, cy + 13)]), MARBLE, style="bevel", dither=0.0)
    blob(c, cx, cy - 8, 4, 4, MARBLE)
    eyes(c, cx, cy - 8, d, NEON["amber"], gap=2)
    c.flat(c.ring(cx, cy - 15, 4, 1.2), NEON["amber"])
    if d == "side":
        px(c, [(cx + 3 + k, cy - 6 - k // 2) for k in range(8)], BRASS[3])
    finish(c)


def requiem(c, f, n, d):
    """Реквием (48): the final conductor-angel — six dark wings, void core, halo."""
    cx, cy = c.w / 2, 24 + BOB[f % 4] * 0.6
    flap = [0, -1, 0, 1][f % 4]
    c.flat(c.ring(cx, cy - 2, 21, 1.2), mix(NEON["purple"], OUTLINE, 0.35))
    for side in (-1, 1):
        for k in range(3):
            base = cy - 6 + k * 7
            tip = (cx + side * (20 - k * 3), base - 8 + k * 3 - flap)
            c.paint(c.poly([(cx + side * 4, base), tip, (cx + side * (13 - k * 2), base + 5)]), ["#05030a", "#120a20", "#24143a", "#3a2058"], style="bevel", dither=0.0)
            px(c, [tip], NEON["purple"] if k != 1 else NEON["white"])
    c.paint(c.poly([(cx - 5, cy - 8), (cx + 5, cy - 8), (cx + 9, cy + 18), (cx - 9, cy + 18)]), ["#05030a", "#0e0818", "#1a0e2c", "#2a1844"], style="bevel", dither=0.0)
    if d != "up":
        blob(c, cx, cy + 3, 3.5, 3.5, VOID[::-1])
        px(c, [(cx, cy + 3)], NEON["white"])
    blob(c, cx, cy - 12, 3.5, 4, MARBLE)
    eyes(c, cx, cy - 12, d, NEON["purple"], gap=2)
    c.flat(c.ring(cx, cy - 19, 4, 1.2), NEON["white"])
    finish(c)


# ---------------------------------------------------------------- allies, props

def drone(c, f, n, d):
    """Chorus drone (12 px): little lime tri-rotor."""
    cx, cy = c.w / 2, c.h / 2 + BOB[f % 4] * 0.5
    blade = [2, 1, 2, 1][f % 4]
    px(c, [(cx - 3 - blade + k, cy - 3) for k in range(blade * 2 + 1)] + [(cx + 3 - blade + k, cy - 3) for k in range(blade * 2 + 1)], GUNMETAL[3])
    c.paint(c.poly([(cx, cy - 3), (cx + 4, cy + 3), (cx - 4, cy + 3)]), GUNMETAL, style="bevel", dither=0.0)
    px(c, [(cx, cy + 1)], NEON["lime"])
    finish(c)


def train(c, f, n, d):
    """Monorail train (104 x 16) for the Ashen Rail hazard, faces right."""
    w, h = c.w, c.h
    c.paint(c.rect(1, 2, w - 2, h - 4, 3), RUST, style="bevel", dither=0.0)
    c.paint(c.poly([(w - 10, 2), (w - 1, 6), (w - 1, h - 2), (w - 10, h - 2)]), BRASS, style="bevel", dither=0.0)
    for x in range(6, w - 14, 9):
        c.paint(c.rect(x, 4, 6, 4), ["#140402", "#2a0804"], style="flat")
        px(c, [(x + 1 + k, 5) for k in range(4)], NEON["amber"] if (x // 9 + f) % 3 else NEON["orange"])
    px(c, [(k, h - 4) for k in range(3, w - 3)], NEON["amber"])
    px(c, [(w - 3, h // 2)], "#ffffff")
    finish(c)


def portal(c, f, n, d):
    """Hub portal (32 x 40): neon arch with a swirling vortex."""
    cx, cy = c.w / 2, 18
    c.paint(c.rect(4, c.h - 6, c.w - 8, 4, 1), GUNMETAL, style="bevel", dither=0.0)
    px(c, [(k, c.h - 6) for k in range(5, c.w - 5)], NEON["cyan"])
    c.paint(c.ellipse(cx, cy, 12, 15), STEEL, style="dome", dither=0.0)
    c.paint(c.ellipse(cx, cy, 9, 12), VOID[::-1], style="dome", dither=0.0)
    for k in range(10):
        a = f * TAU / 4 + k * 0.7
        r = 2 + k * 0.7
        px(c, [(cx + math.cos(a) * r, cy + math.sin(a) * r * 1.3)], NEON["magenta"] if k % 2 else NEON["cyan"])
    px(c, [(cx, cy), (cx - 1, cy)], NEON["white"])
    for side in (-1, 1):
        px(c, [(cx + side * 13, cy - 6 + k) for k in range(16)], NEON["cyan"] if (f + k + (side > 0)) % 3 else GUNMETAL[2])
    finish(c)


def tree_terminal(c, f, n, d):
    """Skill tree projector (22 x 32): pedestal with a holographic tree."""
    cx = c.w / 2
    c.paint(c.rect(cx - 6, c.h - 7, 12, 5, 1), STEEL, style="bevel", dither=0.0)
    px(c, [(cx - 4 + k, c.h - 5) for k in range(9)], NEON["lime"])
    col = NEON["lime"] if f % 4 != 2 else mix(NEON["lime"], OUTLINE, 0.3)
    branches = [((cx, c.h - 8), (cx, c.h - 16)), ((cx, c.h - 16), (cx - 6, c.h - 22)), ((cx, c.h - 16), (cx + 6, c.h - 22)),
                ((cx, c.h - 16), (cx, c.h - 25)), ((cx - 6, c.h - 22), (cx - 8, c.h - 27)), ((cx + 6, c.h - 22), (cx + 8, c.h - 27))]
    for a, b in branches:
        c.flat(c.line(*a, *b, 1), col)
    for x, y in ((cx, c.h - 25), (cx - 8, c.h - 27), (cx + 8, c.h - 27), (cx - 6, c.h - 22), (cx + 6, c.h - 22)):
        px(c, [(x, y), (x + 1, y), (x, y + 1), (x + 1, y + 1)], NEON["cyan"] if (int(x) + f) % 3 == 0 else NEON["lime"])
    finish(c)


def workshop(c, f, n, d):
    """Workshop bench (30 x 26) with a robotic arm and sparks."""
    w, h = c.w, c.h
    c.paint(c.rect(1, h - 13, w - 2, 5, 1), RUST, style="bevel", dither=0.0)
    for x in (3, w - 5):
        c.paint(c.rect(x, h - 8, 2, 7), GUNMETAL, style="flat")
    c.paint(c.rect(w / 2 - 3, h - 16, 6, 3), CHROME, style="bevel", dither=0.0)
    px(c, [(w / 2, h - 15)], NEON["amber"])
    swing = [0, 2, 3, 1][f % 4]
    c.flat(c.line(w - 6, h - 13, w - 10 - swing, h - 22, 1.4), TINT["amber"][3])
    c.flat(c.line(w - 10 - swing, h - 22, w / 2 + 3 - swing, h - 18, 1.2), TINT["amber"][3])
    if f % 2 == 0:
        px(c, [(w / 2 + 2 - swing, h - 18), (w / 2 + 1 - swing, h - 20), (w / 2 + 4 - swing, h - 19)], NEON["amber"])
    c.paint(c.rect(3, h - 24, 7, 9, 1), GUNMETAL, style="bevel", dither=0.0)
    for k in range(3):
        px(c, [(4 + j, h - 22 + k * 3) for j in range(5)], NEON["amber"] if (k + f) % 3 else TINT["amber"][2])
    finish(c)


def hero_pod(c, f, n, d):
    """Hero capsule (20 x 32): glass pod with a silhouette."""
    cx = c.w / 2
    c.paint(c.rect(2, 2, c.w - 4, c.h - 5, 7), STEEL, style="bevel", dither=0.0)
    glass = c.rect(4, 4, c.w - 8, c.h - 10, 5)
    c.paint(glass, ["#041018", "#06202e", "#0a3444", "#0e4a5e"], style="dome", dither=0.0)
    sil = c.ellipse(cx, 14, 4, 4.5) | c.rect(cx - 3, 18, 6, 6)
    c.flat(sil.clip(glass), "#041018")
    scan = 5 + (f * 5) % 18
    px(c, [(k, scan) for k in range(5, c.w - 5)], NEON["cyan"])
    px(c, [(k, c.h - 4) for k in range(5, c.w - 5)], NEON["cyan"] if f % 2 else TINT["cyan"][2])
    finish(c)


def stats_board(c, f, n, d):
    """Records board (30 x 22): screen with bars and a trophy."""
    w, h = c.w, c.h
    c.paint(c.rect(1, 1, w - 2, h - 6, 2), GUNMETAL, style="bevel", dither=0.0)
    c.paint(c.rect(3, 3, w - 6, h - 10, 1), ["#03141c", "#06222e"], style="flat")
    for k in range(5):
        bh = [3, 6, 4, 8, 5][(k + f) % 5]
        px(c, [(5 + k * 3, h - 8 - j) for j in range(bh)], NEON["magenta"] if k == 3 else TINT["cyan"][3])
    px(c, [(w - 8, 5), (w - 7, 5), (w - 6, 5), (w - 5, 5), (w - 7, 6), (w - 6, 6), (w - 6, 7), (w - 7, 8), (w - 6, 8), (w - 5, 8)], BRASS[3])
    c.paint(c.rect(w / 2 - 1, h - 5, 2, 4), GUNMETAL, style="flat")
    finish(c)


# id -> (w, h, frames, painter, directional)
CREATURES = {
    "grunt": (16, 16, 4, grunt, True), "glitch_rat": (16, 16, 4, glitch_rat, True), "turret_bot": (16, 16, 4, turret_bot, True),
    "spark": (16, 16, 4, spark, False), "brute": (24, 24, 4, brute, True), "thug": (16, 16, 4, thug, True),
    "neon_sniper": (16, 16, 4, neon_sniper, True), "graffiti_bomber": (16, 16, 4, graffiti_bomber, True),
    "packet": (16, 16, 4, packet, False), "firewall": (16, 16, 4, firewall, False), "daemon": (16, 16, 4, daemon, True),
    "vine_crawler": (16, 16, 4, vine_crawler, True), "spore_pod": (16, 16, 4, spore_pod, False), "mantis": (16, 16, 4, mantis, True),
    "rail_jumper": (16, 16, 4, rail_jumper, True), "ember_drone": (16, 16, 4, ember_drone, True), "coal_golem": (24, 24, 4, coal_golem, True),
    "choir_wisp": (16, 16, 4, choir_wisp, True), "seraph_lance": (16, 16, 4, seraph_lance, True), "requiem_knight": (24, 24, 4, requiem_knight, True),
    "slum_enforcer": (32, 32, 4, slum_enforcer, True), "slum_king": (40, 40, 4, slum_king, True),
    "core_sentinel": (32, 32, 4, core_sentinel, True), "core_overseer": (40, 40, 4, core_overseer, True),
    "thorn_matriarch": (32, 32, 4, thorn_matriarch, True), "gardener_prime": (40, 40, 4, gardener_prime, True),
    "furnace_drone": (32, 32, 4, furnace_drone, True), "rail_baron": (40, 40, 4, rail_baron, True),
    "spire_herald": (32, 32, 4, spire_herald, True), "requiem": (48, 48, 4, requiem, True),
    "drone": (12, 12, 4, drone, False), "train": (104, 16, 2, train, False),
    "portal": (32, 40, 4, portal, False), "tree_terminal": (22, 32, 4, tree_terminal, False), "workshop": (30, 26, 4, workshop, False),
    "hero_pod": (20, 32, 4, hero_pod, False), "stats_board": (30, 22, 4, stats_board, False),
}
PROPS = {"train", "portal", "tree_terminal", "workshop", "hero_pod", "stats_board"}


def frames(creature_id: str, facing: str = "down") -> list:
    w, h, count, painter, _directional = CREATURES[creature_id]
    out = []
    for f in range(count):
        c = Canvas(w, h)
        painter(c, f, count, facing)
        out.append(c.image())
    return out
