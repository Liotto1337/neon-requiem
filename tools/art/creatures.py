"""Enemies, bosses, drones and the train: 4-frame loops drawn in code (3/4 top-down view,
facing the camera, centred on the canvas so the sprite origin is the body centre)."""
from __future__ import annotations

import math

from palette import (BONE, BRASS, CHROME, COAT, DARKCLOTH, GLASS, GLOW, GUNMETAL, LEATHER, MARBLE, MOSS,
                     NEON, OUTLINE, RUST, SKIN, SKIN_PALE, STEEL, TINT, VOID)
from pixlib import Canvas, mix

TAU = math.tau


def _eye(c: Canvas, x: float, y: float, r: float, col: str) -> None:
    c.paint(c.circle(x, y, r + 1), ["#05030a", "#0b0714"], style="flat")
    c.paint(c.circle(x, y, r), GLOW[col], style="dome", dither=0.3)


def _visor(c: Canvas, x: float, y: float, w: float, h: float, col: str) -> None:
    c.paint(c.rect(x, y, w, h, h / 2), GLOW[col][:4] + ["#ffffff"], style="cylinder", sep=True)


def _limb(c: Canvas, x0, y0, x1, y1, r0, r1, colors, sep=True) -> None:
    c.paint(c.capsule(x0, y0, x1, y1, r0, r1), colors, style="cylinder", sep=sep)


def _spikes(c: Canvas, cx, cy, r, count, length, colors, phase=0.0, width=2.5) -> None:
    for k in range(count):
        a = TAU * k / count + phase
        c.paint(c.capsule(cx + math.cos(a) * r * 0.6, cy + math.sin(a) * r * 0.6,
                          cx + math.cos(a) * (r + length), cy + math.sin(a) * (r + length), width, 0.6), colors, style="cylinder")


def _bob(f: int, n: int, amp: float = 1.0) -> float:
    return round(math.sin(TAU * f / n) * amp)


# ---------------------------------------------------------------- common enemies

def grunt(c: Canvas, f: int, n: int) -> None:
    """Громила-дрон: boxy brawler drone with fists."""
    s, b = c.w / 2, _bob(f, n)
    swing = math.sin(TAU * f / n) * 3
    for side in (-1, 1):
        _limb(c, s + side * 13, s - 2 + b, s + side * 19, s + 8 + b + side * swing, 3, 3, GUNMETAL)
        c.paint(c.rect(s + side * 19 - 5, s + 6 + b + side * swing, 10, 9, 3), STEEL, style="bevel", sep=True)
    c.paint(c.rect(s - 15, s - 14 + b, 30, 26, 7), TINT["magenta"], style="bevel", rim=NEON["magenta"], rim_dir=(0.6, 0.8))
    c.paint(c.rect(s - 10, s - 10 + b, 20, 11, 3), STEEL, style="bevel", sep=True)
    _visor(c, s - 8, s - 7 + b, 16, 5, "magenta")
    c.paint(c.rect(s - 11, s + 5 + b, 22, 5, 2), GUNMETAL, style="bevel", sep=True)
    for k in range(3):
        c.flat(c.rect(s - 7 + k * 6, s + 7 + b, 3, 1), GLOW["magenta"][1])
    c.paint(c.ellipse(s, s + 16 + b, 8, 3), GLOW["magenta"], style="dome")  # thruster
    c.outline(OUTLINE, "selout")


def glitch_rat(c: Canvas, f: int, n: int) -> None:
    """Глюк-крыса: small robo-rat, lime, glitch pixels."""
    s = c.w / 2
    step = 1 if f % 2 else -1
    c.paint(c.capsule(s + 6, s + 3, s + 15, s + 7 + step, 1.5, 0.7), GUNMETAL, style="cylinder")  # tail
    for k, x in enumerate((-6, 4)):
        _limb(c, s + x, s + 3, s + x + (step if k else -step), s + 8, 1.5, 1.5, GUNMETAL, sep=False)
    c.paint(c.ellipse(s, s, 9, 6), TINT["lime"], style="dome", rim=NEON["lime"], rim_dir=(0.5, 1))
    c.paint(c.ellipse(s - 8, s - 2, 5, 4), STEEL, style="dome", sep=True)
    c.paint(c.circle(s - 4, s - 7, 2.5), STEEL, style="dome")
    _eye(c, s - 10, s - 3, 1.2, "lime")
    if f % 2 == 0:
        c.flat(c.rect(s + 2, s - 4, 3, 1), NEON["magenta"])
    else:
        c.flat(c.rect(s - 2, s + 2, 4, 1), NEON["cyan"])
    c.outline(OUTLINE, "selout")


def turret_bot(c: Canvas, f: int, n: int) -> None:
    """Турель-бот: hex walker turret, amber."""
    s = c.w / 2
    lift = [0, 1, 0, -1][f % 4]
    for k, side in enumerate((-1, 1)):
        y = lift if k == 0 else -lift
        _limb(c, s + side * 10, s + 4, s + side * 17, s + 14 + y, 2.5, 2, GUNMETAL)
        c.paint(c.rect(s + side * 17 - 4, s + 13 + y, 8, 4, 1), STEEL, style="bevel", sep=True)
    hexagon = [(s + math.cos(TAU * k / 6) * 15, s - 2 + math.sin(TAU * k / 6) * 12) for k in range(6)]
    c.paint(c.poly(hexagon), TINT["amber"], style="bevel", rim=NEON["amber"], rim_dir=(0.6, 0.8))
    c.paint(c.circle(s, s - 4, 8), STEEL, style="dome", sep=True)
    c.paint(c.rect(s - 2.5, s - 18, 5, 12, 2), GUNMETAL, style="cylinder", sep=True)  # barrel
    c.paint(c.rect(s - 3.5, s - 20, 7, 3, 1), STEEL, style="bevel")
    _eye(c, s, s - 3, 2.5, "amber")
    c.outline(OUTLINE, "selout")


def spark(c: Canvas, f: int, n: int) -> None:
    """Искра: crackling electric spark creature, cyan."""
    s = c.w / 2
    _spikes(c, s, s, 6, 6, 5 + (f % 2) * 2, GLOW["cyan"][:4], phase=f * 0.4, width=1.6)
    c.paint(c.circle(s, s, 7), GLOW["cyan"], style="dome", dither=0.3)
    c.paint(c.circle(s - 1, s - 1, 3), ["#73f7ff", "#ffffff"], style="dome")
    for k in range(2):
        a = f * 1.3 + k * 3.1
        c.flat(c.pixels([(int(s + math.cos(a) * 11), int(s + math.sin(a) * 11))]), NEON["white"])
    c.outline(OUTLINE)


