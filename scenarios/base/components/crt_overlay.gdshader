// Subtle CRT frame drawn over the whole screen: horizontal scanlines via a
// sin() modulation on UV.y plus a radial vignette via distance from the
// centre. Both only darken (black with low alpha), so any content below —
// terminal green or bright browser page — keeps its own colours and stays
// readable. Defaults are deliberately low.
shader_type canvas_item;

// Peak darkening of a scanline. Keep <= 0.1 or small text starts to shimmer.
uniform float scanline_alpha : hint_range(0.0, 0.3) = 0.07;
// Number of dark lines over the rect height. 360 = 3px period at 1080p.
uniform float scanline_count : hint_range(60.0, 1080.0) = 360.0;
// Peak darkening in the screen corners.
uniform float vignette_alpha : hint_range(0.0, 0.6) = 0.22;
// Distance from centre (in UV units) where the vignette starts to fade in.
uniform float vignette_start : hint_range(0.0, 0.7) = 0.42;

void fragment() {
	float wave = sin(UV.y * scanline_count * TAU);
	float scan = (wave * 0.5 + 0.5) * scanline_alpha;
	float dist = distance(UV, vec2(0.5));
	float vig = smoothstep(vignette_start, 0.78, dist) * vignette_alpha;
	COLOR = vec4(0.0, 0.0, 0.0, scan + vig);
}
