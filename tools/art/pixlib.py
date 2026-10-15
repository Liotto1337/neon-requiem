"""Tiny pixel-art painter on numpy: analytic shapes, form shading with palette ramps and
ordered dithering, part separation lines, neon rims and a 1 px outline.

Everything is code-drawn (no image model). Colours come only from ramps, so a sprite keeps a
small exact palette. Neon colours are bright (max channel >= 0.94); matte colours stay below
0.80 so the in-game sprite shader can boost only the neon parts into the glow.
"""
from __future__ import annotations

import math
from dataclasses import dataclass

import numpy as np
from PIL import Image

LIGHT = np.array([-0.55, -0.75, 0.95])
LIGHT = LIGHT / np.linalg.norm(LIGHT)
BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0


def hex_rgb(value: str) -> tuple[int, int, int]:
    value = value.lstrip("#")
    return int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16)


def mix(a: str, b: str, t: float) -> str:
    ca, cb = hex_rgb(a), hex_rgb(b)
    return "#%02x%02x%02x" % tuple(round(ca[i] + (cb[i] - ca[i]) * t) for i in range(3))


def ramp(dark: str, mid: str, light: str, steps: int = 5) -> list[str]:
    """Dark -> light ramp through `mid`, with `steps` colours (odd counts keep mid exact)."""
    out = []
    half = (steps - 1) / 2.0
    for i in range(steps):
        if i <= half:
            out.append(mix(dark, mid, i / half))
        else:
            out.append(mix(mid, light, (i - half) / half))
    return out


@dataclass
class Shape:
    """Pixel-centre mask plus the inside distance to the edge (px) for shading."""
    mask: np.ndarray
    dist: np.ndarray

    def __or__(self, other: "Shape") -> "Shape":
        return Shape(self.mask | other.mask, np.maximum(self.dist, other.dist))

    def minus(self, other: "Shape") -> "Shape":
        mask = self.mask & ~other.mask
        return Shape(mask, np.where(mask, self.dist, 0.0))

    def clip(self, other: "Shape") -> "Shape":
        mask = self.mask & other.mask
        return Shape(mask, np.where(mask, np.minimum(self.dist, other.dist + 1e-3), 0.0))

    def shifted(self, dx: int, dy: int) -> "Shape":
        return Shape(np.roll(np.roll(self.mask, dy, 0), dx, 1), np.roll(np.roll(self.dist, dy, 0), dx, 1))

    def any(self) -> bool:
        return bool(self.mask.any())


