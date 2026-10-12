shader_type canvas_item;
// The still drop shadows softened like Motri's filtered shadow map (canvas blur(2px)):
// a 7 x 7 gaussian, sigma 2 px, over the coverage (white on transparent: rgb holds it).
void fragment() {
	vec2 px = TEXTURE_PIXEL_SIZE;
	float s = 0.0;
	float wsum = 0.0;
	for (int j = -3; j <= 3; j++) {
		for (int i = -3; i <= 3; i++) {
			float w = exp(-float(i * i + j * j) / 8.0);
			s += texture(TEXTURE, UV + vec2(float(i), float(j)) * px).r * w;
			wsum += w;
		}
	}
	float v = s / wsum;
	COLOR = vec4(v, v, v, 1.0);
}
