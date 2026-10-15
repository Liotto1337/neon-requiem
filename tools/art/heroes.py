"""Hero rigs for codeart2d `rig_animate.py` (code-drawn skeletal pixel art, no image model).

Each hero is a portable SVG rig (bones + slots) plus a `codeart2d.rig_anim.v1` file, both
generated here in a 64 px "design space" and scaled by K into a 96x96 frame. Clips: idle,
run, reload, attack, hurt, levelup, cast; reload_run is composed from the run legs and
the reload upper body (rendered as separate clips with the other half hidden)."""
from __future__ import annotations

import json
import math

K = 1.45
SIZE = 96
AX, AY = 48.0, 92.0
OUTLINE = "#0b0714"


def P(x: float, y: float) -> tuple[float, float]:
    return round(AX + (x - 32.0) * K, 3), round(AY + (y - 59.0) * K, 3)


def L(v: float) -> float:
    return round(v * K, 3)


# ---------------------------------------------------------------- svg building

def rect(cls: str, x, y, w, h, rx=0.0, z=None, extra="") -> str:
    px, py = P(x, y)
    zz = f' data-z="{z}"' if z is not None else ""
    return f'<rect class="c-{cls} c-out"{zz} x="{px}" y="{py}" width="{L(w)}" height="{L(h)}" rx="{L(rx)}"{extra}/>'


def circle(cls: str, cx, cy, r, z=None) -> str:
    px, py = P(cx, cy)
    zz = f' data-z="{z}"' if z is not None else ""
    return f'<circle class="c-{cls} c-out"{zz} cx="{px}" cy="{py}" r="{L(r)}"/>'


def ellipse(cls: str, cx, cy, rx, ry, z=None) -> str:
    px, py = P(cx, cy)
    zz = f' data-z="{z}"' if z is not None else ""
    return f'<ellipse class="c-{cls} c-out"{zz} cx="{px}" cy="{py}" rx="{L(rx)}" ry="{L(ry)}"/>'


def poly(cls: str, pts, z=None) -> str:
    zz = f' data-z="{z}"' if z is not None else ""
    coords = " ".join("%s,%s" % P(x, y) for x, y in pts)
    return f'<polygon class="c-{cls} c-out"{zz} points="{coords}"/>'


def ring(cls: str, cx, cy, r, width, n=16) -> str:
    """Closed ring as one polygon (outer loop, then the inner loop reversed: a hole under nonzero fill)."""
    outer = [(cx + r * math.cos(math.tau * i / n), cy + r * math.sin(math.tau * i / n)) for i in range(n + 1)]
    inner = [(cx + (r - width) * math.cos(math.tau * i / n), cy + (r - width) * math.sin(math.tau * i / n)) for i in range(n, -1, -1)]
    return poly(cls, outer + inner)


def bone(bid: str, pivot, children: list[str], z=None) -> str:
    px, py = P(*pivot)
    zz = f' data-z="{z}"' if z is not None else ""
    return f'<g id="{bid}" data-pivot="{px} {py}"{zz}>' + "".join(children) + "</g>"


def svg(fills: dict[str, str], root_children: list[str]) -> str:
    style = " ".join(f".c-{k}{{fill:{v}}}" for k, v in fills.items())
    ax, ay = AX, AY
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" viewBox="0 0 {SIZE} {SIZE}" '
            f'data-codeart="rig.v1" data-anchor="{ax} {ay}" data-ground="{ay + 1}" data-facing="right" data-outline="{OUTLINE}">'
            f'<style>.c-out{{stroke:{OUTLINE};stroke-width:1}} {style}</style>'
            + bone("root", (32, 59), root_children) + "</svg>")


def legs(pants: str, pants_b: str, boot: str, boot_b: str) -> tuple[list[str], list[str]]:
    back = [bone("thigh_b", (31, 38), [rect(pants_b, 28.25, 36.5, 5.5, 12, 2.5),
            bone("shin_b", (31, 47.5), [rect(pants_b, 28.75, 46.75, 4.5, 11.25, 2),
                 bone("foot_b", (31, 57), [rect(boot_b, 28.5, 55.5, 8, 3.5, 1.25)], z=11)])], z=10)]
    front = [bone("thigh_f", (33, 38), [rect(pants, 30.25, 36.5, 5.5, 12, 2.5),
             bone("shin_f", (33, 47.5), [rect(pants, 30.75, 46.75, 4.5, 11.25, 2),
                  bone("foot_f", (33, 57), [rect(boot, 30.5, 55.5, 8, 3.5, 1.25)], z=51)])], z=50)]
    return back, front


