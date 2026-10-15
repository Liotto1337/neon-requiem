"""Hero bodies and weapons at 16-px scale (shown x4), Soul Knight style.

Bodies are oval, three facings (side = right, mirrored in game; down; up) and 8 clips each:
idle, run, reload, reload_run, attack, hurt, levelup, cast. The weapon is a separate sprite
held at the hand and rotated to the aim in game; its manifest entry carries the grip pivot
and the muzzle point, so shots leave the barrel / blade tip / staff orb."""
from __future__ import annotations

import math

from palette import COAT, DARKCLOTH, GLOW, GUNMETAL, LEATHER, NEON, OUTLINE, SKIN, STEEL, TINT, BRASS
from pixlib import Canvas, hex_rgb, mix

S = 16
DIRS = ("side", "down", "up")
ROBE = ["#0e2018", "#1e4232", "#2e6048", "#448064"]
PLUM = ["#1c0f26", "#3a1e4c", "#58306e", "#76468e"]
NAVY = ["#121a30", "#24345a", "#36507e", "#4e6ea0"]

# clip -> list of poses; a pose: bob (body y), step (feet), sx/sy (squash), jump (whole sprite y),
# eyes ("normal" | "down" | "x" | "glow"), spark (sparkle ring frame or -1), lean (x shift).
CLIPS = {
    "idle": {"ms": 180, "loop": True, "poses": [dict(bob=0), dict(bob=0), dict(bob=1), dict(bob=1)]},
    "run": {"ms": 90, "loop": True, "poses": [dict(step=1, bob=0), dict(step=0, bob=-1), dict(step=-1, bob=0), dict(step=0, bob=-1)]},
    "reload": {"ms": 120, "loop": True, "poses": [dict(eyes="down"), dict(eyes="down", bob=1), dict(eyes="down"), dict(eyes="down", bob=1)]},
    "reload_run": {"ms": 90, "loop": True, "poses": [dict(step=1, eyes="down"), dict(step=0, bob=-1, eyes="down"),
                                                      dict(step=-1, eyes="down"), dict(step=0, bob=-1, eyes="down")]},
    "attack": {"ms": 60, "loop": False, "poses": [dict(lean=-1, sx=0.5), dict(lean=-1), dict(lean=0)]},
    "hurt": {"ms": 90, "loop": False, "poses": [dict(sx=1, sy=-1, eyes="x"), dict(eyes="x", lean=-1)]},
    "levelup": {"ms": 90, "loop": False, "poses": [dict(sx=1, sy=-1), dict(jump=-2, sy=0.5, spark=0), dict(jump=-3, spark=1, eyes="glow"),
                                                    dict(jump=-3, spark=2, eyes="glow"), dict(jump=-1, spark=3), dict(sx=1, sy=-1)]},
    "cast": {"ms": 70, "loop": False, "poses": [dict(sy=0.5, eyes="glow", spark=0), dict(sy=0.5, eyes="glow", spark=1),
                                                 dict(eyes="glow", spark=2), dict(spark=3)]},
}


def px(c: Canvas, pts, color: str) -> None:
    for x, y in pts:
        x, y = int(round(x)), int(round(y))
        if 0 <= x < c.w and 0 <= y < c.h:
            c.rgb[y, x] = hex_rgb(color)
            c.alpha[y, x] = True


def _feet(c: Canvas, d: str, step: int, color: str, y: int) -> None:
    if d == "side":
        px(c, [(6 + step, y), (7 + step, y), (9 - step, y), (10 - step, y)], color)
    else:
        lift_l = 1 if step > 0 else 0
        lift_r = 1 if step < 0 else 0
        px(c, [(5, y - lift_l), (6, y - lift_l), (10, y - lift_r), (11, y - lift_r)], color)


def _sparkles(c: Canvas, frame: int, color: str) -> None:
    if frame < 0:
        return
    r = 6 + frame
    for k in range(6):
        a = math.tau * k / 6 + frame * 0.4
        px(c, [(8 + math.cos(a) * r, 8 + math.sin(a) * r * 0.8)], color if k % 2 else "#ffffff")


