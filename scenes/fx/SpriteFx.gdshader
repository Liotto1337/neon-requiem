// Shared material for every code-drawn sprite and the tile layers.
//  * Neon boost: texels brighter than `neon_threshold` (the neon palette) are multiplied by
//    `neon_boost`, so they cross the WorldEnvironment glow threshold and bloom; matte
//    colours stay below it.
//  * Hit flash: modulate above 1.0 (e.g. Color(2, 2, 2)) blends the sprite towards white
//    instead of just brightening it.
//  * Elite outline (outline_mode >= 0): a 2 px silhouette ring around the sprite —
//    0 single colour, 1 two colours alternating around the body, 2 rainbow.
shader_type canvas_item;

uniform float neon_threshold = 0.9;
uniform float neon_boost = 1.9;
uniform int outline_mode = -1;
uniform vec4 color_a : source_color = vec4(1.0, 0.2, 0.25, 1.0);
uniform vec4 color_b : source_color = vec4(0.2, 0.45, 1.0, 1.0);
uniform float outline_energy = 1.6;
uniform float spin_speed = 0.35;
uniform float pulse_speed = 3.0;

varying vec2 local_pos;
varying vec4 modulate_color;

void vertex() {
	local_pos = VERTEX;
	modulate_color = COLOR;
}

vec3 hue_to_rgb(float h) {
	return clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
}

vec3 outline_color() {
	float angle = atan(local_pos.y, local_pos.x) / 6.2831853 + 0.5;
	if (outline_mode == 1) {
		return mix(color_a.rgb, color_b.rgb, step(0.5, fract(angle * 2.0 + TIME * spin_speed)));
	} else if (outline_mode == 2) {
		return hue_to_rgb(fract(angle + TIME * spin_speed));
	}
	return color_a.rgb;
}

void fragment() {
	// In fragment() COLOR is already texture * modulate; use the raw texel and the modulate.
	vec4 tex = texture(TEXTURE, UV);
	vec3 tint = modulate_color.rgb;
	float flash = clamp(max(tint.r, max(tint.g, tint.b)) - 1.0, 0.0, 1.0);
	vec3 base = tex.rgb * min(tint, vec3(1.0));
	float m = max(tex.r, max(tex.g, tex.b));
	base *= 1.0 + (neon_boost - 1.0) * smoothstep(neon_threshold - 0.05, neon_threshold, m);
	base = mix(base, vec3(1.8), flash);
	vec4 result = vec4(base, tex.a * modulate_color.a);
	if (outline_mode >= 0 && tex.a < 0.5) {
		float around = 0.0;
		for (int x = -2; x <= 2; x++) {
			for (int y = -2; y <= 2; y++) {
				if (abs(x) + abs(y) <= 2) {
					around = max(around, texture(TEXTURE, UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE).a);
				}
			}
		}
		if (around > 0.5) {
			float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
			result = vec4(outline_color() * outline_energy * pulse, modulate_color.a);
		}
	}
	COLOR = result;
}