def brute(c: Canvas, f: int, n: int) -> None:
    """Бугай: heavy armored brute robot, purple."""
    s, b = c.w / 2, _bob(f, n, 1.5)
    stomp = [0, 2, 0, -2][f % 4]
    for side in (-1, 1):  # legs
        _limb(c, s + side * 12, s + 14, s + side * 15, s + 30 + side * stomp * 0.5, 6, 5, GUNMETAL)
        c.paint(c.rect(s + side * 15 - 8, s + 28 + side * stomp * 0.5, 16, 8, 3), STEEL, style="bevel", sep=True)
    for side in (-1, 1):  # arms
        _limb(c, s + side * 24, s - 8 + b, s + side * 30, s + 14 + b - side * stomp, 7, 6, TINT["purple"])
        c.paint(c.rect(s + side * 30 - 9, s + 12 + b - side * stomp, 18, 14, 4), STEEL, style="bevel", sep=True)
        c.flat(c.rect(s + side * 30 - 6, s + 17 + b - side * stomp, 12, 2), GLOW["purple"][2])
    c.paint(c.rect(s - 24, s - 22 + b, 48, 40, 10), TINT["purple"], style="bevel", rim=NEON["purple"], rim_dir=(0.6, 0.8))
    c.paint(c.rect(s - 16, s - 4 + b, 32, 16, 4), STEEL, style="bevel", sep=True)
    c.paint(c.circle(s, s + 4 + b, 5), GLOW["purple"], style="dome")
    c.paint(c.rect(s - 10, s - 30 + b, 20, 14, 5), STEEL, style="bevel", sep=True)  # head
    _visor(c, s - 8, s - 25 + b, 16, 4, "purple")
    for side in (-1, 1):
        c.paint(c.rect(s + side * 22 - 7, s - 26 + b, 14, 10, 4), STEEL[1:], style="bevel", sep=True)
    c.outline(OUTLINE, "selout")


# ---------------------------------------------------------------- neon slums

def _humanoid(c: Canvas, f: int, n: int, body: list[str], legs: list[str], skin: list[str], hood: bool,
              accent: str, prop: str) -> None:
    s = c.w / 2
    b = _bob(f, n)
    step = math.sin(TAU * f / n)
    for side in (-1, 1):  # legs
        y = side * step * 3
        _limb(c, s + side * 5, s + 6, s + side * 6, s + 20 + y, 3.5, 3, legs)
        c.paint(c.rect(s + side * 6 - 4, s + 18 + y, 8, 4, 2), GUNMETAL, style="bevel", sep=True)
    c.paint(c.rect(s - 10, s - 10 + b, 20, 20, 6), body, style="bevel", rim=NEON[accent], rim_dir=(0.7, 0.7))
    c.flat(c.rect(s - 1, s - 8 + b, 2, 16), body[0])
    head_y = s - 17 + b
    if hood:
        c.paint(c.circle(s, head_y, 8), body, style="dome", sep=True)
        c.paint(c.ellipse(s, head_y + 2, 5, 4.5), ["#05030a", "#0b0714", "#140c22"], style="flat")
        _visor(c, s - 4, head_y + 1, 8, 2.5, accent)
    else:
        c.paint(c.circle(s, head_y, 7), skin, style="dome", sep=True)
        c.paint(c.ellipse(s, head_y - 5, 7, 3.5), [accent and GLOW[accent][0], GLOW[accent][1], GLOW[accent][2]], style="dome")  # mohawk
        c.flat(c.rect(s - 4, head_y, 3, 2), "#0b0714"); c.flat(c.rect(s + 1, head_y, 3, 2), "#0b0714")
        c.flat(c.rect(s - 5, head_y - 1, 10, 1), GLOW[accent][2])
    swing = step * 4
    if prop == "bat":
        _limb(c, s + 10, s - 6 + b, s + 15, s + 2 + b + swing, 3, 3, skin)
        c.paint(c.capsule(s + 15, s + 2 + b + swing, s + 20, s - 18 + b + swing, 1.5, 3), LEATHER[1:] + [mix(NEON[accent], "#ffffff", 0.2)], style="cylinder")
        c.flat(c.line(s + 16, s - 2 + b + swing, s + 20, s - 16 + b + swing, 1), NEON[accent])
        _limb(c, s - 10, s - 6 + b, s - 13, s + 6 + b - swing, 3, 3, skin)
    else:  # rifle held across the body
        _limb(c, s - 10, s - 6 + b, s - 6, s + 4 + b, 3, 3, body)
        c.paint(c.rect(s - 14, s + 1 + b, 32, 4, 1), GUNMETAL, style="bevel", sep=True)
        c.paint(c.rect(s + 2, s - 1 + b, 7, 3, 1), STEEL, style="bevel")
        c.flat(c.rect(s + 18, s + 2 + b, 4, 2), GLOW[accent][2])
        c.flat(c.rect(s - 12, s + 2 + b, 10, 1), GLOW[accent][2])
        _limb(c, s + 10, s - 6 + b, s + 8, s + 3 + b, 3, 3, body)
    c.outline(OUTLINE, "selout")


def thug(c: Canvas, f: int, n: int) -> None:
    """Бандит: punk with a neon bat."""
    _humanoid(c, f, n, LEATHER, DARKCLOTH, SKIN, False, "magenta", "bat")


def neon_sniper(c: Canvas, f: int, n: int) -> None:
    """Неон-снайпер: hooded sniper with a rifle."""
    _humanoid(c, f, n, COAT, DARKCLOTH, SKIN_PALE, True, "cyan", "rifle")


def graffiti_bomber(c: Canvas, f: int, n: int) -> None:
    """Граффити-бомбер: round bomber bot with spray cans."""
    s, b = c.w / 2, _bob(f, n)
    for side in (-1, 1):
        _limb(c, s + side * 8, s + 8, s + side * 10, s + 18 + (side * (f % 2) * 2), 3, 2.5, GUNMETAL)
    c.paint(c.circle(s, s + b, 15), TINT["amber"], style="dome", rim=NEON["amber"], rim_dir=(0.6, 0.8))
    for k, col in enumerate(("magenta", "cyan", "lime")):  # paint drips
        c.flat(c.rect(s - 9 + k * 7, s - 6 + b, 3, 6 + (k + f) % 3 * 2), GLOW[col][2])
    c.paint(c.rect(s - 8, s - 14 + b, 16, 7, 3), STEEL, style="bevel", sep=True)
    _eye(c, s - 3, s - 11 + b, 1.8, "amber"); _eye(c, s + 3, s - 11 + b, 1.8, "amber")
    for side in (-1, 1):  # spray cans
        c.paint(c.rect(s + side * 16 - 3, s - 2 + b, 6, 11, 2), CHROME[1:], style="cylinder", sep=True)
        c.flat(c.rect(s + side * 16 - 1, s - 4 + b, 2, 2), NEON["magenta"] if side < 0 else NEON["cyan"])
    c.paint(c.circle(s, s + 8 + b, 4), GLOW["red"] if f % 2 else GLOW["amber"], style="dome")  # fuse light
    c.outline(OUTLINE, "selout")