class Canvas:
    def __init__(self, w: int, h: int):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3), np.uint8)
        self.alpha = np.zeros((h, w), bool)
        self.label = np.zeros((h, w), np.int32)
        self.dark = np.zeros((h, w, 3), np.uint8)
        self._next = 1
        ys, xs = np.mgrid[0:h, 0:w]
        self.X = xs + 0.5
        self.Y = ys + 0.5

    # ------------------------------------------------------------------ shapes
    def ellipse(self, cx: float, cy: float, rx: float, ry: float, angle: float = 0.0) -> Shape:
        ca, sa = math.cos(math.radians(angle)), math.sin(math.radians(angle))
        dx, dy = self.X - cx, self.Y - cy
        u = (dx * ca + dy * sa) / max(rx, 0.01)
        v = (-dx * sa + dy * ca) / max(ry, 0.01)
        r = np.sqrt(u * u + v * v)
        mask = r <= 1.0
        dist = np.where(mask, (1.0 - r) * min(rx, ry), 0.0)
        return Shape(mask, dist)

    def circle(self, cx: float, cy: float, r: float) -> Shape:
        return self.ellipse(cx, cy, r, r)

    def poly(self, points: list[tuple[float, float]]) -> Shape:
        pts = np.array(points, float)
        n = len(pts)
        inside = np.zeros((self.h, self.w), bool)
        dist = np.full((self.h, self.w), 1e9)
        for i in range(n):
            x0, y0 = pts[i]
            x1, y1 = pts[(i + 1) % n]
            cond = ((y0 > self.Y) != (y1 > self.Y))
            xint = (x1 - x0) * (self.Y - y0) / ((y1 - y0) if y1 != y0 else 1e-9) + x0
            inside ^= cond & (self.X < xint)
            dist = np.minimum(dist, _seg_dist(self.X, self.Y, x0, y0, x1, y1))
        return Shape(inside, np.where(inside, dist, 0.0))

    def rect(self, x: float, y: float, w: float, h: float, r: float = 0.0) -> Shape:
        if r <= 0:
            dx = np.minimum(self.X - x, x + w - self.X)
            dy = np.minimum(self.Y - y, y + h - self.Y)
            mask = (dx > 0) & (dy > 0)
            return Shape(mask, np.where(mask, np.minimum(dx, dy), 0.0))
        cx, cy = x + w / 2, y + h / 2
        qx = np.abs(self.X - cx) - (w / 2 - r)
        qy = np.abs(self.Y - cy) - (h / 2 - r)
        outside = np.sqrt(np.maximum(qx, 0) ** 2 + np.maximum(qy, 0) ** 2) + np.minimum(np.maximum(qx, qy), 0) - r
        mask = outside < 0
        return Shape(mask, np.where(mask, -outside, 0.0))

    def capsule(self, x0: float, y0: float, x1: float, y1: float, r0: float, r1: float | None = None) -> Shape:
        r1 = r0 if r1 is None else r1
        vx, vy = x1 - x0, y1 - y0
        ll = vx * vx + vy * vy
        t = np.clip(((self.X - x0) * vx + (self.Y - y0) * vy) / (ll if ll > 0 else 1e-9), 0, 1)
        px, py = x0 + vx * t, y0 + vy * t
        d = np.sqrt((self.X - px) ** 2 + (self.Y - py) ** 2)
        rad = r0 + (r1 - r0) * t
        mask = d <= rad
        return Shape(mask, np.where(mask, rad - d, 0.0))

    def ring(self, cx: float, cy: float, r: float, width: float) -> Shape:
        d = np.sqrt((self.X - cx) ** 2 + (self.Y - cy) ** 2)
        band = width / 2 - np.abs(d - r)
        mask = band >= 0
        return Shape(mask, np.where(mask, band, 0.0))

    def arc(self, cx: float, cy: float, r: float, width: float, a0: float, a1: float) -> Shape:
        """Ring segment from angle a0 to a1 (degrees, clockwise on screen, 0 = right)."""
        ring = self.ring(cx, cy, r, width)
        ang = (np.degrees(np.arctan2(self.Y - cy, self.X - cx)) - a0) % 360.0
        keep = ang <= (a1 - a0) % 360.0 + (360.0 if (a1 - a0) % 360.0 == 0 and a1 != a0 else 0.0)
        mask = ring.mask & keep
        return Shape(mask, np.where(mask, ring.dist, 0.0))

    def line(self, x0: float, y0: float, x1: float, y1: float, width: float = 1.0) -> Shape:
        return self.capsule(x0, y0, x1, y1, width / 2.0)

    def pixels(self, coords: list[tuple[int, int]]) -> Shape:
        mask = np.zeros((self.h, self.w), bool)
        for x, y in coords:
            if 0 <= x < self.w and 0 <= y < self.h:
                mask[y, x] = True
        return Shape(mask, mask.astype(float))

    def from_mask(self, mask: np.ndarray) -> Shape:
        return Shape(mask.copy(), mask.astype(float))

    # ------------------------------------------------------------------ paint
    def paint(self, shape: Shape, colors: list[str], style: str = "dome", depth: float | None = None,
              light: np.ndarray | None = None, dither: float = 0.55, bias: float = 0.0,
              sep: bool = False, rim: str | None = None, rim_dir: tuple[float, float] = (0.7, 0.7),
              rim_width: int = 1, under: bool = False) -> int:
        """Fill `shape` with ramp `colors` (dark -> light) shaded as a dome / bevel / cylinder.
        sep: darkest ramp colour where the part meets already painted pixels (part separation).
        rim: neon rim colour on the edge facing rim_dir (backlight). under: paint only empty pixels."""
        mask = shape.mask.copy()
        if under:
            mask &= ~self.alpha
        if not mask.any():
            return 0
        idx = self._shade_index(shape, mask, len(colors), style, depth, light, dither, bias)
        pal = np.array([hex_rgb(c) for c in colors], np.uint8)
        label = self._next
        self._next += 1
        existing = self.alpha.copy()
        self.rgb[mask] = pal[idx[mask]]
        self.dark[mask] = pal[0]
        self.alpha[mask] = True
        self.label[mask] = label
        edge = mask & ~_erode(mask)
        if sep:
            touching = edge & _dilate(existing & ~mask)
            self.rgb[touching] = pal[0]
        if rim:
            self._rim(mask, rim, rim_dir, rim_width)
        return label

    def flat(self, shape: Shape, color: str, under: bool = False) -> None:
        mask = shape.mask & (~self.alpha if under else True)
        self.rgb[mask] = hex_rgb(color)
        self.alpha[mask] = True
        self.dark[mask] = hex_rgb(color)
        self.label[mask] = self._next
        self._next += 1

    def erase(self, shape: Shape) -> None:
        self.alpha[shape.mask] = False
        self.rgb[shape.mask] = 0
        self.label[shape.mask] = 0

    def recolor(self, shape: Shape, color: str) -> None:
        """Repaint only pixels that are already visible."""
        mask = shape.mask & self.alpha
        self.rgb[mask] = hex_rgb(color)

    def _shade_index(self, shape: Shape, mask: np.ndarray, n: int, style: str, depth: float | None,
                     light: np.ndarray | None, dither: float, bias: float) -> np.ndarray:
        light = LIGHT if light is None else light / np.linalg.norm(light)
        d = np.where(mask, shape.dist, 0.0)
        depth = depth if depth is not None else max(1.0, float(d.max()))
        t = np.clip(d / depth, 0.0, 1.0)
        if style == "flat":
            inten = np.full(d.shape, 0.62)
        else:
            if style == "bevel":
                hgt = np.minimum(t * 3.0, 1.0)
            elif style == "cylinder":
                hgt = np.sqrt(1.0 - (1.0 - t) ** 2)
            else:
                hgt = np.sqrt(np.clip(1.0 - (1.0 - t) ** 2, 0, 1))
            gy, gx = np.gradient(hgt * depth * 0.9)
            nz = np.ones_like(gx)
            norm = np.sqrt(gx * gx + gy * gy + nz * nz)
            inten = (-gx * light[0] - gy * light[1] + nz * light[2]) / norm
            inten = 0.5 * inten + 0.5 * (inten ** 3) if style == "bevel" else inten
            inten = np.clip(inten * 0.95 + 0.05, 0, 1)
        h, w = d.shape
        bay = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]
        val = inten * (n - 1) + bias + (bay - 0.5) * dither
        return np.clip(np.round(val), 0, n - 1).astype(int)

    def _rim(self, mask: np.ndarray, color: str, direction: tuple[float, float], width: int) -> None:
        dx, dy = direction
        norm = math.hypot(dx, dy) or 1.0
        dx, dy = dx / norm, dy / norm
        band = mask.copy()
        for _ in range(width):
            band = _erode(band)
        edge = mask & ~band
        # Outward normal approximated by which neighbours are empty.
        nx = (~_shift(mask, 1, 0)).astype(float) - (~_shift(mask, -1, 0)).astype(float)
        ny = (~_shift(mask, 0, 1)).astype(float) - (~_shift(mask, 0, -1)).astype(float)
        for _ in range(width - 1):
            nx, ny = _spread(nx, mask), _spread(ny, mask)
        face = (nx * dx + ny * dy) > 0.2
        self.rgb[edge & face] = hex_rgb(color)

    # ------------------------------------------------------------------ finishing
    def outline(self, color: str = "#0b0714", mode: str = "solid", diagonal: bool = False) -> None:
        ring = _dilate(self.alpha, diagonal) & ~self.alpha
        if mode == "selout":
            src = np.zeros_like(self.rgb)
            for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
                src = np.where(_shift(self.alpha, dx, dy)[..., None] & (src.sum(-1) == 0)[..., None],
                               _shift3(self.dark, dx, dy), src)
            base = np.array(hex_rgb(color), float)
            blend = (src.astype(float) * 0.45 + base * 0.55).astype(np.uint8)
            self.rgb[ring] = blend[ring]
        else:
            self.rgb[ring] = hex_rgb(color)
        self.alpha[ring] = True

    def glow_halo(self, color: str, radius: int = 2, strength: float = 0.45) -> np.ndarray:
        """Soft halo alpha for previews / UI icons (not used on in-game sprites)."""
        halo = np.zeros((self.h, self.w), float)
        a = self.alpha.astype(float)
        for r in range(1, radius + 1):
            a = np.maximum(a, _box(a, 1) * 0.8)
            halo = np.maximum(halo, a * (strength / r))
        return halo

    def image(self) -> Image.Image:
        out = np.zeros((self.h, self.w, 4), np.uint8)
        out[..., :3] = np.where(self.alpha[..., None], self.rgb, 0)
        out[..., 3] = np.where(self.alpha, 255, 0)
        return Image.fromarray(out, "RGBA")

    def opaque_image(self, bg: str) -> Image.Image:
        out = np.zeros((self.h, self.w, 3), np.uint8)
        out[:] = hex_rgb(bg)
        out = np.where(self.alpha[..., None], self.rgb, out)
        return Image.fromarray(out.astype(np.uint8), "RGB")