def _eye_pair(d: str, cx: float, y: float, gap: float = 3.0) -> list:
    if d == "up":
        return []
    if d == "down":
        return [(cx - gap / 2, y), (cx + gap / 2, y)]
    return [(cx + 1.5, y), (cx + 3.5, y)]


def _eyes(c: Canvas, d: str, cx: float, y: float, mode: str, color: str) -> None:
    pts = _eye_pair(d, cx, y)
    if mode == "down":
        pts = [(x, y + 1) for x, y in pts]
    if mode == "x":
        for x, ey in pts:
            px(c, [(x, ey)], "#ffffff")
        return
    px(c, pts, "#ffffff" if mode == "glow" else color)


# ---------------------------------------------------------------- heroes

def _base_body(c: Canvas, ramp: list[str], pose: dict, d: str) -> tuple[float, float]:
    cx = 8 + pose.get("lean", 0) * (1 if d == "side" else 0)
    cy = 8.5 + pose.get("bob", 0) * 0.5 + pose.get("jump", 0)
    c.paint(c.ellipse(cx, cy, 5 + pose.get("sx", 0) * 0.5, 5.5 + pose.get("sy", 0) * 0.5), ramp, style="dome", dither=0.0)
    return cx, cy


def vector(c: Canvas, d: str, pose: dict) -> None:
    """Вектор: navy coat blob, spiky hair, cyan visor."""
    _feet(c, d, pose.get("step", 0), GUNMETAL[2], 14 + pose.get("jump", 0))
    cx, cy = _base_body(c, NAVY, pose, d)
    hair = [(cx - 2, cy - 5), (cx - 1, cy - 6), (cx, cy - 5), (cx + 1, cy - 6), (cx + 2, cy - 5)]
    if d == "side":
        hair = [(cx - 3, cy - 4), (cx - 2, cy - 5), (cx - 1, cy - 6), (cx, cy - 5), (cx + 1, cy - 5), (cx - 4, cy - 3)]
    px(c, hair, "#0e1426")
    if d == "down":
        px(c, [(cx - 3 + k, cy - 2) for k in range(7)], GLOW["cyan"][1])
    elif d == "side":
        px(c, [(cx + k, cy - 2) for k in range(5)], GLOW["cyan"][1])
    else:
        px(c, [(cx - 2 + k, cy - 3) for k in range(5)], "#0e1426")
    _eyes(c, d, cx, cy - 2, pose.get("eyes", "normal"), NEON["cyan"])
    px(c, [(cx - 2, cy + 3), (cx + 2, cy + 3)] if d == "down" else [(cx, cy + 3)], NAVY[3])
    _sparkles(c, pose.get("spark", -1), NEON["cyan"])
    c.outline(OUTLINE)


def katar(c: Canvas, d: str, pose: dict) -> None:
    """Катар: masked ninja blob with a magenta scarf."""
    step = pose.get("step", 0)
    _feet(c, d, step, PLUM[2], 14 + pose.get("jump", 0))
    cx, cy = _base_body(c, PLUM, pose, d)
    wave = [0, 1, 0, -1][(step + 2) % 4]
    if d == "side":
        px(c, [(cx - 4, cy + 1), (cx - 5, cy + 1 + wave), (cx - 6, cy + wave), (cx - 7, cy + 1 + wave)], TINT["magenta"][3])
    elif d == "up":
        px(c, [(cx - 1, cy + 1), (cx, cy + 1), (cx - 1, cy + 2), (cx - 2, cy + 3 + wave), (cx + 1, cy + 3)], TINT["magenta"][3])
    px(c, [(cx - 4 + k, cy + 1) for k in range(9)] if d != "side" else [(cx - 3 + k, cy + 1) for k in range(8)], TINT["magenta"][2])
    _eyes(c, d, cx, cy - 2, pose.get("eyes", "normal"), NEON["magenta"])
    px(c, [(cx - 1, cy - 6), (cx, cy - 6)], PLUM[3])
    _sparkles(c, pose.get("spark", -1), NEON["magenta"])
    c.outline(OUTLINE)