# ---------------------------------------------------------------- data core

def packet(c: Canvas, f: int, n: int) -> None:
    """Пакет: spinning data cube."""
    s = c.w / 2
    turn = f / n * TAU / 4
    pts = [(s + math.cos(turn + TAU * k / 4) * 10, s + math.sin(turn + TAU * k / 4) * 10) for k in range(4)]
    c.paint(c.poly(pts), TINT["cyan"], style="bevel", rim=NEON["cyan"], rim_dir=(0.7, 0.7))
    inner = [(s + math.cos(turn + TAU * k / 4) * 5, s + math.sin(turn + TAU * k / 4) * 5) for k in range(4)]
    c.paint(c.poly(inner), GLOW["cyan"], style="bevel", sep=True)
    c.flat(c.rect(s - 1, s - 1, 2, 2), "#ffffff")
    for k in range(3):
        c.flat(c.pixels([(int(s - 12 + (f * 5 + k * 9) % 24), int(s + 12))]), NEON["cyan"])
    c.outline(OUTLINE)


def firewall(c: Canvas, f: int, n: int) -> None:
    """Файрвол: hex emitter with a rotating flame-shield."""
    s = c.w / 2
    c.paint(c.ring(s, s, 20, 3), GLOW["magenta"][:3], style="cylinder")
    for k in range(6):
        a = TAU * k / 6 + f / n * TAU / 6
        c.paint(c.rect(s + math.cos(a) * 20 - 3, s + math.sin(a) * 20 - 3, 6, 6, 1), GLOW["magenta"][1:], style="bevel")
    hexagon = [(s + math.cos(TAU * k / 6 + TAU / 12) * 14, s + math.sin(TAU * k / 6 + TAU / 12) * 14) for k in range(6)]
    c.paint(c.poly(hexagon), STEEL, style="bevel", sep=True)
    flame = [(s - 6, s + 5), (s - 7, s - 2), (s - 3, s - 8 + (f % 2)), (s, s - 4), (s + 3, s - 10 + ((f + 1) % 2)), (s + 7, s - 1), (s + 6, s + 5)]
    c.paint(c.poly(flame), GLOW["magenta"], style="dome")
    c.paint(c.ellipse(s, s + 2, 3, 3), ["#ff9cc4", "#ffffff"], style="dome")
    c.outline(OUTLINE, "selout")


def daemon(c: Canvas, f: int, n: int) -> None:
    """Демон: horned digital demon, white."""
    s, b = c.w / 2, _bob(f, n, 1.5)
    tail = math.sin(TAU * f / n) * 4
    c.paint(c.capsule(s, s + 10, s + tail, s + 22, 3, 1), TINT["white"], style="cylinder")
    for side in (-1, 1):  # claws/wings
        c.paint(c.poly([(s + side * 8, s - 6 + b), (s + side * 24, s - 14 + b + tail * side * 0.5), (s + side * 18, s + 4 + b), (s + side * 8, s + 4 + b)]),
                TINT["white"], style="bevel", sep=True)
        c.flat(c.line(s + side * 9, s - 4 + b, s + side * 22, s - 12 + b + tail * side * 0.5, 1), NEON["white"])
    tri = [(s, s + 14 + b), (s - 13, s - 10 + b), (s + 13, s - 10 + b)]
    c.paint(c.poly(tri), GUNMETAL, style="bevel", rim=NEON["white"], rim_dir=(0.6, 0.8))
    for side in (-1, 1):  # horns
        c.paint(c.capsule(s + side * 9, s - 10 + b, s + side * 14, s - 22 + b, 2.5, 0.8), BONE, style="cylinder")
    _eye(c, s - 4, s - 4 + b, 2, "red"); _eye(c, s + 4, s - 4 + b, 2, "red")
    c.flat(c.rect(s - 3, s + 2 + b, 6, 1), NEON["white"])
    c.outline(OUTLINE, "selout")


# ---------------------------------------------------------------- chrome gardens

def vine_crawler(c: Canvas, f: int, n: int) -> None:
    """Лозоползун: hex beetle wrapped in vines."""
    s = c.w / 2
    for k in range(3):
        for side in (-1, 1):
            off = math.sin(TAU * f / n + k * 2 + (side > 0) * math.pi) * 3
            _limb(c, s + side * 8, s - 6 + k * 7, s + side * 19, s - 9 + k * 9 + off, 2, 1.2, GUNMETAL, sep=False)
    hexagon = [(s + math.cos(TAU * k / 6) * 14, s + math.sin(TAU * k / 6) * 14) for k in range(6)]
    c.paint(c.poly(hexagon), CHROME[:5], style="bevel", rim=NEON["lime"], rim_dir=(0.6, 0.8))
    c.flat(c.line(s, s - 13, s, s + 13, 1), CHROME[0])
    for k in range(4):
        a = k * 1.6 + f * 0.3
        c.paint(c.capsule(s + math.cos(a) * 10, s + math.sin(a) * 10, s + math.cos(a + 1.2) * 4, s + math.sin(a + 1.2) * 4, 1.5), MOSS, style="cylinder")
    _eye(c, s - 4, s - 10, 1.8, "lime"); _eye(c, s + 4, s - 10, 1.8, "lime")
    c.outline(OUTLINE, "selout")


def spore_pod(c: Canvas, f: int, n: int) -> None:
    """Спорокапсула: pulsing spore pod."""
    s = c.w / 2
    pulse = math.sin(TAU * f / n) * 1.5
    for k in range(5):
        a = TAU * k / 5 + 0.3
        c.paint(c.capsule(s, s + 6, s + math.cos(a) * 18, s + 10 + math.sin(a) * 6, 2.5, 1), MOSS, style="cylinder")
    c.paint(c.ellipse(s, s, 14 + pulse, 15 + pulse), TINT["magenta"], style="dome", rim=NEON["magenta"], rim_dir=(0.6, 0.8))
    for k in range(6):
        a = TAU * k / 6 + 0.5
        c.paint(c.circle(s + math.cos(a) * 8, s - 2 + math.sin(a) * 8, 2.5), GLOW["lime"][1:], style="dome")
    c.paint(c.circle(s, s - 3, 4 + pulse * 0.5), GLOW["magenta"], style="dome")
    c.outline(OUTLINE, "selout")


