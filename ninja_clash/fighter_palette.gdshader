shader_type canvas_item;
uniform vec4 clan_color : source_color = vec4(0.31, 0.82, 0.9, 1.0);
varying vec4 vertex_tint;
void vertex() {
	vertex_tint = COLOR;
}
void fragment() {
	vec4 pixel = texture(TEXTURE, UV);
	float accent = step(0.12, min(pixel.g, pixel.b) - pixel.r) * step(0.2, pixel.g);
	vec3 recolored = clan_color.rgb * (0.22 + 0.78 * max(pixel.g, pixel.b));
	COLOR = vec4(mix(pixel.rgb, recolored, accent), pixel.a) * vertex_tint;
}
