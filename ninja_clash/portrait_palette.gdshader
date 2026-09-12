shader_type canvas_item;

uniform float source_hue = 0.52;
uniform float target_hue = 0.89;
varying vec4 vertex_tint;

void vertex() {
	vertex_tint = COLOR;
}

void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float high = max(pixel.r, max(pixel.g, pixel.b));
	float low = min(pixel.r, min(pixel.g, pixel.b));
	float chroma = high - low;
	float hue = 0.0;
	if (chroma > 0.001) {
		if (high == pixel.r) {
			hue = (pixel.g - pixel.b) / chroma;
		} else if (high == pixel.g) {
			hue = 2.0 + (pixel.b - pixel.r) / chroma;
		} else {
			hue = 4.0 + (pixel.r - pixel.g) / chroma;
		}
		hue = fract(hue / 6.0 + 1.0);
	}
	float saturation = chroma / max(high, 0.001);
	float distance = abs(hue - source_hue);
	distance = min(distance, 1.0 - distance);
	float accent = (1.0 - smoothstep(0.045, 0.10, distance)) * smoothstep(0.22, 0.50, saturation);
	// Keep the shared gold eyes and warm metal accents out of the cloth palette.
	float gold = smoothstep(0.09, 0.12, hue) * (1.0 - smoothstep(0.18, 0.21, hue));
	accent *= 1.0 - gold;
	float shifted = fract(hue + target_hue - source_hue + 1.0);
	vec3 wheel = clamp(abs(fract(vec3(shifted) + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0) - 1.0, 0.0, 1.0);
	vec3 recolored = high * mix(vec3(1.0), wheel, saturation);
	COLOR = vec4(mix(pixel.rgb, recolored, accent), pixel.a) * vertex_tint;
}