def ramp(hi: str, mid: str, lo: str, dark: str, out: str = "#0b0714") -> dict:
    return {"hi": hi, "mid": mid, "lo": lo, "dark": dark, "out": out}


# ---------------------------------------------------------------- heroes

def vector_rig() -> tuple[str, dict, dict]:
    fills = {"skin": "#a86a54", "hair": "#263258", "coat": "#3a3a62", "coatb": "#1e1e34", "pants": "#26263a",
             "pantsb": "#18182a", "boot": "#2e2224", "bootb": "#1e1416", "gun": "#3a3a55", "mag": "#4a4a66",
             "neon": "#00f0ff", "hot": "#c8fcff", "flash": "#ffffff", "aura": "#00f0ff", "belt": "#3a2a24"}
    ramps = {"c-skin": ramp("#d09a7c", "#a86a54", "#7a4638", "#4a2420"), "c-hair": ramp("#3a4a7a", "#263258", "#182040", "#0c1024"),
             "c-coat": ramp("#5c5c8c", "#3a3a62", "#26263f", "#151526"), "c-coatb": ramp("#3a3a62", "#26263f", "#191930", "#0e0e1c"),
             "c-pants": ramp("#3a3a50", "#26263a", "#18182a", "#0e0e1a"), "c-pantsb": ramp("#26263a", "#18182a", "#101020", "#0a0a14"),
             "c-boot": ramp("#4a3a3a", "#2e2224", "#1e1416", "#120a0c"), "c-bootb": ramp("#2e2224", "#1e1416", "#140c0e", "#0c0608"),
             "c-gun": ramp("#6a6a8a", "#3a3a55", "#26263a", "#14141f"), "c-mag": ramp("#7a7a9a", "#4a4a66", "#30304a", "#1a1a28")}
    back_leg, front_leg = legs("pants", "pantsb", "boot", "bootb")
    gun = bone("gun", (40, 35), [
        poly("gun", [(31.5, 34), (36, 33.6), (36, 36.8), (32.5, 38.4)]),
        rect("gun", 35, 32.4, 12.5, 4.2, 1), rect("gun", 47, 33.1, 8, 2, 0.5), rect("gun", 39, 30.6, 5.5, 2, 0.6),
        rect("neon", 36.5, 33.3, 9.5, 1.0), rect("hot", 54.6, 33.2, 1.0, 1.8),
        bone("gun_mag", (42, 37), [rect("mag", 40.6, 36.4, 3.0, 5.0, 0.6)]),
        bone("flash", (57, 34), [poly("flash", [(55.5, 34), (58, 31.5), (58.8, 33.4), (62, 34), (58.8, 34.8), (58, 36.6)])], z=70),
    ], z=62)
    front_arm = bone("arm_f", (34, 29.5), [rect("coat", 32, 28.2, 4.2, 7.4, 2),
        bone("fore_f", (34, 35), [rect("coat", 33, 33.4, 7.2, 3.2, 1.5), circle("skin", 40.6, 35, 1.7), gun,
             bone("cast_fx", (41, 35), [ring("aura", 41, 35, 3.2, 1.0, 12), circle("hot", 41, 35, 0.9)], z=72)])], z=60)
    back_arm = bone("arm_b", (31.5, 29.5), [rect("coatb", 29.5, 28.2, 4.2, 7.4, 2),
        bone("fore_b", (31.5, 35), [rect("coatb", 30.5, 33.6, 13, 3, 1.4), circle("skin", 44.2, 35.2, 1.6),
             bone("mag_hand", (44, 37), [rect("mag", 42.6, 36.2, 3.0, 5.0, 0.6)])])], z=5)
    head = bone("head", (33, 27), [circle("skin", 34, 20, 7.5),
        poly("hair", [(26.5, 21.5), (25.5, 15), (28, 11.5), (31, 13), (32.5, 10), (35.5, 12.2), (38.5, 10.5), (40, 13.5), (42, 15.5), (38, 16.2), (35, 15), (31, 17), (29.6, 22.5)], z=41),
        rect("neon", 33.5, 18.4, 8.4, 2.2, 0.8, z=42), rect("hot", 39.5, 18.6, 2, 1.2, z=43)], z=40)
    torso = bone("torso", (32, 38), [back_arm,
        rect("coat", 27.6, 26.8, 10.8, 13, 3, z=30), rect("neon", 36.6, 28, 1.0, 10.5, z=31), rect("belt", 28.2, 36, 10, 1.8, z=31),
        poly("coat", [(27, 26.5), (31, 25.8), (33, 28.5)], z=32), head, front_arm], z=None)
    skirt = bone("skirt", (32, 38), [poly("coat", [(27.6, 37.5), (38.4, 37.5), (39.8, 47.5), (26.2, 48.5)]),
                                      rect("neon", 26.6, 47.2, 12.8, 0.9)], z=55)
    aura = bone("aura", (32, 36), [ring("aura", 32, 36, 14, 1.6, 20)], z=1)
    root = [aura, bone("hips", (32, 38), back_leg + [torso, skirt] + front_leg)]
    hidden = ["flash", "mag_hand", "cast_fx", "aura"]
    return svg(fills, root), ramps, {"hidden": hidden, "weapon": "rifle"}


