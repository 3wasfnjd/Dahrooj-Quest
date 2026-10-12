shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/motri.gdshaderinc"
// Foliage.js: leaf planes cut out by the foliage SDF that the wind turns.
uniform sampler2D foliage_sdf : filter_linear_mipmap;
uniform vec3 color_a : source_color;
uniform vec3 color_b : source_color;
uniform float threshold = 0.3;
varying vec3 g;
varying vec3 gn;
varying float turn;
void vertex() {
	g = to_game(MODEL_MATRIX, VERTEX);
	gn = normal_to_game(MODEL_MATRIX, NORMAL);
	turn = length(wind_offset(VERTEX.xz)) * 2.2;
}
void fragment() {
	vec2 c = UV - 0.5;
	float s = sin(turn), k = cos(turn);
	vec2 ruv = vec2(c.x * k - c.y * s, c.x * s + c.y * k) + 0.5;
	float edge = texture(foliage_sdf, ruv).r - threshold - 0.1;
	if (edge < 0.0) discard;
	vec3 n = normalize(gn);
	if (!FRONT_FACING) n = -n;
	vec3 base = mix(color_a, color_b, smoothstep(0.0, 1.0, dot(n, dah_light_dir)));
	ALBEDO = motri_shade(base, n, 0.0, length(g - dah_cam));
}
