"""Neon Requiem palette: neon accents (bright, glow in game) and matte material ramps
(dark -> light, max channel < 0.86 so the sprite shader leaves them unboosted)."""
from pixlib import mix, ramp

OUTLINE = "#0b0714"
INK = "#140c22"

NEON = {
    "cyan": "#00f0ff",
    "magenta": "#ff2e88",
    "lime": "#b6ff00",
    "amber": "#ffb800",
    "white": "#f0f0ff",
    "red": "#ff3344",
    "blue": "#3a7dff",
    "purple": "#b14dff",
    "orange": "#ff7a1a",
    "green": "#33ff77",
    "yellow": "#ffee33",
}

# Ramps used by neon parts: deep tone -> neon -> white-hot core.
GLOW = {name: [mix(c, "#0b0714", 0.55), mix(c, "#0b0714", 0.25), c, mix(c, "#ffffff", 0.45), "#fbfbff"]
        for name, c in NEON.items()}
# Same hue but matte (stays below the boost threshold): painted lights, cloth, enamel.
TINT = {name: ramp(mix(c, "#0b0714", 0.82), mix(c, "#1a1426", 0.5), mix(c, "#1a1426", 0.2), 5)
        for name, c in NEON.items()}

STEEL = ramp("#0f0d1a", "#353450", "#8d90aa", 5)
GUNMETAL = ramp("#0c0a14", "#26233a", "#5e5b7c", 5)
CHROME = ramp("#17152a", "#5c6080", "#b9bdd2", 6)
DARKCLOTH = ramp("#0b0814", "#221836", "#4e3e70", 5)
COAT = ramp("#0a0912", "#1c1a30", "#454569", 5)
LEATHER = ramp("#120a0c", "#3a2224", "#7a4e44", 5)
SKIN = ramp("#2a1418", "#8c5446", "#d09a7c", 5)
SKIN_PALE = ramp("#2a1c26", "#8a7088", "#cab4c8", 5)
RUST = ramp("#140a06", "#5a2e16", "#b0663a", 5)
BRASS = ramp("#1a1006", "#6a4a14", "#c4983c", 5)
MOSS = ramp("#060f08", "#1c3e1a", "#4f8a2e", 5)
BONE = ramp("#1c1820", "#6e6878", "#c6c0cc", 5)
MARBLE = ramp("#16122a", "#4e4870", "#aaa4c8", 5)
BRICK = ramp("#14070f", "#4a1c34", "#86405a", 5)
CONCRETE = ramp("#0e0a16", "#2e2840", "#5a5274", 5)
GLASS = ["#0c1a2e", "#1a3a5a", "#2e6a8a", "#5ab0c8", "#c8f4ff"]
VOID = ["#05020a", "#12071f", "#250d3d", "#4a1a70", "#8a3ad0"]