def katar_rig() -> tuple[str, dict, dict]:
    fills = {"suit": "#422650", "suitb": "#201228", "wrap": "#8a80a0", "mask": "#1c1424", "scarf": "#ae2566",
             "blade": "#7a7e98", "neon": "#ff2e88", "hot": "#ffd0e4", "skin": "#a86a54", "boot": "#241a2a", "bootb": "#160e1a",
             "trail": "#ff2e88", "aura": "#ff2e88", "flash": "#ffffff"}
    ramps = {"c-suit": ramp("#64406e", "#422650", "#2a1834", "#180c20"), "c-suitb": ramp("#422650", "#2a1834", "#1c1026", "#100816"),
             "c-wrap": ramp("#b8aec8", "#8a80a0", "#605878", "#3a3450"), "c-mask": ramp("#4a3a5c", "#2a2036", "#1a1424", "#0c0812"),
             "c-scarf": ramp("#d12974", "#ae2566", "#8c2157", "#621840"), "c-blade": ramp("#b9bdd2", "#7a7e98", "#4a4e66", "#2a2c3e"),
             "c-boot": ramp("#3a2e44", "#241a2a", "#160e1a", "#0c0610"), "c-bootb": ramp("#241a2a", "#160e1a", "#0e0812", "#08040a")}
    back_leg, front_leg = legs("suit", "suitb", "boot", "bootb")

    def katar(prefix: str, x: float, y: float, z: int, cls_blade="blade") -> str:
        return bone(prefix + "_blade", (x, y), [
            rect("wrap", x - 1.6, y - 1.6, 3.4, 3.2, 0.8),
            poly(cls_blade, [(x + 1, y - 1.6), (x + 11.5, y - 0.4), (x + 13.5, y), (x + 11.5, y + 0.6), (x + 1, y + 1.6)]),
            rect("neon", x + 2, y - 0.3, 9.5, 0.8)], z=z)
    front_arm = bone("arm_f", (34, 29.5), [rect("suit", 32, 28.2, 4.0, 7.4, 2),
        bone("fore_f", (34, 35), [rect("wrap", 33, 33.5, 6.6, 3.0, 1.4), katar("f", 40, 35, 63),
             bone("cast_fx", (41, 35), [ring("aura", 41, 35, 3.2, 1.0, 12), circle("hot", 41, 35, 0.9)], z=72)])], z=60)
    back_arm = bone("arm_b", (31.5, 29.5), [rect("suitb", 29.5, 28.2, 4.0, 7.4, 2),
        bone("fore_b", (31.5, 35), [rect("wrap", 30.5, 33.5, 7.0, 3.0, 1.4), katar("b", 38, 35, 6)])], z=5)
    scarf = bone("scarf", (30, 25.5), [poly("scarf", [(31, 23.8), (24, 23.5), (17, 25), (14.5, 28.5), (19, 27.2), (24.5, 27.4), (31, 27.4)])], z=35)
    head = bone("head", (33, 27), [circle("mask", 34, 20, 7.3),
        rect("scarf", 27.5, 22.8, 13.2, 4.2, 2, z=41), rect("neon", 34.5, 17.6, 7.2, 1.6, 0.6, z=42), rect("hot", 39.6, 17.8, 1.6, 1.1, z=43),
        poly("mask", [(28, 14), (33, 11.5), (37, 13)], z=41), scarf], z=40)
    torso = bone("torso", (32, 38), [back_arm,
        rect("suit", 28, 27, 10, 12.5, 3, z=30), rect("neon", 28.6, 36.2, 9, 1.0, z=31), rect("wrap", 29, 29, 8, 1.4, z=31),
        head, front_arm,
        bone("trail", (36, 30), [poly("trail", [(30, 14), (42, 15.5), (51, 24), (54, 36), (50, 45), (51, 35), (47, 24), (38, 17)])], z=75),
        bone("parry_fx", (41, 22), [poly("flash", [(41, 15), (43, 20.5), (48.5, 22), (43, 23.5), (41, 29), (39, 23.5), (33.5, 22), (39, 20.5)])], z=76)])
    aura = bone("aura", (32, 36), [ring("aura", 32, 36, 14, 1.6, 20)], z=1)
    root = [aura, bone("hips", (32, 38), back_leg + [torso] + front_leg)]
    hidden = ["trail", "parry_fx", "cast_fx", "aura"]
    return svg(fills, root), ramps, {"hidden": hidden, "weapon": "katar"}


