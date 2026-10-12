// nature.js TRACK and SHADOW: the tracks picture (white where balls pressed the
// ground, Tracks.js) and the baked drop shadows, each over a square around the
// court: area = centre x, centre z, size (game units). Set by Park.
global uniform sampler2D dah_tracks : filter_linear;
global uniform vec3 dah_track_area;
global uniform sampler2D dah_shadow : filter_linear;
global uniform vec3 dah_shadow_area;

float track_at(vec2 p) {
	vec2 uv = (p - dah_track_area.xy) / dah_track_area.z + 0.5;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
	return texture(dah_tracks, uv).r;
}

float shadow_at(vec2 p) {
	vec2 uv = (p - dah_shadow_area.xy) / dah_shadow_area.z + 0.5;
	if (uv.x < 0.0 || uv.y < 0.0 || uv.x > 1.0 || uv.y > 1.0) return 0.0;
	return texture(dah_shadow, uv).r;
}
