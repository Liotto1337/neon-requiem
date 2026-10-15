// Elite / boss outline glow. One shader for every enemy type, drawn on a ColorRect that sits
// behind the body. Parameterized by modifier (rarity) colours:
//   mode 0 — single colour, mode 1 — two colours alternating around the ring,
//   mode 2 — rainbow (three or more modifiers).
// The ring is quantized to `pixel_steps` cells so it reads as pixel art; colours above 1.0
// cross the WorldEnvironment glow threshold and bloom.
shader_type canvas_item;
render_mode blend_add, unshaded;

uniform vec4 color_a : source_color = vec4(1.0, 0.2, 0.25, 1.0);
uniform vec4 color_b : source_color = vec4(0.2, 0.45, 1.0, 1.0);
uniform int mode = 0;
uniform float ring_radius = 0.36;
uniform float thickness = 0.07;
uniform float shape_mix = 0.0;
uniform float pixel_steps = 24.0;
uniform float energy = 1.6;
uniform float pulse_speed = 3.0;
uniform float spin_speed = 0.35;

vec3 hue_to_rgb(float h) {
	vec3 k = clamp(abs(mod(h * 6.0 + vec3(0.0, 4.0, 2.0), 6.0) - 3.0) - 1.0, 0.0, 1.0);
	return k;
}

void fragment() {
	vec2 cell = (floor(UV * pixel_steps) + 0.5) / pixel_steps;
	vec2 p = cell - vec2(0.5);
	float d_circle = length(p);
	float d_square = max(abs(p.x), abs(p.y));
	float d = mix(d_circle, d_square, shape_mix);
	float band = abs(d - ring_radius);
	float ring = 1.0 - step(thickness, band);
	float halo = (1.0 - smoothstep(thickness, thickness * 3.0, band)) * 0.35;
	float angle = atan(p.y, p.x) / 6.2831853 + 0.5;
	vec3 col = color_a.rgb;
	if (mode == 1) {
		col = mix(color_a.rgb, color_b.rgb, step(0.5, fract(angle * 2.0 + TIME * spin_speed)));
	} else if (mode == 2) {
		col = hue_to_rgb(fract(angle + TIME * spin_speed));
	}
	float pulse = 0.8 + 0.2 * sin(TIME * pulse_speed);
	float alpha = clamp(ring + halo, 0.0, 1.0) * pulse;
	COLOR = vec4(col * energy, alpha);
}