def chorus_rig() -> tuple[str, dict, dict]:
    fills = {"robe": "#285646", "robeb": "#142a24", "hood": "#05030a", "skin": "#9aa28a", "staff": "#6a4a14",
             "neon": "#b6ff00", "hot": "#f0ffd0", "pants": "#1a1e24", "pantsb": "#101418", "boot": "#22262e", "bootb": "#14181e",
             "drone": "#26233a", "aura": "#b6ff00", "ring": "#b6ff00", "trim": "#3a5a2a"}
    ramps = {"c-robe": ramp("#3e7a62", "#285646", "#1a3a30", "#0e2018"), "c-robeb": ramp("#285646", "#1a3a30", "#102620", "#081610"),
             "c-skin": ramp("#c8d0b8", "#9aa28a", "#6a7260", "#3a4034"), "c-staff": ramp("#c4983c", "#6a4a14", "#4a3010", "#2a1a08"),
             "c-pants": ramp("#2a2e38", "#1a1e24", "#101418", "#080a0e"), "c-pantsb": ramp("#1a1e24", "#101418", "#0a0c10", "#060708"),
             "c-boot": ramp("#3a3e4a", "#22262e", "#14181e", "#0a0c10"), "c-bootb": ramp("#22262e", "#14181e", "#0c0e12", "#06070a"),
             "c-drone": ramp("#5e5b7c", "#26233a", "#18162a", "#0c0a14"), "c-trim": ramp("#5a8a3a", "#3a5a2a", "#26401c", "#142410")}
    back_leg, front_leg = legs("pants", "pantsb", "boot", "bootb")
    staff = bone("staff", (40, 35), [rect("staff", 39.6, 18.5, 1.9, 34, 0.8),
        circle("neon", 40.5, 17.0, 3.0), circle("hot", 40.0, 16.4, 1.2),
        bone("ring_fx", (40.5, 17), [ring("ring", 40.5, 17, 7, 1.2, 16)], z=71)], z=62)
    front_arm = bone("arm_f", (34, 29.5), [rect("robe", 31.8, 28.2, 4.6, 7.6, 2),
        bone("fore_f", (34, 35), [rect("robe", 33, 33.2, 6.8, 3.6, 1.6), circle("skin", 40.5, 35, 1.7), staff,
             bone("cast_fx", (41, 35), [ring("aura", 41, 35, 3.2, 1.0, 12), circle("hot", 41, 35, 0.9)], z=72)])], z=60)
    back_arm = bone("arm_b", (31.5, 29.5), [rect("robeb", 29.3, 28.2, 4.6, 7.6, 2),
        bone("fore_b", (31.5, 35), [rect("robeb", 30.5, 33.4, 7.5, 3.4, 1.5), circle("skin", 38.5, 35, 1.6)])], z=5)
    head = bone("head", (33, 27), [circle("robe", 33.5, 20, 8),
        poly("robe", [(27, 16), (30, 10), (33, 12.5)], z=41), ellipse("hood", 36.2, 21.2, 4.6, 5.2, z=42),
        rect("neon", 36.4, 19.6, 1.6, 1.6, z=43), rect("neon", 39.2, 19.6, 1.6, 1.6, z=43),
        bone("halo", (33.5, 10), [ellipse("neon", 33.5, 9.5, 6.5, 1.5)], z=44)], z=40)
    torso = bone("torso", (32, 38), [back_arm,
        rect("robe", 27.4, 26.6, 11.2, 14, 3.5, z=30), rect("trim", 32, 27, 1.6, 13, z=31), rect("neon", 27.8, 32, 10.4, 1.0, z=31),
        head, front_arm], z=None)
    skirt = bone("skirt", (32, 38), [poly("robe", [(27.2, 37.5), (38.8, 37.5), (41.5, 52), (25, 52.5)]),
                                      rect("neon", 25.4, 51.2, 15.8, 1.0)], z=55)
    pet = bone("pet", (18, 20), [poly("drone", [(18, 16.5), (22, 23), (14, 23)]), circle("neon", 18, 20.8, 1.3),
                                 rect("drone", 13, 15.5, 4, 1), rect("drone", 19, 15.5, 4, 1)], z=80)
    aura = bone("aura", (32, 36), [ring("aura", 32, 36, 14, 1.6, 20)], z=1)
    root = [aura, pet, bone("hips", (32, 38), back_leg + [torso, skirt] + front_leg)]
    hidden = ["ring_fx", "cast_fx", "aura"]
    return svg(fills, root), ramps, {"hidden": hidden, "weapon": "staff"}