def chorus(c: Canvas, d: str, pose: dict) -> None:
    """Хор: hooded robe blob, shadowed face with lime eyes, a halo above."""
    _feet(c, d, pose.get("step", 0), ROBE[1], 14 + pose.get("jump", 0))
    cx, cy = _base_body(c, ROBE, pose, d)
    px(c, [(cx, cy - 6), (cx - 1, cy - 5)] if d != "side" else [(cx - 2, cy - 6), (cx - 2, cy - 5)], ROBE[2])
    if d != "up":
        fx = cx + (1.5 if d == "side" else 0)
        c.flat(c.ellipse(fx, cy - 2, 2.6 if d == "down" else 2.2, 2), "#05030a")
    _eyes(c, d, cx, cy - 2, pose.get("eyes", "normal"), NEON["lime"])
    halo_y = cy - 8
    px(c, [(cx - 2 + k, halo_y) for k in range(5)], NEON["lime"])
    px(c, [(cx - 3, halo_y + 1), (cx + 3, halo_y + 1)], GLOW["lime"][1])
    px(c, [(cx - 3 + k, cy + 3) for k in range(7)], GLOW["lime"][1])
    _sparkles(c, pose.get("spark", -1), NEON["lime"])
    c.outline(OUTLINE)


BODIES = {"vector": vector, "katar": katar, "chorus": chorus}


def hero_frames(hero: str) -> tuple[list, dict]:
    """All frames of a hero body and the clip table {"<clip>_<facing>": {frames, fps, loop}}."""
    frames: list = []
    clips: dict = {}
    for d in DIRS:
        for name, clip in CLIPS.items():
            start = len(frames)
            for pose in clip["poses"]:
                c = Canvas(S, S)
                BODIES[hero](c, d, pose)
                frames.append(c.image())
            clips["%s_%s" % (name, d)] = {"frames": list(range(start, len(frames))), "fps": round(1000.0 / clip["ms"], 3), "loop": clip["loop"]}
    return frames, clips


# ---------------------------------------------------------------- weapons (point right, grip = pivot)

def rifle(c: Canvas, clip: str, f: int) -> None:
    """Vector's rifle (18 x 7): flash on fire, magazine out / in on reload."""
    px(c, [(1, 3), (2, 3), (1, 4), (2, 4)], GUNMETAL[2])
    px(c, [(3 + k, 3) for k in range(9)] + [(3 + k, 2) for k in range(8)], GUNMETAL[2])
    px(c, [(4 + k, 2) for k in range(6)], STEEL[3])
    px(c, [(12, 3), (13, 3), (14, 3)], STEEL[2])
    px(c, [(5, 1), (6, 1), (7, 1)], GUNMETAL[3])
    px(c, [(4 + k, 3) for k in range(6)], GLOW["cyan"][2])
    mag = {"reload": [(8, 4), (8, 5), (9, 5)] if f in (0, 3) else ([] if f == 1 else [(8, 6), (9, 6)])}.get(clip, [(8, 4), (8, 5), (9, 5)])
    px(c, mag, STEEL[3])
    px(c, [(4, 4), (5, 4)], SKIN[2])
    if clip == "fire" and f == 0:
        px(c, [(15, 3), (16, 2), (16, 4), (17, 3)], "#ffffff")
        px(c, [(16, 3)], NEON["cyan"])
    c.outline(OUTLINE)


