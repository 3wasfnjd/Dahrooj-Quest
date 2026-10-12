shader_type spatial;
render_mode unshaded;
// emissiveOrangeRadialGradient: #ff8641 to #ff3e00, normalised to unit luminance.
uniform vec3 color_a : source_color = vec3(1.0000, 0.5255, 0.2549);  // #ff8641
uniform vec3 color_b : source_color = vec3(1.0000, 0.2431, 0.0000);  // #ff3e00
uniform float intensity = 1.7;
uniform float on = 1.0;
void fragment() {
	vec3 c = mix(color_a, color_b, length(UV - 0.5) * 2.0);
	c /= dot(c, vec3(0.2126, 0.7152, 0.0722));
	ALBEDO = c * intensity * on;
}