RIGS = {"vector": vector_rig, "katar": katar_rig, "chorus": chorus_rig}


# ---------------------------------------------------------------- animation

def T(keys):
    """Scale translate keys from design px to rig px."""
    return [[t, [L(v[0]), L(v[1])]] for t, v in keys]


def gait_ik(stride: float, stance: float, lift: float) -> dict:
    return {
        "leg_f": {"bones": ["thigh_f", "shin_f"], "end": "foot_f", "pole": [1, 0],
                  "gait": {"phase": 0.0625, "stance": stance, "lift": L(lift), "roll": 18, "x": P(33.5, 0)[0]}},
        "leg_b": {"bones": ["thigh_b", "shin_b"], "end": "foot_b", "pole": [1, 0],
                  "gait": {"phase": 0.5625, "stance": stance, "lift": L(lift), "roll": 18, "x": P(31.5, 0)[0]}},
    }


RUN_BOB = [2.0, 1.2, 0.5, 1.2, 2.0, 1.2, 0.5, 1.2]
RUN_HIPS = [[i / 8, [0, RUN_BOB[i % 8]]] for i in range(9)]


def hide_tracks(hidden: list[str], shown: dict[str, list] | None = None) -> dict:
    out = {}
    for bid in hidden:
        out[bid] = {"show": (shown or {}).get(bid, [[0, False]])}
    return out


def merge(*parts: dict) -> dict:
    out: dict = {}
    for part in parts:
        for bid, tracks in part.items():
            out.setdefault(bid, {}).update(tracks)
    return out


def arms_run(meta: dict) -> dict:
    if meta["weapon"] == "katar":  # blades trailing behind, ninja run
        return {"arm_f": {"rotate": [[0, 50], [0.5, 30], [1, 50]], "ease": "sine"}, "fore_f": {"rotate": [[0, -30], [0.5, -20], [1, -30]], "ease": "sine"},
                "arm_b": {"rotate": [[0, 40], [0.5, 60], [1, 40]], "ease": "sine"}, "fore_b": {"rotate": [[0, -20], [0.5, -35], [1, -20]], "ease": "sine"}}
    return {"arm_f": {"rotate": [[0, -6], [0.5, 4], [1, -6]], "ease": "sine"}, "arm_b": {"rotate": [[0, 4], [0.5, -6], [1, 4]], "ease": "sine"}}