def katar_blade(c: Canvas, clip: str, f: int) -> None:
    """Katar's punch blade (14 x 9): magenta edge, slash trail, parry glow."""
    px(c, [(1, 4), (2, 4), (1, 5), (2, 5)], SKIN[2])
    px(c, [(3, 2), (3, 3), (3, 4), (3, 5), (3, 6)], BRASS[3])
    px(c, [(4 + k, 4) for k in range(8)] + [(4 + k, 5) for k in range(6)], STEEL[3])
    px(c, [(4 + k, 3) for k in range(7)], NEON["magenta"])
    px(c, [(12, 4)], "#ffffff")
    if clip == "slash":
        px(c, [(5 + k, 1) for k in range(6 - f * 2)], GLOW["magenta"][2])
        px(c, [(6 + k, 7) for k in range(5 - f * 2)], GLOW["magenta"][1])
    if clip == "parry":
        px(c, [(4 + k, 2) for k in range(8)], "#ffffff" if f == 0 else NEON["magenta"])
    c.outline(OUTLINE)


def staff(c: Canvas, clip: str, f: int) -> None:
    """Chorus's staff (17 x 9): brass rod, lime orb that pulses and flares when casting."""
    px(c, [(k, 4) for k in range(1, 12)], BRASS[2])
    px(c, [(k, 3) for k in range(1, 11)], BRASS[3])
    px(c, [(4, 5), (5, 5)], ROBE[3])
    r = 2 if (clip == "idle" and f % 2 == 0) else 2.6
    c.paint(c.circle(13.5, 4, r), GLOW["lime"], style="dome", dither=0.0)
    px(c, [(13, 3)], "#ffffff")
    if clip == "cast":
        px(c, [(16, 1), (16, 7), (11, 1), (11, 7)] if f == 0 else [(16, 4), (13, 0), (13, 8)], NEON["lime"])
    c.outline(OUTLINE)


def enemy_rifle(c: Canvas, clip: str, f: int) -> None:
    """Neon sniper's long rifle (16 x 5)."""
    px(c, [(k, 2) for k in range(1, 14)], GUNMETAL[2])
    px(c, [(k, 1) for k in range(2, 9)], GUNMETAL[3])
    px(c, [(4, 3), (5, 3)], COAT[3])
    px(c, [(3 + k, 2) for k in range(5)], GLOW["cyan"][1])
    if clip == "fire" and f == 0:
        px(c, [(14, 2), (15, 1), (15, 3)], "#ffffff")
    c.outline(OUTLINE)


def spear(c: Canvas, clip: str, f: int) -> None:
    """Seraph's lance (18 x 5)."""
    px(c, [(k, 2) for k in range(1, 13)], BRASS[3])
    px(c, [(13, 1), (13, 2), (13, 3), (14, 2), (15, 2), (16, 2)], "#dcdcf0")
    if clip == "fire" and f == 0:
        px(c, [(16, 1), (16, 3)], NEON["white"])
    c.outline(OUTLINE)


# id -> (w, h, painter, pivot (grip), muzzle, {clip: (frames, ms, loop)})
WEAPONS = {
    "rifle": (19, 9, rifle, (4, 4), (17, 3), {"idle": (1, 200, True), "fire": (2, 50, False), "reload": (4, 120, True)}),
    "katar": (15, 10, katar_blade, (2, 5), (13, 5), {"idle": (1, 200, True), "slash": (3, 50, False), "parry": (2, 80, True)}),
    "staff": (18, 10, staff, (5, 5), (14, 4), {"idle": (2, 300, True), "cast": (2, 80, False)}),
    "enemy_rifle": (17, 6, enemy_rifle, (4, 3), (15, 2), {"idle": (1, 200, True), "fire": (2, 60, False)}),
    "spear": (19, 6, spear, (3, 2), (17, 2), {"idle": (1, 200, True), "fire": (2, 60, False)}),
}
HERO_WEAPON = {"vector": "rifle", "katar": "katar", "chorus": "staff"}


def weapon_frames(weapon: str) -> tuple[list, dict]:
    w, h, painter, _pivot, _muzzle, clips = WEAPONS[weapon]
    frames: list = []
    table: dict = {}
    for name, (count, ms, loop) in clips.items():
        start = len(frames)
        for f in range(count):
            c = Canvas(w, h)
            painter(c, name, f)
            frames.append(c.image())
        table[name] = {"frames": list(range(start, len(frames))), "fps": round(1000.0 / ms, 3), "loop": loop}
    return frames, table
