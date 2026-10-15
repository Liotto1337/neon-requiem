"""Builds every code-drawn sprite of Neon Requiem (no image model):

    python3 tools/art/build_art.py [tiles] [creatures] [icons] [fx] [heroes] [--review DIR]

Without arguments every group is rebuilt. Sprite sheets go to assets/, icons to
assets/icons/<kind>/<id>.png and the sheet manifest to data/sprites.json (frame size, pivot,
clips). Heroes need the codeart2d skill (rig_animate.py): set CODEART2D to its folder when it
is not in ~/.claude/skills/codeart2d. --review writes upscaled review sheets to DIR.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(Path(__file__).resolve().parent))

import creatures  # noqa: E402
import fx  # noqa: E402
import heroes  # noqa: E402
import icons  # noqa: E402
import pixlib  # noqa: E402
import tiles  # noqa: E402

GROUPS = ("tiles", "creatures", "icons", "fx", "heroes")
MANIFEST = ROOT / "data/sprites.json"
HERO_CLIPS = ("idle", "run", "reload", "reload_run", "attack", "hurt", "levelup", "cast")
LOOPING = {"idle", "run", "reload_run"}
ACCEPTED_QA = {"l_corners", "seam:run_lower"}


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
         columns: int = 8, pad: int = 3) -> None:
    """Unique frames into one sheet; clips reference sheet indices. Every frame gets `pad`
    transparent pixels on each side so the 2 px outline shader never samples a neighbour."""
    if pad:
        padded = []
        for frame in frames:
            canvas = Image.new("RGBA", (frame.size[0] + pad * 2, frame.size[1] + pad * 2), (0, 0, 0, 0))
            canvas.paste(frame, (pad, pad))
            padded.append(canvas)
        frames = padded
        pivot = (pivot[0] + pad, pivot[1] + pad)
    unique: list[bytes] = []
    images: list[Image.Image] = []
    index_of: list[int] = []
    for frame in frames:
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
    manifest[sprite_id] = {"texture": res(out), "frame": list(images[0].size), "columns": columns,
                           "pivot": list(pivot), "clips": entry_clips}


def build_tiles(review: Path | None, manifest: dict) -> None:
    table = json.loads((ROOT / "data/tiles.json").read_text(encoding="utf-8"))
    atlas = tiles.build_atlas(table)
    out = ROOT / "assets/tiles/neon_atlas.png"
    out.parent.mkdir(parents=True, exist_ok=True)
    atlas.save(out, optimize=True)
    if review:
        pixlib.preview([atlas], 2, columns=1).save(review / "tiles.png")


def build_creatures(review: Path | None, manifest: dict) -> None:
    previews = []
    for cid in creatures.CREATURES:
        frames = creatures.frames(cid)
        w, h = frames[0].size
        fps = 4.0 if cid == "train" else 8.0
        group = "props" if cid in creatures.PROPS else ("allies" if cid == "drone" else "enemies")
        pack("%s/%s" % (group, cid), frames, {"move": {"frames": list(range(len(frames))), "fps": fps, "loop": True}},
             (w // 2, h // 2), manifest)
        previews.append(frames[0])
    if review:
        pixlib.preview(previews, 2, columns=8).save(review / "creatures.png")


def build_fx(review: Path | None, manifest: dict) -> None:
    previews = []
    for fid, (w, h, count, _painter) in fx.FX.items():
        frames = fx.frames(fid)
        fps = {"spark": 20.0, "blade": 16.0, "rocket": 12.0}.get(fid, 8.0)
        loop = fid != "spark"
        pack("fx/" + fid, frames, {"default": {"frames": list(range(count)), "fps": fps, "loop": loop}}, (w // 2, h // 2), manifest)
        previews += frames
    ui = ROOT / "assets/icons/ui"
    ui.mkdir(parents=True, exist_ok=True)
    fx.frames("cursor")[0].save(ui / "cursor.png", optimize=True)
    if review:
        pixlib.preview(previews, 3, columns=12).save(review / "fx.png")


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
            pixlib.preview(images, 2, columns=10).save(review / ("icons_%s.png" % kind))


def build_app_icon() -> None:
    """Windows / window icon: Vector's idle frame (x3) on a neon framed tile, as PNG and ICO."""
    entry = load_manifest().get("heroes/vector")
    if not entry:
        return
    sheet = Image.open(ROOT / entry["texture"].replace("res://", "")).convert("RGBA")
    fw, fh = entry["frame"]
    frame = sheet.crop((0, 0, fw, fh))
    bbox = frame.getbbox()
    hero = frame.crop(bbox).resize(((bbox[2] - bbox[0]) * 3, (bbox[3] - bbox[1]) * 3), Image.NEAREST)
    c = pixlib.Canvas(256, 256)
    c.paint(c.rect(4, 4, 248, 248, 40), ["#07040e", "#120a22", "#1c1030", "#26163e"], style="bevel", depth=24)
    c.flat(c.rect(4, 4, 248, 248, 40).minus(c.rect(12, 12, 232, 232, 34)), "#ff2e88")
    c.flat(c.rect(16, 16, 224, 224, 32).minus(c.rect(19, 19, 218, 218, 30)), "#00f0ff")
    icon = c.image()
    icon.alpha_composite(hero, ((256 - hero.size[0]) // 2, max(8, 248 - hero.size[1])))
    folder = ROOT / "assets/icons/app"
    folder.mkdir(parents=True, exist_ok=True)
    icon.save(folder / "icon.png", optimize=True)
    icon.save(folder / "icon.ico", sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)])


