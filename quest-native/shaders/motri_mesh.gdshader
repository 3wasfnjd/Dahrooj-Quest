shader_type spatial;
render_mode unshaded, cull_back;
#include "res://shaders/motri.gdshaderinc"
// Tree bodies, poles, benches, lanterns and crates: their palette texture, Motri-lit.
uniform sampler2D map : source_color, filter_nearest;
varying vec3 g;
varying vec3 gn;
void vertex() { g = to_game(MODEL_MATRIX, VERTEX); gn = normal_to_game(MODEL_MATRIX, NORMAL); }
void fragment() {
	ALBEDO = motri_shade(texture(map, UV).rgb, normalize(gn), 0.0, length(g - dah_cam));
}