def staff_keep(meta: dict, keys: list) -> dict:
    """Chorus keeps the staff upright while the arm moves: counter-rotate by -(arm + fore)."""
    return {"staff": {"rotate": keys, "ease": "sine"}} if meta["weapon"] == "staff" else {}


def clips_for(hero: str, meta: dict) -> dict:
    hidden = meta["hidden"]
    weapon = meta["weapon"]
    extra_idle = {"scarf": {"rotate": [[0, 0], [0.5, -6], [1, 0]], "ease": "sine"}} if weapon == "katar" else {}
    if weapon == "staff":
        extra_idle = {"pet": {"translate": T([[0, [0, 0]], [0.5, [0, -2]], [1, [0, 0]]]), "ease": "sine"}}
    clips = {}
    clips["idle"] = {"frames": 6, "loop": True, "duration_ms": 150, "tracks": merge(hide_tracks(hidden), {
        "torso": {"translate": T([[0, [0, 0]], [0.5, [0, 0.7]], [1, [0, 0]]]), "ease": "sine"},
        "head": {"rotate": [[0, 0], [0.5, 3], [1, 0]], "ease": "sine"},
        "arm_f": {"rotate": [[0, 0], [0.5, -3], [1, 0]], "ease": "sine"}}, extra_idle)}
    run_extra = {"scarf": {"rotate": [[0, 10], [0.25, 22], [0.5, 10], [0.75, 22], [1, 10]], "ease": "sine"}} if weapon == "katar" else {}
    if weapon == "staff":
        run_extra = {"pet": {"translate": T([[0, [-3, 0]], [0.5, [-3, -2]], [1, [-3, 0]]]), "ease": "sine"}}
    run_tracks = merge(hide_tracks(hidden), {"hips": {"translate": T(RUN_HIPS)}, "torso": {"rotate": [[0, 7], [1, 7]]},
                                             "head": {"rotate": [[0, -4], [0.25, -2], [0.5, -4], [0.75, -2], [1, -4]], "ease": "sine"}},
                       arms_run(meta), run_extra)
    clips["run"] = {"frames": 8, "loop": True, "duration_ms": 75, "stride_world_units": L(26), "tracks": run_tracks, "ik": gait_ik(26, 0.55, 4)}
    clips["run_lower"] = {"frames": 8, "loop": True, "duration_ms": 75, "stride_world_units": L(26),
                          "tracks": merge(run_tracks, {"torso": {"show": [[0, False]]}, "pet": {"show": [[0, False]]}} if weapon == "staff" else merge(run_tracks, {"torso": {"show": [[0, False]]}})),
                          "ik": gait_ik(26, 0.55, 4)}
    reload_tracks, reload_frames, reload_ms = reload_clip(meta)
    clips["reload"] = {"frames": reload_frames, "loop": False, "duration_ms": reload_ms, "tracks": reload_tracks}
    lower_bones = ["thigh_f", "thigh_b"] + (["skirt"] if weapon != "katar" else [])
    upper = merge(reload_tracks, {bid: {"show": [[0, False]]} for bid in lower_bones})
    upper["torso"] = dict(upper.get("torso", {}))
    upper["torso"]["rotate"] = [[0, 7], [1, 7]]
    bob = RUN_BOB
    keys = []
    for i in range(reload_frames):
        j = int(i * reload_ms / 75) % 8
        keys.append([round(i / (reload_frames - 1), 5), [0, L(bob[j])]])
    upper["hips"] = {"translate": keys}
    clips["reload_upper"] = {"frames": reload_frames, "loop": False, "duration_ms": reload_ms, "tracks": upper, "grounded": False}
    clips["attack"] = attack_clip(meta)
    clips["hurt"] = {"frames": 4, "loop": False, "duration_ms": 70, "tracks": merge(hide_tracks(hidden), {
        "torso": {"rotate": [[0, 0], [0.3, -12], [1, -2]], "translate": T([[0, [0, 0]], [0.3, [-1.5, 0.5]], [1, [0, 0]]]), "ease": "out"},
        "head": {"rotate": [[0, 0], [0.3, -18], [1, -3]], "ease": "out"},
        "arm_f": {"rotate": [[0, 0], [0.3, -25], [1, 0]], "ease": "out"}, "arm_b": {"rotate": [[0, 0], [0.3, -35], [1, 0]], "ease": "out"}})}
    clips["levelup"] = {"frames": 10, "loop": False, "duration_ms": 80, "tracks": merge(hide_tracks(hidden, {"aura": [[0, False], [0.2, True], [0.95, False]]}), {
        "aura": {"scale": [[0, 0.3], [0.2, 0.4], [0.7, 1.15], [1, 1.3]], "ease": "out"},
        "torso": {"translate": T([[0, [0, 0]], [0.2, [0, 2]], [0.45, [0, -1.5]], [1, [0, 0]]]), "ease": "sine"},
        "head": {"rotate": [[0, 0], [0.2, 10], [0.45, -14], [1, 0]], "ease": "sine"},
        "arm_f": {"rotate": [[0, 0], [0.2, 20], [0.45, -150], [0.8, -150], [1, 0]], "ease": "sine"},
        "fore_f": {"rotate": [[0, 0], [0.45, -30], [0.8, -30], [1, 0]], "ease": "sine"},
        "arm_b": {"rotate": [[0, 0], [0.2, 20], [0.45, -140], [0.8, -140], [1, 0]], "ease": "sine"}},
        staff_keep(meta, [[0, 0], [0.2, -20], [0.45, 180], [0.8, 180], [1, 0]]))}
    clips["cast"] = {"frames": 6, "loop": False, "duration_ms": 65, "tracks": merge(hide_tracks(hidden, {"cast_fx": [[0, False], [0.2, True], [0.9, False]]}), {
        "cast_fx": {"scale": [[0, 0.4], [0.2, 0.6], [0.6, 1.6], [1, 2.0]], "ease": "out"},
        "arm_f": {"rotate": [[0, 0], [0.25, -55], [0.7, -55], [1, 0]], "ease": "out"},
        "fore_f": {"rotate": [[0, 0], [0.25, -25], [0.7, -25], [1, 0]], "ease": "out"},
        "torso": {"rotate": [[0, 0], [0.25, 5], [1, 0]], "ease": "out"}},
        staff_keep(meta, [[0, 0], [0.25, 70], [0.7, 70], [1, 0]]))}
    return clips


