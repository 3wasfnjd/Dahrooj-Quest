shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix;
#include "res://shaders/motri.gdshaderinc"
// RainLines.js: quads falling from 20 m, wrapped around the view; short and slow for
// snow. UV = the quad corner (offset), UV2.x = the line's random. Game units.
uniform float thickness = 0.015;
uniform float elevation = 20.0;
uniform float incline = 0.2;
uniform float size = 40.0;
uniform vec2 center = vec2(0.0);
uniform float len = 2.0;
uniform float local_time = 0.0;
uniform float visible_ratio = 0.0;
uniform vec3 drop_color : source_color = vec3(0.82, 0.86, 0.9);
varying vec2 flake;
varying vec3 g;
void vertex() {
	flake = UV;
	float rnd = UV2.x;
	vec3 p = VERTEX;
	vec2 tangent = vec2(0.707, -0.707);
	p.xz *= size;
	p.xz -= center;
	float hs = size * 0.5;
	p.x = mod(p.x + hs, size) - hs;
	p.z = mod(p.z + hs, size) - hs;
	p.xz += center;
	p.xz += tangent * flake.x * thickness;
	float progress = mod(local_time + rnd, 1.0);
	p.y = elevation + len;
	p.y -= len * (1.0 - flake.y);
	p.y -= progress * (elevation + len);
	p.y = clamp(p.y, 0.0, elevation);
	p.y += step(visible_ratio, fract(rnd * 99.0)) * 99.0;
	p.xz += tangent * p.y * incline * -1.0;
	p.y -= 0.3;
	VERTEX = p;
	g = to_game(MODEL_MATRIX, p);
}
void fragment() {
	vec2 edge = min(flake, 1.0 - flake);
	ALPHA = smoothstep(0.0, 0.25, edge.x) * smoothstep(0.0, 0.18, edge.y) * 0.65;
	ALBEDO = motri_shade(drop_color, vec3(0.0, 1.0, 0.0), 0.0, length(g - dah_cam));
}
