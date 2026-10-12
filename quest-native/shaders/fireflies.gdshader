shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
#include "res://shaders/motri.gdshaderinc"
// Fireflies around each pole light at night (PoleLights.js): points drifting on
// sines, sized by distance (in game units), glowing orange.
uniform vec3 color_a : source_color = vec3(1.0, 0.5255, 0.2549);  // #ff8641
uniform vec3 color_b : source_color = vec3(1.0, 0.2431, 0.0);  // #ff3e00
uniform float scale_k = 0.0;
void vertex() {
	float t = dah_time + UV.x;
	vec3 p = VERTEX + vec3(sin(t * 0.4) * 0.5, sin(t) * 0.2, sin(t * 0.3) * 0.5);
	VERTEX = p;
	float dist = max(length(to_game(MODEL_MATRIX, p) - dah_cam), 0.01);
	POINT_SIZE = clamp(45.0 * scale_k / dist, 0.0, 7.0);
}
void fragment() {
	float d = length(POINT_COORD - 0.5) * 2.0;
	if (d > 1.0) discard;
	vec3 c = mix(color_a, color_b, d);
	ALBEDO = c * (1.0 - d * d);
	ALPHA = 1.0;
}