def _rig_animate() -> Path:
    base = Path(os.environ.get("CODEART2D", Path.home() / ".claude/skills/codeart2d"))
    tool = base / "scripts/rig_animate.py"
    if not tool.exists():
        raise SystemExit("heroes: codeart2d rig_animate.py not found; set CODEART2D")
    return tool


def _render_hero(hero: str, work: Path) -> tuple[dict, Path]:
    rig_path, anim_path, data = heroes.write(hero, work)
    out = work / ("out_" + hero)
    proc = subprocess.run([sys.executable, str(_rig_animate()), "--rig", str(rig_path), "--anim", str(anim_path),
                           "--output-dir", str(out), "--route", "pixel"], capture_output=True, text=True)
    summary = proc.stdout.strip().splitlines()[-1] if proc.stdout.strip() else "{}"
    failed = set(json.loads(summary).get("failed_checks", [])) if summary.startswith("{") else {"render"}
    if proc.returncode not in (0, 1) or failed - ACCEPTED_QA:
        raise SystemExit("heroes: %s rig_animate failed: %s %s" % (hero, proc.stderr.strip(), summary))
    if failed:
        print("art: %s QA notes (accepted for ~70 px sprites): %s" % (hero, ", ".join(sorted(failed))))
    return data, out


def _clip_frames(out: Path, clips: dict, name: str) -> list[Image.Image]:
    files = {f["name"]: f["file"] for f in clips["frames"]}
    return [Image.open(out / files[f]).convert("RGBA") for f in clips["clips"][name]["frames"]]


def build_heroes(review: Path | None, manifest: dict) -> None:
    work = Path(tempfile.mkdtemp(prefix="nr-heroes-"))
    try:
        for hero in heroes.RIGS:
            data, out = _render_hero(hero, work)
            clips = json.loads((out / "clips.json").read_text(encoding="utf-8"))
            frames: list[Image.Image] = []
            table: dict = {}
            for name in HERO_CLIPS:
                if name == "reload_run":
                    clip_frames = _compose_reload_run(out, clips, data)
                    ms = data["clips"]["reload"]["duration_ms"]
                else:
                    clip_frames = _clip_frames(out, clips, name)
                    ms = data["clips"][name]["duration_ms"]
                table[name] = {"frames": list(range(len(frames), len(frames) + len(clip_frames))),
                               "fps": round(1000.0 / ms, 3), "loop": name in LOOPING}
                frames += clip_frames
            anchor = clips["anchor_px"]
            pack("heroes/" + hero, frames, table, (int(anchor[0]), int(anchor[1]) - 24), manifest)
            if review:
                pixlib.preview(frames, 3, columns=16).save(review / ("hero_%s.png" % hero))
    finally:
        shutil.rmtree(work, ignore_errors=True)


def _compose_reload_run(out: Path, clips: dict, data: dict) -> list[Image.Image]:
    """Run legs (by time) under the reload upper body, frame by frame."""
    lower = _clip_frames(out, clips, "run_lower")
    upper = _clip_frames(out, clips, "reload_upper")
    reload_ms = data["clips"]["reload"]["duration_ms"]
    run_ms = data["clips"]["run"]["duration_ms"]
    result = []
    for i, top in enumerate(upper):
        frame = lower[int(i * reload_ms / run_ms) % len(lower)].copy()
        frame.alpha_composite(top)
        result.append(frame)
    return result


def main(argv: list[str]) -> int:
    review = None
    if "--review" in argv:
        review = Path(argv[argv.index("--review") + 1])
        review.mkdir(parents=True, exist_ok=True)
        argv = argv[:argv.index("--review")] + argv[argv.index("--review") + 2:]
    groups = [a for a in argv if a in GROUPS] or list(GROUPS)
    builders = {"tiles": build_tiles, "creatures": build_creatures, "icons": build_icons, "fx": build_fx, "heroes": build_heroes}
    manifest = load_manifest()
    for group in groups:
        builders[group](review, manifest)
        print("art: %s done" % group)
    save_manifest(manifest)
    build_app_icon()
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
