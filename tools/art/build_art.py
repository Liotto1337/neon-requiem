"""Builds every code-drawn sprite of Neon Requiem (no image model) at 16-px scale:

    python3 tools/art/build_art.py [tiles] [creatures] [icons] [fx] [heroes] [--review DIR]

Without arguments every group is rebuilt. Sprite sheets go to assets/, icons to
assets/icons/<kind>/<id>.png and the sheet manifest to data/sprites.json (frame size, pivot,
clips, plus hand / muzzle points for weapons). Everything is drawn small (16 px tiles and
bodies) and shown x4 in game. --review writes upscaled review sheets to DIR.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import creatures  # noqa: E402
import fx  # noqa: E402
import heroes  # noqa: E402
import icons  # noqa: E402
import pixlib  # noqa: E402
import tile_spec  # noqa: E402
import tiles  # noqa: E402

GROUPS = ("tiles", "creatures", "icons", "fx", "heroes")
MANIFEST = ROOT / "data/sprites.json"
UI_SCALE = 4
# Hand anchor (texels from the body pivot) where each hero holds the weapon, per facing.
HANDS = {"side": [2, 3], "down": [3, 3], "up": [-3, 1]}


def res(path: Path) -> str:
    return "res://" + path.relative_to(ROOT).as_posix()


def load_manifest() -> dict:
    if MANIFEST.exists():
        return json.loads(MANIFEST.read_text(encoding="utf-8"))
    return {}


def save_manifest(data: dict) -> None:
    lines = ["{"]
    keys = sorted(data)
    for i, key in enumerate(keys):
        comma = "," if i < len(keys) - 1 else ""
        lines.append("\t%s: %s%s" % (json.dumps(key), json.dumps(data[key], ensure_ascii=False, separators=(", ", ": ")), comma))
    lines.append("}")
    MANIFEST.write_text("\n".join(lines) + "\n", encoding="utf-8")


def pack(sprite_id: str, frames: list[Image.Image], clips: dict, pivot: tuple[int, int], manifest: dict,
         columns: int = 12, pad: int = 2, extra: dict | None = None) -> None:
    """Unique frames into one sheet; clips reference sheet indices. Every frame gets `pad`
    transparent pixels on each side so the outline shader never samples a neighbour."""
    padded = []
    for frame in frames:
        canvas = Image.new("RGBA", (frame.size[0] + pad * 2, frame.size[1] + pad * 2), (0, 0, 0, 0))
        canvas.paste(frame, (pad, pad))
        padded.append(canvas)
    pivot = (pivot[0] + pad, pivot[1] + pad)
    unique: list[bytes] = []
    images: list[Image.Image] = []
    index_of: list[int] = []
    for frame in padded:
        data = frame.tobytes()
        if data in unique:
            index_of.append(unique.index(data))
        else:
            unique.append(data)
            images.append(frame)
            index_of.append(len(images) - 1)
    out = ROOT / "assets/sprites" / (sprite_id + ".png")
    out.parent.mkdir(parents=True, exist_ok=True)
    columns = min(columns, len(images))
    pixlib.sheet(images, columns).save(out, optimize=True)
    entry_clips = {}
    for name, clip in clips.items():
        entry_clips[name] = {"frames": [index_of[i] for i in clip["frames"]], "fps": clip["fps"], "loop": clip["loop"]}
    entry = {"texture": res(out), "frame": list(images[0].size), "columns": columns, "pivot": list(pivot), "clips": entry_clips}
    if extra:
        for key, value in extra.items():
            entry[key] = [value[0] + pad, value[1] + pad] if key == "muzzle" else value
    manifest[sprite_id] = entry


def build_tiles(review: Path | None, manifest: dict) -> None:
    table = json.loads((ROOT / "data/tiles.json").read_text(encoding="utf-8"))
    atlas = tiles.build_atlas(table)
    out = ROOT / "assets/tiles/neon_atlas.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(out, optimize=True)
    tiles.backdrop().save(ROOT / "assets/tiles/backdrop.png", optimize=True)
    tile_spec.main()
    if review:
        pixlib.preview([atlas], 3, columns=1).save(review / "tiles.png")


def build_creatures(review: Path | None, manifest: dict) -> None:
    previews = []
    for cid, (w, h, count, _painter, directional) in creatures.CREATURES.items():
        frames: list = []
        clips: dict = {}
        fps = 4.0 if cid == "train" else 7.0
        for facing in (creatures.DIRS if directional else ("down",)):
            start = len(frames)
            frames += creatures.frames(cid, facing)
            name = "move_" + facing if directional else "move"
            clips[name] = {"frames": list(range(start, len(frames))), "fps": fps, "loop": True}
        group = "props" if cid in creatures.PROPS else ("allies" if cid == "drone" else "enemies")
        pack("%s/%s" % (group, cid), frames, clips, (w // 2, h // 2), manifest, extra={"directional": directional})
        previews.append(frames[0])
    if review:
        pixlib.preview(previews, 4, columns=10).save(review / "creatures.png")


def build_fx(review: Path | None, manifest: dict) -> None:
    previews = []
    for fid, (w, h, count, _painter) in fx.FX.items():
        frames = fx.frames(fid)
        fps = {"spark": 20.0, "blade": 16.0, "rocket": 12.0, "lightning": 24.0}.get(fid, 8.0)
        loop = fid != "spark"
        pack("fx/" + fid, frames, {"default": {"frames": list(range(count)), "fps": fps, "loop": loop}}, (w // 2, h // 2), manifest)
        previews += frames
    ui = ROOT / "assets/icons/ui"
    ui.mkdir(parents=True, exist_ok=True)
    cursor = fx.frames("cursor")[0]
    cursor.resize((cursor.size[0] * UI_SCALE, cursor.size[1] * UI_SCALE), Image.NEAREST).save(ui / "cursor.png", optimize=True)
    if review:
        pixlib.preview(previews, 6, columns=14).save(review / "fx.png")


def build_icons(review: Path | None, manifest: dict) -> None:
    for kind, table in (("items", icons.ITEMS), ("abilities", icons.ABILITIES), ("meta", icons.META), ("ui", icons.UI)):
        folder = ROOT / "assets/icons" / kind
        folder.mkdir(parents=True, exist_ok=True)
        images = []
        for icon_id, painter in table.items():
            image = icons.render(painter)
            image.save(folder / (icon_id + ".png"), optimize=True)
            images.append(image)
        if review:
            pixlib.preview(images, 5, columns=16).save(review / ("icons_%s.png" % kind))


def build_heroes(review: Path | None, manifest: dict) -> None:
    for hero in heroes.BODIES:
        frames, clips = heroes.hero_frames(hero)
        weapon = heroes.HERO_WEAPON[hero]
        pack("heroes/" + hero, frames, clips, (8, 9), manifest, extra={"weapon": "weapons/" + weapon, "hands": HANDS})
        if review:
            pixlib.preview(frames, 5, columns=24).save(review / ("hero_%s.png" % hero))
    for weapon, (w, h, _painter, pivot, muzzle, _clips) in heroes.WEAPONS.items():
        frames, clips = heroes.weapon_frames(weapon)
        pack("weapons/" + weapon, frames, clips, pivot, manifest, extra={"muzzle": list(muzzle)})


def build_app_icon() -> None:
    """Windows / window icon: Vector (x12) in a neon frame, as PNG and ICO."""
    body, _clips = heroes.hero_frames("vector")
    hero = body[0].resize((16 * 12, 16 * 12), Image.NEAREST)
    gun = heroes.weapon_frames("rifle")[0][0]
    gun = gun.resize((gun.size[0] * 7, gun.size[1] * 7), Image.NEAREST)
    c = pixlib.Canvas(256, 256)
    c.paint(c.rect(4, 4, 248, 248, 40), ["#07040e", "#120a22", "#1c1030", "#26163e"], style="bevel", depth=24)
    c.flat(c.rect(4, 4, 248, 248, 40).minus(c.rect(12, 12, 232, 232, 34)), "#e8468e")
    c.flat(c.rect(16, 16, 224, 224, 32).minus(c.rect(19, 19, 218, 218, 30)), "#3fd8e8")
    icon = c.image()
    icon.alpha_composite(hero, (32, 40))
    icon.alpha_composite(gun, (100, 150))
    folder = ROOT / "assets/icons/app"
    folder.mkdir(parents=True, exist_ok=True)
    icon.save(folder / "icon.png", optimize=True)
    icon.save(folder / "icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


def main(argv: list[str]) -> int:
    review = None
    if "--review" in argv:
        review = Path(argv[argv.index("--review") + 1])
        review.mkdir(parents=True, exist_ok=True)
        argv = argv[:argv.index("--review")] + argv[argv.index("--review") + 2:]
    groups = [a for a in argv if a in GROUPS] or list(GROUPS)
    builders = {"tiles": build_tiles, "creatures": build_creatures, "icons": build_icons, "fx": build_fx, "heroes": build_heroes}
    manifest = load_manifest() if set(groups) != set(GROUPS) else {}
    for group in groups:
        builders[group](review, manifest)
        print("art: %s done" % group)
    save_manifest(manifest)
    build_app_icon()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