def mantis(c: Canvas, f: int, n: int) -> None:
    """Хром-богомол: chrome mantis with scythe arms."""
    s, b = c.w / 2, _bob(f, n)
    step = math.sin(TAU * f / n)
    for side in (-1, 1):
        _limb(c, s + side * 4, s + 6, s + side * 14, s + 20 + side * step * 2, 2, 1.5, CHROME[:5], sep=False)
    c.paint(c.ellipse(s, s + 8, 6, 10), CHROME[:5], style="dome", rim=NEON["lime"], rim_dir=(0.6, 0.8))
    c.paint(c.ellipse(s, s - 6 + b, 5, 7), CHROME[:5], style="dome", sep=True)
    for side in (-1, 1):  # scythes
        x1, y1 = s + side * 12, s - 14 + b - step * side * 2
        _limb(c, s + side * 4, s - 6 + b, x1, y1, 2.5, 2, CHROME[:5])
        c.paint(c.poly([(x1, y1), (x1 + side * 10, y1 + 4), (x1 + side * 4, y1 + 14), (x1 + side * 2, y1 + 4)]), GLOW["lime"][:4], style="bevel", sep=True)
    c.paint(c.poly([(s - 7, s - 16 + b), (s + 7, s - 16 + b), (s, s - 8 + b)]), CHROME[:5], style="bevel", sep=True)
    _eye(c, s - 5, s - 16 + b, 1.8, "lime"); _eye(c, s + 5, s - 16 + b, 1.8, "lime")
    c.outline(OUTLINE, "selout")


# ---------------------------------------------------------------- ashen rail

def rail_jumper(c: Canvas, f: int, n: int) -> None:
    """Рельсовый прыгун: spring-legged jumper."""
    s = c.w / 2
    squash = [0, 3, 0, -3][f % 4]
    for side in (-1, 1):
        for k in range(4):  # spring coils
            y = s + 6 + k * (3 + squash * 0.25)
            c.paint(c.ellipse(s + side * 9, y, 4, 1.5), CHROME[1:], style="dome")
        c.paint(c.rect(s + side * 9 - 5, s + 18 + squash, 10, 4, 1), STEEL, style="bevel")
    pts = [(s, s - 14 - squash * 0.5), (s + 14, s), (s, s + 8), (s - 14, s)]
    c.paint(c.poly(pts), TINT["amber"], style="bevel", rim=NEON["amber"], rim_dir=(0.6, 0.8))
    c.paint(c.poly([(s, s - 8 - squash * 0.5), (s + 7, s), (s, s + 3), (s - 7, s)]), RUST, style="bevel", sep=True)
    _eye(c, s, s - 2, 2.5, "amber")
    c.outline(OUTLINE, "selout")


def ember_drone(c: Canvas, f: int, n: int) -> None:
    """Угольный дрон: flying coal furnace with rotor."""
    s, b = c.w / 2, _bob(f, n, 1.5)
    blade = f / n * math.pi
    for k in range(2):
        a = blade + k * math.pi / 2
        c.paint(c.capsule(s - math.cos(a) * 16, s - 16 + b - math.sin(a) * 3, s + math.cos(a) * 16, s - 16 + b + math.sin(a) * 3, 1.5), STEEL, style="cylinder")
    c.paint(c.rect(s - 1.5, s - 17 + b, 3, 6), GUNMETAL, style="cylinder")
    c.paint(c.poly([(s - 12, s - 10 + b), (s + 12, s - 10 + b), (s + 8, s + 10 + b), (s - 8, s + 10 + b)]), RUST, style="bevel", rim=NEON["amber"], rim_dir=(0.6, 0.8))
    c.paint(c.rect(s - 7, s - 4 + b, 14, 8, 2), ["#1a0602", "#3a0a02", "#7a2006"], style="flat", sep=True)
    c.paint(c.ellipse(s, s + 1 + b, 5, 2.5 + (f % 2)), GLOW["orange"], style="dome")
    for k in range(3):
        c.flat(c.pixels([(int(s - 4 + k * 4), int(s + 14 + b + (f + k) % 3 * 2))]), NEON["orange"] if k % 2 else NEON["amber"])
    c.outline(OUTLINE, "selout")


def coal_golem(c: Canvas, f: int, n: int) -> None:
    """Угольный голем: hulking coal golem with magma cracks."""
    s, b = c.w / 2, _bob(f, n, 1.5)
    stomp = [0, 2, 0, -2][f % 4]
    coal = ["#07050a", "#141018", "#221c26", "#342c38", "#4a404e"]
    for side in (-1, 1):
        c.paint(c.ellipse(s + side * 14, s + 28 + side * stomp * 0.5, 11, 8), coal, style="dome")
    for side in (-1, 1):
        c.paint(c.ellipse(s + side * 30, s + 8 + b - side * stomp, 11, 15), coal, style="dome", sep=True)
    c.paint(c.ellipse(s, s + 2 + b, 27, 26), coal, style="dome", rim=NEON["orange"], rim_dir=(0.6, 0.8))
    c.paint(c.ellipse(s, s - 22 + b, 13, 10), coal, style="dome", sep=True)
    cracks = [((s - 14, s - 8), (s - 4, s + 2), (s - 9, s + 14)), ((s + 6, s - 12), (s + 12, s), (s + 4, s + 10), (s + 14, s + 18)),
              ((s - 22, s + 6), (s - 30, s + 14)), ((s + 26, s + 2), (s + 32, s + 12))]
    for line in cracks:
        for a, bb in zip(line, line[1:]):
            c.flat(c.line(a[0], a[1] + b, bb[0], bb[1] + b, 2), NEON["orange"] if f % 2 else NEON["amber"])
    _eye(c, s - 5, s - 22 + b, 2.5, "amber"); _eye(c, s + 5, s - 22 + b, 2.5, "amber")
    c.paint(c.circle(s, s + 2 + b, 6), GLOW["orange"], style="dome")
    c.outline(OUTLINE, "selout")


# ---------------------------------------------------------------- requiem spire

def choir_wisp(c: Canvas, f: int, n: int) -> None:
    """Хоровой огонёк: singing ghost wisp."""
    s, b = c.w / 2, _bob(f, n, 1.5)
    tail = [(s - 6, s + b), (s + 6, s + b), (s + 3 + math.sin(TAU * f / n) * 3, s + 14), (s - 2 + math.sin(TAU * f / n + 1) * 3, s + 11)]
    c.paint(c.poly(tail), GLOW["white"][:4], style="dome")
    c.paint(c.circle(s, s - 3 + b, 8), GLOW["white"], style="dome", dither=0.3)
    c.paint(c.ellipse(s - 3, s - 4 + b, 1.2, 2), ["#05030a"], style="flat")
    c.paint(c.ellipse(s + 3, s - 4 + b, 1.2, 2), ["#05030a"], style="flat")
    c.paint(c.ellipse(s, s + 1 + b, 2, 1.5 + (f % 2)), ["#05030a"], style="flat")
    c.flat(c.ring(s, s - 12 + b, 4, 1), NEON["amber"])
    c.outline(OUTLINE)


