// Motri's look (folio-2025 Ligthing.js / MeshDefaultMaterial.js / Fog.js), as the web
// game's nature.js shades every park piece: flat light, a coloured core shadow, and
// range fog into the sky's horizon colour. Positions and normals in game units.
global uniform mat4 dah_world_to_game;
global uniform vec3 dah_cam;
global uniform vec3 dah_light_color;
global uniform float dah_light_intensity;
global uniform vec3 dah_shadow_color;
global uniform vec3 dah_horizon;
global uniform vec3 dah_light_dir;
global uniform float dah_fog_near;
global uniform float dah_fog_far;
global uniform float dah_time;
global uniform vec2 dah_wind_dir;
global uniform float dah_wind_strength;
global uniform float dah_wind_time;
global uniform sampler2D dah_perlin : repeat_enable, filter_linear;

vec3 motri_shade(vec3 base, vec3 n, float extra_shadow, float dist) {
	vec3 col = base * dah_light_color * dah_light_intensity;
	float core = smoothstep(1.0, -0.25, dot(n, dah_light_dir));
	col = mix(col, base * dah_shadow_color, clamp(max(core, extra_shadow), 0.0, 1.0));
	return mix(col, dah_horizon, smoothstep(dah_fog_near, dah_fog_far, dist));
}

vec3 to_game(mat4 model, vec3 local) {
	return (dah_world_to_game * (model * vec4(local, 1.0))).xyz;
}

vec3 normal_to_game(mat4 model, vec3 n) {
	return normalize(mat3(dah_world_to_game) * (mat3(model) * n));
}

vec2 wind_offset(vec2 p) {
	p *= 0.5;
	float n1 = texture(dah_perlin, p * 0.2 + dah_wind_dir * dah_wind_time).r - 0.5;
	float n2 = texture(dah_perlin, p * 0.1 + dah_wind_dir * dah_wind_time * 0.2).r - 0.5;
	return dah_wind_dir * (n1 + n2) * dah_wind_strength;
}

// The stone court (Floor.js): centre x, centre z, half width, half length.
uniform vec4 slab_area = vec4(0.0, -2.5, 9.0, 9.0);
float slab_at(vec2 p) {
	vec2 q = abs(p - slab_area.xy) - slab_area.zw;
	float edge = max(q.x, q.y);
	float n = texture(dah_perlin, p * 0.03).r;
	return 1.0 - smoothstep(-1.2, 0.8, edge + (n - 0.5) * 2.2);
}

// The pond: centre x, centre z, radius x, radius z. Above 0 in the water.
uniform vec4 pond = vec4(-22.0, -5.0, 7.0, 10.0);
float pond_at(vec2 p) {
	vec2 d = (p - pond.xy) / pond.zw;
	return 1.0 - length(d) + (texture(dah_perlin, p * 0.045).r - 0.5) * 0.35;
}
