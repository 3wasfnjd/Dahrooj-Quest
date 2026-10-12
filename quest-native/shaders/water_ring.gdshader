shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
#include "res://shaders/motri.gdshaderinc"
// The pond's surface effects (nature.js water): white rings where something meets the
// water and ripples fading from white into the shallow colour (INSTANCE_CUSTOM.rgb,
// linear), in the scene fog.
uniform float alpha = 1.0;
varying vec3 g;
varying vec3 col;
void vertex() {
	col = INSTANCE_CUSTOM.rgb;
	g = to_game(MODEL_MATRIX, VERTEX);
}
void fragment() {
	ALBEDO = mix(col, dah_horizon, smoothstep(dah_fog_near, dah_fog_far, length(g - dah_cam)));
	ALPHA = alpha;
}
