shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/motri.gdshaderinc"
// Flowers, fallen leaves and pebbles: a colour per instance (INSTANCE_CUSTOM), Motri-lit.
// mode 0: normal from the mesh; 1: flowers, hidden on the stone, in the pond and on the pitch.
uniform int mode = 0;
uniform vec4 pitch = vec4(0.0, -9.0, 11.0, 17.0);
varying vec3 g;
varying vec3 gn;
varying vec3 tint;
void vertex() {
	tint = INSTANCE_CUSTOM.rgb;
	if (mode == 1) {
		vec2 root = to_game(MODEL_MATRIX, vec3(0.0)).xz;
		vec2 q = abs(root - pitch.xy) - pitch.zw;
		if (slab_at(root) > 0.3 || pond_at(root) > -0.14 || max(q.x, q.y) < 1.5) VERTEX.y -= 1000.0;
	}
	g = to_game(MODEL_MATRIX, VERTEX);
	gn = normal_to_game(MODEL_MATRIX, NORMAL);
}
void fragment() {
	vec3 n = normalize(gn);
	if (!FRONT_FACING) n = -n;
	ALBEDO = motri_shade(tint, n, 0.0, length(g - dah_cam));
}
