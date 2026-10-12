shader_type spatial;
render_mode unshaded, cull_back;
#include "res://shaders/motri.gdshaderinc"
#include "res://shaders/motri_ground.gdshaderinc"
// Terrain.js grass, Floor.js stone slabs and the pond (nature.js groundMat).
// Marks: dirt where balls rolled (tracks); then the pond; then the drop shadows.
uniform vec3 grass_color : source_color = vec3(0.7216, 0.7137, 0.1804);  // #b8b62e
uniform vec3 slab_high : source_color = vec3(1.0000, 0.8118, 0.5451);  // #ffcf8b
uniform vec3 slab_low : source_color = vec3(0.6588, 0.4667, 0.3843);  // #a87762
uniform vec3 sand : source_color = vec3(1.0000, 0.6627, 0.3059);  // #ffa94e
uniform vec3 shallow : source_color = vec3(0.3569, 0.7608, 0.7255);  // #5bc2b9
uniform vec3 deep : source_color = vec3(0.0745, 0.2157, 0.3725);  // #13375f
uniform vec3 dirt : source_color = vec3(0.4784, 0.2902, 0.1333);  // #7a4a22
uniform sampler2D slabs : repeat_enable, filter_linear_mipmap_anisotropic;
// The slab picture is a blend factor, read raw as three.js does (no colour space).
varying vec3 g;
void vertex() { g = to_game(MODEL_MATRIX, VERTEX); }
void fragment() {
	vec2 w = g.xz;
	float slab = slab_at(w);
	vec3 slab_col = mix(slab_low, slab_high, texture(slabs, w * 0.175).r);
	vec3 c = mix(grass_color * (0.93 + 0.14 * texture(dah_perlin, w * 0.012).r), slab_col, slab);
	c = mix(c, dirt, clamp(track_at(w) * 1.4, 0.0, 0.9) * (1.0 - slab * 0.6));
	float pd = pond_at(w);
	float wet = 0.0;
	if (pd > -0.14) {
		c = mix(c, sand, smoothstep(-0.14, -0.05, pd));
		wet = smoothstep(-0.005, 0.025, pd);
		c = mix(c, mix(shallow, deep, smoothstep(0.0, 0.6, pd)), wet);
		float n = texture(dah_perlin, w * 0.1 + floor(pd * 9.0 + dah_time * 0.22) * 0.345).r;
		float ripple = step(0.93 - n * 0.22, fract(pd * 9.0 + dah_time * 0.22)) * (1.0 - smoothstep(0.12, 0.5, pd)) * wet;
		float shore = smoothstep(-0.02, 0.0, pd) * (1.0 - smoothstep(0.012, 0.03, pd));
		c = mix(c, vec3(1.0), clamp(ripple * 0.85 + shore, 0.0, 1.0));
	}
	ALBEDO = motri_shade(c, vec3(0.0, 1.0, 0.0), shadow_at(w) * 0.85 * (1.0 - wet * 0.4), length(g - dah_cam));
}
