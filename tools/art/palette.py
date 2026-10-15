"""Neon Requiem palette (dark revision): deep, low-value materials and a restrained neon set.
Matte colours stay below 0.80 of max channel; neon accents (the brightest step of each GLOW
ramp) are >= 0.86 so the in-game SpriteFx shader boosts only them into the glow."""
from pixlib import mix

OUTLINE = "#06040b"
INK = "#0d0916"

NEON = {
    "cyan": "#3fd8e8",
    "magenta": "#e8468e",
    "lime": "#a8dc3c",
    "amber": "#e8b03c",
    "white": "#dcdcf0",
    "red": "#e84a52",
    "blue": "#5a84e8",
    "purple": "#a46ae0",
    "orange": "#e8803a",
    "green": "#4ad87a",
    "yellow": "#e0d440",
}

# Glowing parts: deep tone -> mid -> neon (boosted in game) -> pale core.
GLOW = {name: [mix(c, OUTLINE, 0.62), mix(c, OUTLINE, 0.32), c, mix(c, "#ffffff", 0.35)] for name, c in NEON.items()}
# Same hue, matte (never boosted): enamel, cloth, painted metal.
TINT = {name: [mix(c, OUTLINE, 0.84), mix(c, OUTLINE, 0.66), mix(c, "#1a1426", 0.45), mix(c, "#1a1426", 0.22)] for name, c in NEON.items()}

# Material ramps, dark -> light, 4 steps (16 px sprites need few tones).
STEEL = ["#0e0c16", "#22202e", "#3a384e", "#5e5c78"]
GUNMETAL = ["#09080f", "#17151f", "#2a2738", "#423e56"]
CHROME = ["#14121e", "#34364a", "#5c6078", "#8c90aa"]
DARKCLOTH = ["#0a0712", "#191226", "#2a1f3e", "#3e3058"]
COAT = ["#09080f", "#171628", "#272640", "#3c3c5e"]
LEATHER = ["#100809", "#2a171a", "#46282a", "#644038"]
SKIN = ["#2a1614", "#5e362c", "#8e5a46", "#b8826a"]
SKIN_PALE = ["#211a24", "#4e4458", "#786c84", "#a69ab4"]
RUST = ["#100806", "#2e180e", "#4e2a16", "#764222"]
BRASS = ["#140c04", "#3e2c0e", "#6c5018", "#a07a2a"]
MOSS = ["#060c07", "#112410", "#20401a", "#365e24"]
BONE = ["#18141c", "#4a4452", "#7a7484", "#a8a2b2"]
MARBLE = ["#120f20", "#2a2540", "#47406a", "#6e6696"]
BRICK = ["#10060c", "#2c1222", "#461c34", "#62304a"]
CONCRETE = ["#0b0812", "#1a1626", "#2a2438", "#3e364e"]
GLASS = ["#081220", "#12283e", "#1e4860", "#3a7890"]
VOID = ["#030106", "#0b0414", "#180a2a", "#2e1450"]

# Floors are the darkest layer so sprites and bullets read on top of them.
FLOOR = {
    "slum": ["#0b0712", "#110b1a", "#171024", "#1e152e"],
    "core": ["#060a18", "#0a1022", "#0e162e", "#131d3a"],
    "garden": ["#050a06", "#08120a", "#0d1a0f", "#132414"],
    "rail": ["#0c0705", "#140c08", "#1c120c", "#261810"],
    "spire": ["#0c0a16", "#131022", "#1a162e", "#221d3a"],
    "hub": ["#08070f", "#0d0c18", "#131222", "#1a182e"],
}