def reload_clip(meta: dict) -> tuple[dict, int, int]:
    hidden = meta["hidden"]
    if meta["weapon"] == "rifle":
        tracks = merge(hide_tracks(hidden, {"mag_hand": [[0, False], [0.32, True], [0.66, False]]}), {
            "gun_mag": {"show": [[0, True], [0.18, False], [0.66, True]]},
            "gun": {"rotate": [[0, 0], [0.15, -16], [0.6, -16], [0.72, -26], [0.85, -6], [1, 0]], "ease": "sine"},
            "arm_b": {"rotate": [[0, 0], [0.15, 12], [0.3, 28], [0.55, -4], [0.7, 0], [1, 0]], "ease": "sine"},
            "fore_b": {"rotate": [[0, 0], [0.15, 70], [0.3, 96], [0.55, 30], [0.68, -6], [0.78, 0], [1, 0]], "ease": "sine"},
            "head": {"rotate": [[0, 0], [0.2, 12], [0.7, 12], [1, 0]], "ease": "sine"},
            "arm_f": {"rotate": [[0, 0], [0.2, -6], [0.8, -6], [1, 0]], "ease": "sine"}})
        return tracks, 16, 75
    if meta["weapon"] == "katar":
        tracks = merge(hide_tracks(hidden, {"parry_fx": [[0, False], [0.3, True], [0.75, False]]}), {
            "parry_fx": {"scale": [[0, 0.5], [0.3, 0.7], [0.5, 1.3], [0.75, 0.8], [1, 0.5]], "ease": "out"},
            "arm_f": {"rotate": [[0, 0], [0.3, -40], [0.75, -40], [1, 0]], "ease": "out"},
            "fore_f": {"rotate": [[0, 0], [0.3, -75], [0.75, -75], [1, 0]], "ease": "out"},
            "arm_b": {"rotate": [[0, 0], [0.3, -25], [0.75, -25], [1, 0]], "ease": "out"},
            "fore_b": {"rotate": [[0, 0], [0.3, -85], [0.75, -85], [1, 0]], "ease": "out"},
            "torso": {"translate": T([[0, [0, 0]], [0.3, [0, 1.5]], [0.75, [0, 1.5]], [1, [0, 0]]]), "ease": "out"},
            "scarf": {"rotate": [[0, 0], [0.3, 15], [1, 0]], "ease": "out"}})
        return tracks, 8, 50
    tracks = merge(hide_tracks(hidden, {"ring_fx": [[0, False], [0.3, True], [0.9, False]]}), {
        "ring_fx": {"scale": [[0, 0.4], [0.3, 0.5], [0.9, 1.25], [1, 1.3]], "ease": "out"},
        "arm_f": {"rotate": [[0, 0], [0.3, -50], [0.8, -50], [1, 0]], "ease": "sine"},
        "fore_f": {"rotate": [[0, 0], [0.3, -15], [0.8, -15], [1, 0]], "ease": "sine"},
        "staff": {"rotate": [[0, 0], [0.3, 65], [0.8, 65], [1, 0]], "ease": "sine"},
        "pet": {"translate": T([[0, [0, 0]], [0.5, [14, -4]], [0.8, [14, -4]], [1, [0, 0]]]), "ease": "sine"},
        "head": {"rotate": [[0, 0], [0.3, -10], [1, 0]], "ease": "sine"}})
    return tracks, 10, 60


