shader_type spatial;
render_mode unshaded, cull_disabled;
#include "res://shaders/motri.gdshaderinc"
#include "res://shaders/motri_ground.gdshaderinc"
// Grass.js: three vertices per blade (UV.x = corner, UV.y = height randomness),
// turned to the camera and bent by the wind; short on the pitch, none on the stone
// or in the pond; pressed flat (and dirty) where a ball rolled; the drop shadow at the root. Vertex positions are game units (the mesh sits at the park origin).
// Finer than the web's blades for the headset (park.gd lays them densest near the player): narrow and
// short close up, widening with distance where the blades thin out, so the far lawn still reads full.
uniform vec3 grass_color : source_color = vec3(0.7216, 0.7137, 0.1804);  // #b8b62e
uniform vec4 pitch = vec4(0.0, -9.0, 11.0, 17.0);
uniform vec3 dirt : source_color = vec3(0.4784, 0.2902, 0.1333);  // #7a4a22
uniform float blade_width = 0.075;
uniform float far_width = 2.4;  // width multiplier at the fade ring
uniform float blade_height = 0.42;
uniform float blade_height_randomness = 0.6;
uniform float fade_near = 13.0;
uniform float fade_far = 23.0;
varying float tip;
varying float var;
varying float trk;
varying float shd;
varying vec3 g;
void vertex() {
	vec3 p = VERTEX;
	float corner = UV.x;
	tip = corner < 0.5 ? 1.0 : 0.0;
	float dist = length(p.xz - dah_cam.xz);
	float fade = 1.0 - smoothstep(fade_near, fade_far, dist);
	if (fade <= 0.0) {
		VERTEX = vec3(0.0, -1000.0, 0.0);  // past the ring: no texture reads, a degenerate blade
	} else {
		float h = blade_height * (blade_height_randomness * UV.y + (1.0 - blade_height_randomness)) * (texture(dah_perlin, p.xz * 0.0321).r + 0.5) * fade;
		vec2 q = abs(p.xz - pitch.xy) - pitch.zw;
		h *= mix(0.28, 1.0, smoothstep(0.0, 3.0, max(q.x, q.y)));
		trk = track_at(p.xz);
		h *= 1.0 - trk * 0.85;
		float slab = slab_at(p.xz);
		h *= 1.0 - smoothstep(0.35, 0.7, slab);
		float pd = pond_at(p.xz);
		h *= 1.0 - smoothstep(-0.16, -0.08, pd);
		if (slab > 0.7 || pd > -0.08) p.y -= 1000.0;
		var = texture(dah_perlin, p.xz * 0.012).r;
		shd = shadow_at(p.xz);
		float w = blade_width * mix(1.0, far_width, smoothstep(3.0, fade_far, dist));
		vec2 shape = corner < 0.5 ? vec2(0.0, 1.0) : (corner < 1.5 ? vec2(1.0, 0.0) : vec2(-1.0, 0.0));
		vec3 offset = vec3(shape.x * w, shape.y * h, 0.0);
		float a = atan(p.z - dah_cam.z, p.x - dah_cam.x) - 1.5707963;
		offset.xz = vec2(offset.x * cos(a) - offset.z * sin(a), offset.x * sin(a) + offset.z * cos(a));
		p += offset;
		p.xz += wind_offset(p.xz) * tip * h * 2.0;
		VERTEX = p;
	}
	g = to_game(MODEL_MATRIX, VERTEX);
}
void fragment() {
	vec3 c = mix(grass_color * (0.93 + 0.14 * var), dirt, clamp(trk * 1.2, 0.0, 0.8));
	ALBEDO = motri_shade(c, vec3(0.0, 1.0, 0.0), max(1.0 - tip, shd * 0.85), length(g - dah_cam));
}