def seraph_lance(c: Canvas, f: int, n: int) -> None:
    """Серафим-копьё: winged angel drone with a lance."""
    s, b = c.w / 2, _bob(f, n, 1.5)
    flap = math.sin(TAU * f / n) * 4
    for side in (-1, 1):
        for k in range(3):
            c.paint(c.capsule(s + side * 6, s - 4 + b, s + side * (24 - k * 3), s - 14 + k * 7 + b - flap, 2.5, 1.5), MARBLE[1:] + ["#e6e2f6"], style="cylinder", sep=True)
    c.paint(c.ellipse(s, s + b, 7, 11), MARBLE, style="dome", rim=NEON["white"], rim_dir=(0.6, 0.8))
    c.paint(c.circle(s, s - 12 + b, 5), MARBLE, style="dome", sep=True)
    c.flat(c.rect(s - 3, s - 12 + b, 6, 1.5), NEON["white"])
    c.flat(c.ring(s, s - 19 + b, 5, 1.2), NEON["amber"])
    c.paint(c.capsule(s + 10, s + 16 + b, s + 14, s - 18 + b, 1.2), BRASS, style="cylinder")  # lance
    c.paint(c.poly([(s + 14, s - 26 + b), (s + 17, s - 17 + b), (s + 11, s - 17 + b)]), GLOW["white"], style="bevel")
    c.outline(OUTLINE, "selout")


def requiem_knight(c: Canvas, f: int, n: int) -> None:
    """Рыцарь реквиема: armored knight with a purple greatsword."""
    s, b = c.w / 2, _bob(f, n, 1.5)
    step = math.sin(TAU * f / n)
    plate = ["#0c0a16", "#1e1a30", "#3a345a", "#5e5888", "#8a84b4"]
    for side in (-1, 1):
        _limb(c, s + side * 9, s + 12, s + side * 11, s + 32 + side * step * 3, 6, 5, plate)
        c.paint(c.rect(s + side * 11 - 7, s + 30 + side * step * 3, 14, 6, 2), plate, style="bevel", sep=True)
    c.paint(c.poly([(s - 22, s - 18 + b), (s + 22, s - 18 + b), (s + 16, s + 16 + b), (s - 16, s + 16 + b)]), plate, style="bevel", rim=NEON["purple"], rim_dir=(0.6, 0.8))
    c.paint(c.poly([(s - 10, s + 10 + b), (s + 10, s + 10 + b), (s + 14, s + 26 + b), (s - 14, s + 26 + b)]), DARKCLOTH, style="bevel", sep=True)
    for side in (-1, 1):
        c.paint(c.ellipse(s + side * 22, s - 16 + b, 9, 7), plate, style="dome", sep=True)
    c.paint(c.rect(s - 9, s - 36 + b, 18, 20, 6), plate, style="bevel", sep=True)
    c.flat(c.rect(s - 6, s - 28 + b, 12, 2), NEON["purple"])
    c.flat(c.rect(s - 1, s - 32 + b, 2, 10), "#05030a")
    c.paint(c.capsule(s - 26, s + 30 + b, s - 30, s - 26 + b - step * 2, 2.5, 3.5), GLOW["purple"], style="cylinder")  # sword
    c.paint(c.rect(s - 34, s + 8 + b, 14, 4, 1), BRASS, style="bevel")
    _limb(c, s - 20, s - 12 + b, s - 27, s + 8 + b, 5, 5, plate)
    c.outline(OUTLINE, "selout")


# ---------------------------------------------------------------- bosses

def slum_enforcer(c: Canvas, f: int, n: int) -> None:
    """Вышибала трущоб: giant bouncer cyborg with brass knuckles."""
    s, b = c.w / 2, _bob(f, n, 2)
    stomp = [0, 3, 0, -3][f % 4]
    for side in (-1, 1):
        _limb(c, s + side * 18, s + 24, s + side * 22, s + 52 + side * stomp, 10, 9, DARKCLOTH)
        c.paint(c.rect(s + side * 22 - 13, s + 50 + side * stomp, 26, 12, 4), GUNMETAL, style="bevel", sep=True)
    for side in (-1, 1):
        _limb(c, s + side * 36, s - 16 + b, s + side * 46, s + 16 + b - side * stomp, 11, 10, SKIN)
        c.paint(c.rect(s + side * 46 - 13, s + 12 + b - side * stomp, 26, 18, 6), BRASS, style="bevel", sep=True)
        for k in range(3):
            c.flat(c.rect(s + side * 46 - 10 + k * 7, s + 13 + b - side * stomp, 4, 3), "#fff0a0")
    c.paint(c.rect(s - 36, s - 34 + b, 72, 64, 16), LEATHER, style="bevel", rim=NEON["magenta"], rim_dir=(0.6, 0.8))
    c.paint(c.rect(s - 26, s - 20 + b, 52, 30, 6), ["#0c0612", "#1a0c22", "#2a1434", "#3a1c46"], style="bevel", sep=True)
    c.flat(c.rect(s - 20, s - 8 + b, 40, 3), NEON["magenta"])
    for k in range(4):
        c.flat(c.rect(s - 18 + k * 10, s + 0 + b, 6, 2), GLOW["magenta"][1])
    c.paint(c.rect(s - 16, s - 54 + b, 32, 26, 9), SKIN, style="bevel", sep=True)
    _visor(c, s - 14, s - 46 + b, 28, 7, "magenta")
    c.paint(c.rect(s - 8, s - 34 + b, 16, 3, 1), ["#2a1418", "#4a2428"], style="flat")
    c.outline(OUTLINE, "selout")


def slum_king(c: Canvas, f: int, n: int) -> None:
    """Король трущоб: crowned king on a hex throne-mech."""
    s, b = c.w / 2, _bob(f, n, 2)
    hexagon = [(s + math.cos(TAU * k / 6) * 56, s + 18 + math.sin(TAU * k / 6) * 30) for k in range(6)]
    c.paint(c.poly(hexagon), TINT["magenta"], style="bevel", rim=NEON["magenta"], rim_dir=(0.6, 0.8))
    for k in range(6):
        a = TAU * k / 6
        c.paint(c.circle(s + math.cos(a) * 46, s + 18 + math.sin(a) * 24, 4), GLOW["magenta"] if (k + f) % 2 else GLOW["amber"], style="dome")
    c.paint(c.rect(s - 30, s - 40 + b, 60, 50, 10), ["#140818", "#2a1030", "#40184a", "#582060"], style="bevel", sep=True)  # throne back
    c.flat(c.rect(s - 26, s - 36 + b, 52, 2), NEON["magenta"])
    c.paint(c.ellipse(s, s - 4 + b, 22, 22), ["#3a0a20", "#6a1438", "#9a1e52", "#c0286a"], style="dome", sep=True)  # robe
    c.paint(c.rect(s - 18, s - 4 + b, 36, 6, 2), BRASS, style="bevel", sep=True)
    c.paint(c.circle(s, s - 30 + b, 13), SKIN, style="dome", sep=True)
    c.paint(c.rect(s - 9, s - 33 + b, 18, 5, 2), ["#05030a", "#0b0714"], style="flat")
    c.flat(c.rect(s - 7, s - 32 + b, 5, 2), NEON["amber"]); c.flat(c.rect(s + 2, s - 32 + b, 5, 2), NEON["amber"])
    crown = [(s - 14, s - 40 + b), (s - 14, s - 54 + b), (s - 7, s - 46 + b), (s, s - 58 + b), (s + 7, s - 46 + b), (s + 14, s - 54 + b), (s + 14, s - 40 + b)]
    c.paint(c.poly(crown), BRASS, style="bevel", sep=True)
    c.paint(c.circle(s, s - 47 + b, 3), GLOW["magenta"], style="dome")
    for side in (-1, 1):  # rings / fists on armrests
        c.paint(c.circle(s + side * 34, s + 2 + b, 9), BRASS, style="dome", sep=True)
        c.paint(c.circle(s + side * 34, s + 2 + b, 4), GLOW["cyan"] if side < 0 else GLOW["lime"], style="dome")
    c.outline(OUTLINE, "selout")