# ---------------------------------------------------------------------- helpers

def _seg_dist(X, Y, x0, y0, x1, y1):
    vx, vy = x1 - x0, y1 - y0
    ll = vx * vx + vy * vy
    t = np.clip(((X - x0) * vx + (Y - y0) * vy) / (ll if ll > 0 else 1e-9), 0, 1)
    return np.sqrt((X - x0 - vx * t) ** 2 + (Y - y0 - vy * t) ** 2)


def _shift(a: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """out[y, x] = a[y + dy, x + dx], false outside."""
    out = np.zeros_like(a)
    h, w = a.shape[:2]
    ys0, ys1 = max(0, -dy), min(h, h - dy)
    xs0, xs1 = max(0, -dx), min(w, w - dx)
    out[ys0:ys1, xs0:xs1] = a[ys0 + dy:ys1 + dy, xs0 + dx:xs1 + dx]
    return out


def _shift3(a: np.ndarray, dx: int, dy: int) -> np.ndarray:
    return _shift(a, dx, dy)


def _dilate(a: np.ndarray, diagonal: bool = False) -> np.ndarray:
    out = a | _shift(a, 1, 0) | _shift(a, -1, 0) | _shift(a, 0, 1) | _shift(a, 0, -1)
    if diagonal:
        out |= _shift(a, 1, 1) | _shift(a, -1, -1) | _shift(a, 1, -1) | _shift(a, -1, 1)
    return out


def _erode(a: np.ndarray) -> np.ndarray:
    return a & _shift(a, 1, 0) & _shift(a, -1, 0) & _shift(a, 0, 1) & _shift(a, 0, -1)


def _spread(v: np.ndarray, mask: np.ndarray) -> np.ndarray:
    out = v.copy()
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        nb = _shift(v, dx, dy)
        out = np.where((out == 0) & mask, nb, out)
    return out


def _box(a: np.ndarray, r: int) -> np.ndarray:
    out = np.zeros_like(a)
    n = 0
    for dy in range(-r, r + 1):
        for dx in range(-r, r + 1):
            out += _shift(a, dx, dy)
            n += 1
    return out / n


# ---------------------------------------------------------------------- noise and sheets

def value_noise(w: int, h: int, cell: int, seed: int, tile: bool = True) -> np.ndarray:
    """Smooth value noise in [0, 1]; tileable when w and h are multiples of `cell`."""
    rng = np.random.default_rng(seed)
    gw, gh = max(1, w // cell), max(1, h // cell)
    grid = rng.random((gh + 1, gw + 1))
    if tile:
        grid[-1, :] = grid[0, :]
        grid[:, -1] = grid[:, 0]
    ys, xs = np.mgrid[0:h, 0:w]
    fx, fy = (xs + 0.5) / cell, (ys + 0.5) / cell
    x0, y0 = np.floor(fx).astype(int) % gw, np.floor(fy).astype(int) % gh
    tx, ty = fx - np.floor(fx), fy - np.floor(fy)
    tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
    a = grid[y0, x0]
    b = grid[y0, x0 + 1]
    c = grid[y0 + 1, x0]
    d = grid[y0 + 1, x0 + 1]
    return a * (1 - tx) * (1 - ty) + b * tx * (1 - ty) + c * (1 - tx) * ty + d * tx * ty


def fractal_noise(w: int, h: int, seed: int, cells: tuple[int, ...] = (16, 8, 4)) -> np.ndarray:
    total = np.zeros((h, w))
    amp, norm = 1.0, 0.0
    for i, cell in enumerate(cells):
        total += value_noise(w, h, cell, seed + i * 7919) * amp
        norm += amp
        amp *= 0.5
    return total / norm


def quantize(values: np.ndarray, colors: list[str], dither: float = 0.6) -> np.ndarray:
    h, w = values.shape
    bay = np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]
    idx = np.clip(np.round(values * (len(colors) - 1) + (bay - 0.5) * dither), 0, len(colors) - 1).astype(int)
    pal = np.array([hex_rgb(c) for c in colors], np.uint8)
    return pal[idx]


def sheet(frames: list[Image.Image], columns: int) -> Image.Image:
    fw, fh = frames[0].size
    rows = (len(frames) + columns - 1) // columns
    out = Image.new("RGBA", (fw * columns, fh * rows), (0, 0, 0, 0))
    for i, frame in enumerate(frames):
        out.paste(frame, ((i % columns) * fw, (i // columns) * fh))
    return out


def preview(images: list[Image.Image], scale: int, bg: str = "#1a1426", pad: int = 4, columns: int = 8) -> Image.Image:
    """Review sheet: nearest upscale on a dark background."""
    cell_w = max(im.size[0] for im in images) * scale + pad * 2
    cell_h = max(im.size[1] for im in images) * scale + pad * 2
    rows = (len(images) + columns - 1) // columns
    out = Image.new("RGBA", (cell_w * min(columns, len(images)), cell_h * rows), hex_rgb(bg) + (255,))
    for i, im in enumerate(images):
        big = im.resize((im.size[0] * scale, im.size[1] * scale), Image.NEAREST)
        out.alpha_composite(big, ((i % columns) * cell_w + pad, (i // columns) * cell_h + pad))
    return out
