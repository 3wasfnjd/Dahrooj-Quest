shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add;
// A warm pool of light on the ground under each pole at night (radial gradient,
// white to transparent, additive, opacity night * 0.35).
uniform vec3 color : source_color = vec3(1.0, 0.5255, 0.2549);  // #ff8641
uniform float opacity = 0.0;
void fragment() {
	float d = length(UV - 0.5) * 2.0;
	ALBEDO = color;
	ALPHA = opacity * clamp(1.0 - d, 0.0, 1.0);
}