def core_sentinel(c: Canvas, f: int, n: int) -> None:
    """Страж ядра: diamond eye with orbiting shield plates."""
    s = c.w / 2
    turn = f / n * TAU / 4
    for k in range(4):
        a = turn + TAU * k / 4
        x, y = s + math.cos(a) * 52, s + math.sin(a) * 40
        c.paint(c.poly([(x, y - 12), (x + 9, y), (x, y + 12), (x - 9, y)]), STEEL, style="bevel", rim=NEON["cyan"], rim_dir=(0.6, 0.8))
    c.paint(c.poly([(s, s - 44), (s + 34, s), (s, s + 44), (s - 34, s)]), TINT["cyan"], style="bevel", rim=NEON["cyan"], rim_dir=(0.6, 0.8))
    c.paint(c.poly([(s, s - 30), (s + 22, s), (s, s + 30), (s - 22, s)]), STEEL, style="bevel", sep=True)
    c.paint(c.ellipse(s, s, 14, 12), ["#f0f0ff", "#c8d0e8", "#ffffff"], style="dome", sep=True)
    look = [(-3, 0), (0, -2), (3, 0), (0, 2)][f % 4]
    c.paint(c.circle(s + look[0], s + look[1], 7), GLOW["cyan"], style="dome")
    c.flat(c.circle(s + look[0], s + look[1], 3), "#05030a")
    c.outline(OUTLINE, "selout")


def core_overseer(c: Canvas, f: int, n: int) -> None:
    """Надзиратель ядра: giant floating head with data cables."""
    s, b = c.w / 2, _bob(f, n, 2)
    for k in range(6):
        sway = math.sin(TAU * f / n + k) * 6
        x0 = s - 40 + k * 16
        pts = [(x0, s + 20 + b), (x0 + sway, s + 44), (x0 - sway * 0.5, s + 64)]
        for a, bb in zip(pts, pts[1:]):
            c.paint(c.capsule(*a, *bb, 3), GUNMETAL, style="cylinder")
        c.paint(c.circle(*pts[-1], 3), GLOW["cyan"], style="dome")
    c.paint(c.ellipse(s, s - 6 + b, 50, 42), STEEL, style="dome", rim=NEON["cyan"], rim_dir=(0.6, 0.8))
    c.paint(c.ellipse(s, s - 30 + b, 34, 14), ["#030a14", "#06202e", "#0a3444", "#0e4a5e"], style="dome", sep=True)  # brain glass
    for k in range(5):
        c.flat(c.line(s - 26 + k * 13, s - 36 + b, s - 22 + k * 13, s - 24 + b, 1), GLOW["cyan"][2 + (k + f) % 2])
    c.paint(c.rect(s - 34, s - 8 + b, 68, 18, 8), ["#020608", "#04121a", "#06202e"], style="flat", sep=True)
    c.paint(c.rect(s - 30, s - 4 + b, 60, 10, 5), GLOW["cyan"], style="cylinder")
    scan = int((f / n) * 56)
    c.flat(c.rect(s - 28 + scan, s - 4 + b, 4, 10), "#ffffff")
    c.paint(c.rect(s - 18, s + 18 + b, 36, 8, 3), GUNMETAL, style="bevel", sep=True)
    c.outline(OUTLINE, "selout")


def thorn_matriarch(c: Canvas, f: int, n: int) -> None:
    """Терновая матрона: thorn queen rising from a flower."""
    s, b = c.w / 2, _bob(f, n, 2)
    for k in range(8):
        a = TAU * k / 8 + 0.2
        c.paint(c.ellipse(s + math.cos(a) * 36, s + 30 + math.sin(a) * 16, 18, 9, math.degrees(a)), TINT["magenta"], style="dome", sep=True)
    c.paint(c.ellipse(s, s + 30, 24, 12), MOSS, style="dome", sep=True)
    for side in (-1, 1):  # thorn whips
        sway = math.sin(TAU * f / n + side) * 6
        pts = [(s + side * 14, s - 6 + b), (s + side * 40, s - 20 + sway), (s + side * 58, s + 4 - sway)]
        for a, bb in zip(pts, pts[1:]):
            c.paint(c.capsule(*a, *bb, 4, 3), MOSS, style="cylinder", sep=True)
        for a in pts[1:]:
            c.paint(c.poly([(a[0], a[1] - 8), (a[0] + 3, a[1]), (a[0] - 3, a[1])]), GLOW["lime"][:4], style="bevel")
    c.paint(c.ellipse(s, s + 4 + b, 16, 26), MOSS, style="dome", rim=NEON["lime"], rim_dir=(0.6, 0.8))
    c.paint(c.circle(s, s - 28 + b, 12), ["#1a2a0c", "#3a5a1a", "#5a8a2a", "#7aaa3a"], style="dome", sep=True)
    for k in range(5):  # thorn crown
        a = -math.pi / 2 + (k - 2) * 0.45
        c.paint(c.capsule(s + math.cos(a) * 10, s - 28 + b + math.sin(a) * 10, s + math.cos(a) * 22, s - 28 + b + math.sin(a) * 22, 2.5, 0.6), GLOW["magenta"][:4], style="cylinder")
    _eye(c, s - 5, s - 28 + b, 2.5, "lime"); _eye(c, s + 5, s - 28 + b, 2.5, "lime")
    c.outline(OUTLINE, "selout")


