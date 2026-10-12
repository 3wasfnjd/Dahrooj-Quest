shader_type spatial;
render_mode unshaded, cull_back;
#include "res://shaders/motri.gdshaderinc"
// Fireballs.js: a noisy ball of fire that swells and burns away into goo
// (triplanar perlin on the sphere, eaten from the bottom up as progress grows).
uniform float progress = 0.15;
uniform vec3 color_a : source_color = vec3(1.0, 0.0, 0.0);  // red
uniform vec3 color_b : source_color = vec3(1.0, 0.6471, 0.0);  // orange
uniform float strength = 1.7;
varying vec3 lp;
varying vec3 ln;
varying vec3 g;
void vertex() {
	lp = VERTEX;
	ln = NORMAL;
	g = to_game(MODEL_MATRIX, VERTEX);
}
void fragment() {
	float nx = texture(dah_perlin, lp.yz * 0.8).r;
	float ny = texture(dah_perlin, lp.xz * 0.8 + 0.8).r;
	float nz = texture(dah_perlin, lp.xy * 0.8 + 1.6).r;
	vec3 b = abs(normalize(ln));
	b /= b.x + b.y + b.z;
	float n = (nx * b.x + ny * b.y + nz * b.z - 0.15) / 0.75;
	n *= clamp(g.y * 2.0, 0.0, 1.0);
	n -= progress;
	if (n < 0.0) discard;
	vec3 fire = mix(color_a, color_b, n) * strength;
	vec3 goo = mix(vec3(0.0), dah_horizon, smoothstep(dah_fog_near, dah_fog_far, length(g - dah_cam)));
	ALBEDO = mix(fire, goo, step(n, 0.1));
}
