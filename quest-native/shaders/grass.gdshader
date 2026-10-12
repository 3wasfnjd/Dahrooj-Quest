shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/motri.gdshaderinc"
// Grass.js: three vertices per blade (UV.x = corner, UV.y = height randomness),
// turned to the camera and bent by the wind; short on the pitch, none on the stone
// or in the pond. Vertex positions are game units (the mesh sits at the park origin).
uniform vec3 grass_color : source_color = vec3(0.7216, 0.7137, 0.1804);  // #b8b62e
uniform vec4 pitch = vec4(0.0, -9.0, 11.0, 17.0);
uniform float blade_width = 0.13;
uniform float blade_height = 0.6;
uniform float blade_height_randomness = 0.6;
varying float tip;
varying float var;
varying vec3 g;
void vertex() {
	vec3 p = VERTEX;
	float corner = UV.x;
	tip = corner < 0.5 ? 1.0 : 0.0;
	float fade = 1.0 - smoothstep(12.0, 24.0, length(p.xz - dah_cam.xz));
	float h = blade_height * (blade_height_randomness * UV.y + (1.0 - blade_height_randomness)) * (texture(dah_perlin, p.xz * 0.0321).r + 0.5) * fade;
	vec2 q = abs(p.xz - pitch.xy) - pitch.zw;
	h *= mix(0.28, 1.0, smoothstep(0.0, 3.0, max(q.x, q.y)));
	float slab = slab_at(p.xz);
	h *= 1.0 - smoothstep(0.35, 0.7, slab);
	float pd = pond_at(p.xz);
	h *= 1.0 - smoothstep(-0.16, -0.08, pd);
	if (fade <= 0.0 || slab > 0.7 || pd > -0.08) p.y -= 1000.0;
	var = texture(dah_perlin, p.xz * 0.012).r;
	vec2 shape = corner < 0.5 ? vec2(0.0, 1.0) : (corner < 1.5 ? vec2(1.0, 0.0) : vec2(-1.0, 0.0));
	vec3 offset = vec3(shape.x * blade_width, shape.y * h, 0.0);
	float a = atan(p.z - dah_cam.z, p.x - dah_cam.x) - 1.5707963;
	offset.xz = vec2(offset.x * cos(a) - offset.z * sin(a), offset.x * sin(a) + offset.z * cos(a));
	p += offset;
	p.xz += wind_offset(p.xz) * tip * h * 2.0;
	VERTEX = p;
	g = to_game(MODEL_MATRIX, p);
}
void fragment() {
	vec3 c = grass_color * (0.93 + 0.14 * var);
	ALBEDO = motri_shade(c, vec3(0.0, 1.0, 0.0), 1.0 - tip, length(g - dah_cam));
}