def gardener_prime(c: Canvas, f: int, n: int) -> None:
    """Садовник-прайм: star-shaped gardening mech with giant shears."""
    s, b = c.w / 2, _bob(f, n, 2)
    snip = [0.35, 0.15, 0.0, 0.15][f % 4]
    for k in range(5):  # star legs
        a = TAU * k / 5 + math.pi / 2
        _limb(c, s, s + 6, s + math.cos(a) * 60, s + 10 + math.sin(a) * 44, 7, 4, CHROME[:5])
        c.paint(c.circle(s + math.cos(a) * 60, s + 10 + math.sin(a) * 44, 5), GLOW["lime"], style="dome")
    c.paint(c.circle(s, s + b, 34), CHROME[:5], style="dome", rim=NEON["lime"], rim_dir=(0.6, 0.8))
    c.paint(c.circle(s, s + b, 22), MOSS, style="dome", sep=True)
    for k in range(7):
        a = TAU * k / 7 + f * 0.2
        c.paint(c.circle(s + math.cos(a) * 14, s + b + math.sin(a) * 14, 3), GLOW["lime"] if k % 2 else GLOW["magenta"], style="dome")
    c.paint(c.circle(s, s + b, 7), GLOW["lime"], style="dome")
    for k, side in enumerate((-1, 1)):  # shears
        a = -math.pi / 2 + side * (0.25 + snip)
        x1, y1 = s + side * 30 + math.cos(a) * 44, s - 30 + b + math.sin(a) * 44
        c.paint(c.poly([(s + side * 30, s - 30 + b), (x1, y1), (x1 + side * 8, y1 + 6)]), STEEL, style="bevel", sep=True)
        c.flat(c.line(s + side * 30, s - 30 + b, x1, y1, 1), NEON["white"])
    c.paint(c.circle(s, s - 30 + b, 8), BRASS, style="dome", sep=True)
    c.outline(OUTLINE, "selout")


def furnace_drone(c: Canvas, f: int, n: int) -> None:
    """Печной дрон: big furnace drone with twin rotors."""
    s, b = c.w / 2, _bob(f, n, 2)
    for side in (-1, 1):
        c.paint(c.ellipse(s + side * 44, s - 30 + b, 26, 6), ["#0c0a14", "#26233a", "#5e5b7c"], style="flat")
        a = f / n * math.pi + side
        c.paint(c.capsule(s + side * 44 - math.cos(a) * 24, s - 30 + b, s + side * 44 + math.cos(a) * 24, s - 30 + b, 2), STEEL, style="cylinder")
        _limb(c, s + side * 20, s - 14 + b, s + side * 44, s - 28 + b, 4, 3, RUST)
    c.paint(c.rect(s - 36, s - 26 + b, 72, 58, 12), RUST, style="bevel", rim=NEON["amber"], rim_dir=(0.6, 0.8))
    c.paint(c.rect(s - 24, s - 12 + b, 48, 30, 6), ["#140402", "#2a0804", "#4a1006"], style="flat", sep=True)
    flame = 2 + (f % 2) * 3
    c.paint(c.ellipse(s, s + 4 + b, 18, 9 + flame * 0.5), GLOW["orange"], style="dome")
    c.paint(c.ellipse(s, s + 6 + b, 9, 4 + flame * 0.3), GLOW["amber"], style="dome")
    for k in range(5):
        c.flat(c.rect(s - 22 + k * 10, s - 12 + b, 4, 30), RUST[1])
    for side in (-1, 1):
        c.paint(c.rect(s + side * 28 - 4, s + 30 + b, 8, 10, 2), GUNMETAL, style="cylinder", sep=True)
        c.paint(c.circle(s + side * 28, s + 42 + b + (f % 2), 3), GLOW["orange"], style="dome")
    _eye(c, s - 10, s - 20 + b, 3, "amber"); _eye(c, s + 10, s - 20 + b, 3, "amber")
    c.outline(OUTLINE, "selout")


def rail_baron(c: Canvas, f: int, n: int) -> None:
    """Рельсовый барон: locomotive mech in a top hat."""
    s, b = c.w / 2, _bob(f, n, 1.5)
    wheel = f / n * TAU
    for side in (-1, 1):
        for k in range(2):
            x, y = s + side * (24 + k * 22), s + 44
            c.paint(c.circle(x, y, 11), GUNMETAL, style="dome")
            c.paint(c.ring(x, y, 8, 2), BRASS, style="cylinder")
            c.flat(c.line(x, y, x + math.cos(wheel + k) * 8, y + math.sin(wheel + k) * 8, 2), BRASS[3])
    c.paint(c.rect(s - 60, s + 14, 120, 24, 6), ["#140806", "#2a100a", "#4a1c10", "#6a2a16"], style="bevel", sep=True)
    c.paint(c.rect(s - 30, s - 30 + b, 60, 54, 10), RUST, style="bevel", rim=NEON["amber"], rim_dir=(0.6, 0.8))
    c.paint(c.circle(s, s - 2 + b, 20), BRASS, style="dome", sep=True)  # boiler face
    c.paint(c.circle(s, s - 2 + b, 12), GLOW["amber"], style="dome")
    c.flat(c.rect(s - 8, s + 6 + b, 16, 2), "#3a1c06")
    for side in (-1, 1):
        _eye(c, s + side * 7, s - 8 + b, 2.5, "red")
    c.paint(c.rect(s - 16, s - 70 + b, 32, 36, 4), ["#05030a", "#0b0714", "#16101e", "#221a2c"], style="bevel", sep=True)  # top hat
    c.paint(c.rect(s - 28, s - 38 + b, 56, 8, 3), ["#05030a", "#0b0714", "#16101e", "#221a2c"], style="bevel", sep=True)
    c.flat(c.rect(s - 16, s - 46 + b, 32, 4), NEON["amber"])
    for k in range(3):  # smoke stack puffs
        y = s - 74 - k * 8 - (f % 2) * 2
        c.paint(c.circle(s + 22 + k * 3, y, 4 + k), ["#1a1620", "#2a2430", "#3a3440"], style="dome")
    c.outline(OUTLINE, "selout")


def spire_herald(c: Canvas, f: int, n: int) -> None:
    """Глашатай шпиля: winged herald with a horn and halo."""
    s, b = c.w / 2, _bob(f, n, 2)
    flap = math.sin(TAU * f / n) * 6
    for side in (-1, 1):
        for k in range(4):
            c.paint(c.capsule(s + side * 10, s - 10 + b, s + side * (64 - k * 8), s - 30 + k * 14 + b - flap, 5 - k * 0.5, 2), MARBLE[1:] + ["#e6e2f6"], style="cylinder", sep=True)
    c.paint(c.poly([(s - 16, s - 20 + b), (s + 16, s - 20 + b), (s + 24, s + 44 + b), (s - 24, s + 44 + b)]), MARBLE, style="bevel", rim=NEON["white"], rim_dir=(0.6, 0.8))
    c.flat(c.rect(s - 2, s - 16 + b, 4, 56), NEON["white"])
    c.paint(c.circle(s, s - 32 + b, 11), MARBLE, style="dome", sep=True)
    c.flat(c.rect(s - 7, s - 33 + b, 14, 2), NEON["amber"])
    c.paint(c.ring(s, s - 50 + b, 12, 3), GLOW["amber"], style="cylinder")
    c.paint(c.capsule(s + 10, s - 24 + b, s + 34, s - 44 + b, 2, 6), BRASS, style="cylinder", sep=True)  # horn
    c.paint(c.ellipse(s + 35, s - 45 + b, 5, 7, 40), GLOW["amber"], style="dome")
    c.outline(OUTLINE, "selout")


