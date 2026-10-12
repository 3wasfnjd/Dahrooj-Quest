shader_type sky;
// The day sky (nature.js): pale horizon, rich top, the sun, stars at night.
// Directions are the world's; in VR the game world is not rotated.
global uniform vec3 dah_horizon;
global uniform vec3 dah_zenith;
global uniform vec3 dah_fog_a;
global uniform vec3 dah_sun_dir;
global uniform vec3 dah_light_color;
global uniform float dah_stars;
global uniform float dah_night;
float hash(vec3 p) { p = fract(p * 0.3183099 + 0.1); p *= 17.0; return fract(p.x * p.y * p.z * (p.x + p.y + p.z)); }
void sky() {
	vec3 d = normalize(EYEDIR);
	float h = clamp(d.y, 0.0, 1.0);
	vec3 col = mix(dah_horizon, dah_zenith, pow(h, 0.6));
	col = mix(col, dah_fog_a, 0.18 * (1.0 - h) * (0.5 + 0.5 * d.x));
	float s = max(dot(d, dah_sun_dir), 0.0);
	col += dah_light_color * (pow(s, mix(600.0, 1800.0, dah_night)) * mix(1.5, 0.65, dah_night) + pow(s, 10.0) * mix(0.25, 0.018, dah_night));
	col += step(0.9965, hash(floor(d * 220.0))) * smoothstep(0.05, 0.3, d.y) * dah_stars;
	col = mix(col, dah_horizon, step(d.y, 0.0));
	COLOR = col;
}
