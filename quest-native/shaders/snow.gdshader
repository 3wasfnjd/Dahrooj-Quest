shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix;
#include "res://shaders/motri.gdshaderinc"
#include "res://shaders/motri_ground.gdshaderinc"
// Snow.js: soft snow drifts on the ground that rise while it snows and melt away
// otherwise; dug out where balls rolled. The plane follows the eye (center).
uniform float snow_elevation = -1.0;
uniform vec2 center = vec2(0.0);
uniform vec3 snow_color : source_color = vec3(0.86, 0.9, 0.94);
varying float delta;
varying vec2 w;
varying vec3 g;
float elev(vec2 p) {
	return snow_elevation + smoothstep(0.0, 1.0, texture(dah_perlin, p * 0.1).r * texture(dah_perlin, p * 0.07).r);
}
void vertex() {
	vec3 p = VERTEX;
	p.xz += center;
	float e = elev(p.xz);
	delta = e;
	w = p.xz;
	// Drifts stay low so Dahrooj can still roll: a quarter of Motri's height.
	p.y = max(e, 0.0) * 0.25 + 0.025;
	VERTEX = p;
	g = to_game(MODEL_MATRIX, p);
}
void fragment() {
	float a = smoothstep(0.022, 0.5, delta) * (1.0 - track_at(w) * 0.9);
	if (a < 0.1) discard;
	float grain = texture(dah_perlin, w * 0.18).r;
	ALBEDO = motri_shade(snow_color * (0.96 + grain * 0.04), vec3(0.0, 1.0, 0.0), 0.0, length(g - dah_cam));
	ALPHA = a;
}