def requiem(c: Canvas, f: int, n: int) -> None:
    """Реквием: the final conductor-angel with six wings and a void core."""
    s, b = c.w / 2, _bob(f, n, 2)
    flap = math.sin(TAU * f / n) * 5
    c.paint(c.ring(s, s - 10, 80, 3), GLOW["purple"][:4], style="cylinder")
    for k in range(10):
        a = TAU * k / 10 + f / n * TAU / 10
        c.paint(c.circle(s + math.cos(a) * 80, s - 10 + math.sin(a) * 80, 4), GLOW["white"] if k % 2 else GLOW["purple"], style="dome")
    for side in (-1, 1):
        for k in range(3):
            base = s - 30 + k * 26 + b
            tip_x, tip_y = s + side * (88 - k * 10), base - 30 + k * 10 - flap * (1 - k * 0.3)
            c.paint(c.poly([(s + side * 14, base), (tip_x, tip_y), (s + side * (54 - k * 6), base + 18)]), ["#05030a", "#120a20", "#24143a", "#3a2058", "#5a3080"], style="bevel", sep=True)
            c.flat(c.line(s + side * 16, base, tip_x, tip_y, 1.5), NEON["purple"] if k != 1 else NEON["white"])
    c.paint(c.poly([(s - 22, s - 30 + b), (s + 22, s - 30 + b), (s + 34, s + 70), (s - 34, s + 70)]), ["#05030a", "#0e0818", "#1a0e2c", "#2a1844", "#3e2460"], style="bevel", rim=NEON["purple"], rim_dir=(0.6, 0.8))
    c.paint(c.circle(s, s + 6 + b, 14), VOID[::-1], style="dome", sep=True)
    c.paint(c.circle(s, s + 6 + b, 6), GLOW["white"], style="dome")
    c.paint(c.ellipse(s, s - 46 + b, 12, 15), MARBLE, style="dome", sep=True)
    c.paint(c.rect(s - 10, s - 50 + b, 20, 6, 2), ["#05030a", "#0b0714"], style="flat")
    c.flat(c.rect(s - 7, s - 48 + b, 4, 2), NEON["purple"]); c.flat(c.rect(s + 3, s - 48 + b, 4, 2), NEON["purple"])
    c.paint(c.ring(s, s - 66 + b, 14, 3), GLOW["white"], style="cylinder")
    c.paint(c.capsule(s + 20, s - 10 + b, s + 46, s - 40 + b - flap, 1.5), GLOW["white"][1:], style="cylinder")  # baton
    c.outline(OUTLINE, "selout")


# ---------------------------------------------------------------- allies and props

def drone(c: Canvas, f: int, n: int) -> None:
    """Chorus drone (ally): lime tri-rotor."""
    s, b = c.w / 2, _bob(f, n, 1)
    for k in range(3):
        a = TAU * k / 3 - math.pi / 2
        x, y = s + math.cos(a) * 11, s + math.sin(a) * 9 + b
        c.paint(c.ellipse(x, y, 5, 2), ["#1a2a0c", "#3a5a1a", "#7aaa3a"] if (f + k) % 2 else ["#0c0a14", "#26233a", "#5e5b7c"], style="flat")
    c.paint(c.poly([(s, s - 9 + b), (s + 9, s + 6 + b), (s - 9, s + 6 + b)]), GUNMETAL, style="bevel", rim=NEON["lime"], rim_dir=(0.6, 0.8))
    _eye(c, s, s + 1 + b, 2.5, "lime")
    c.outline(OUTLINE)


def train(c: Canvas, f: int, n: int) -> None:
    """Monorail train for the Ashen Rail hazard (horizontal, faces right)."""
    w, h = c.w, c.h
    c.paint(c.rect(4, 6, w - 8, h - 14, 8), RUST, style="bevel", rim=NEON["amber"], rim_dir=(0.3, 1))
    c.paint(c.poly([(w - 34, 6), (w - 4, 20), (w - 4, h - 8), (w - 34, h - 8)]), BRASS, style="bevel", sep=True)
    for x in range(24, w - 50, 30):
        c.paint(c.rect(x, 12, 20, 12, 2), ["#140402", "#2a0804", "#4a1006"], style="flat", sep=True)
        c.flat(c.rect(x + 2, 14, 16, 8), NEON["amber"] if (x // 30 + f) % 3 else NEON["orange"])
    c.flat(c.rect(8, h - 14, w - 16, 2), NEON["amber"])
    c.paint(c.circle(w - 12, h // 2, 4), GLOW["white"], style="dome")
    c.outline(OUTLINE, "selout")


# id -> (canvas w, canvas h, frames, painter)
CREATURES = {
    "grunt": (64, 64, 4, grunt), "glitch_rat": (40, 40, 4, glitch_rat), "turret_bot": (64, 64, 4, turret_bot),
    "spark": (40, 40, 4, spark), "brute": (112, 112, 4, brute), "thug": (64, 64, 4, thug),
    "neon_sniper": (64, 64, 4, neon_sniper), "graffiti_bomber": (64, 64, 4, graffiti_bomber),
    "packet": (40, 40, 4, packet), "firewall": (64, 64, 4, firewall), "daemon": (64, 64, 4, daemon),
    "vine_crawler": (64, 64, 4, vine_crawler), "spore_pod": (64, 64, 4, spore_pod), "mantis": (64, 64, 4, mantis),
    "rail_jumper": (64, 64, 4, rail_jumper), "ember_drone": (64, 64, 4, ember_drone), "coal_golem": (112, 112, 4, coal_golem),
    "choir_wisp": (40, 40, 4, choir_wisp), "seraph_lance": (64, 64, 4, seraph_lance), "requiem_knight": (112, 112, 4, requiem_knight),
    "slum_enforcer": (176, 176, 4, slum_enforcer), "slum_king": (176, 176, 4, slum_king),
    "core_sentinel": (176, 176, 4, core_sentinel), "core_overseer": (176, 176, 4, core_overseer),
    "thorn_matriarch": (176, 176, 4, thorn_matriarch), "gardener_prime": (176, 176, 4, gardener_prime),
    "furnace_drone": (176, 176, 4, furnace_drone), "rail_baron": (176, 176, 4, rail_baron),
    "spire_herald": (176, 176, 4, spire_herald), "requiem": (208, 208, 4, requiem),
    "drone": (40, 40, 4, drone), "train": (420, 64, 2, train),
}


def frames(creature_id: str) -> list:
    w, h, count, painter = CREATURES[creature_id]
    out = []
    for f in range(count):
        c = Canvas(w, h)
        painter(c, f, count)
        out.append(c.image())
    return out