def attack_clip(meta: dict) -> dict:
    hidden = meta["hidden"]
    if meta["weapon"] == "rifle":
        return {"frames": 4, "loop": False, "duration_ms": 45, "tracks": merge(hide_tracks(hidden, {"flash": [[0, True], [0.5, False]]}), {
            "gun": {"rotate": [[0, -7], [0.4, -3], [1, 0]], "ease": "out"},
            "torso": {"translate": T([[0, [-1, 0]], [1, [0, 0]]]), "ease": "out"},
            "arm_f": {"translate": T([[0, [-1.2, 0]], [1, [0, 0]]]), "ease": "out"}})}
    if meta["weapon"] == "katar":
        return {"frames": 6, "loop": False, "duration_ms": 45, "tracks": merge(hide_tracks(hidden, {"trail": [[0, False], [0.3, True], [0.75, False]]}), {
            "arm_f": {"rotate": [[0, -110], [0.3, -60], [0.55, 35], [1, 0]], "ease": "in"},
            "fore_f": {"rotate": [[0, -40], [0.3, -20], [0.55, 10], [1, 0]], "ease": "in"},
            "torso": {"rotate": [[0, -6], [0.55, 10], [1, 0]], "ease": "out"},
            "arm_b": {"rotate": [[0, 20], [0.55, 40], [1, 0]], "ease": "out"}})}
    return {"frames": 5, "loop": False, "duration_ms": 55, "tracks": merge(hide_tracks(hidden, {"ring_fx": [[0, False], [0.3, True], [0.8, False]]}), {
        "ring_fx": {"scale": [[0, 0.3], [0.3, 0.5], [0.8, 1.2], [1, 1.3]], "ease": "out"},
        "arm_f": {"rotate": [[0, 0], [0.3, -35], [1, 0]], "ease": "out"},
        "fore_f": {"rotate": [[0, 0], [0.3, -25], [1, 0]], "ease": "out"},
        "staff": {"rotate": [[0, 0], [0.3, 35], [1, 0]], "ease": "out"}})}


def anim(hero: str, rig_file: str, meta: dict, ramps: dict) -> dict:
    return {"schema": "codeart2d.rig_anim.v1", "rig": rig_file,
            "states": {"idle": "idle", "moving": "run"}, "entry_reference": "idle",
            "pixel": {"ramps": ramps, "light": [-1, -1], "inner_lines": True, "outline_mode": "selout"},
            "clips": clips_for(hero, meta)}


def write(hero: str, folder) -> tuple:
    rig_svg, ramps, meta = RIGS[hero]()
    rig_path = folder / f"{hero}.rig.svg"
    rig_path.write_text(rig_svg, encoding="utf-8")
    data = anim(hero, rig_path.name, meta, ramps)
    anim_path = folder / f"{hero}.anim.json"
    anim_path.write_text(json.dumps(data, indent=1), encoding="utf-8")
    return rig_path, anim_path, data
