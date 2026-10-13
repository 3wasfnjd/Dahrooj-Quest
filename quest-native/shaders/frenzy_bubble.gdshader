// Pop Frenzy («حمّى الفرقعة»): the floating soap bubbles, one MultiMesh for all of them.
// A thin soap film: interference colours that swirl and drain downward (thicker at the
// bottom), a Fresnel rim, two window reflections and a tint from the instance colour.
// Instance colour (linear): rgb = the bubble's colour; alpha encodes the look:
//   1.0 plain, 0.85 the chain colour (a soft pulse, so the player sees what to pop next),
//   0.5 the rainbow bubble (every colour, running).
// `gold` (0..1): FRENZY, the film turns to liquid gold.
shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, blend_mix, shadows_disabled;

uniform float gold = 0.0;

varying vec3 vN;
varying vec3 vV;
varying vec3 vP;
varying vec4 vC;
varying float vSeed;

void vertex() {
	vec4 mv = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	vN = normalize((MODELVIEW_MATRIX * vec4(NORMAL, 0.0)).xyz);
	vV = normalize(-mv.xyz);
	vP = VERTEX;
	vC = COLOR;
	vSeed = fract(MODEL_MATRIX[3].x * 0.731 + MODEL_MATRIX[3].z * 0.517) * 6.2831;
}

void fragment() {
	vec3 n = normalize(vN);
	vec3 v = normalize(vV);
	float c = abs(dot(n, v));
	float f = 1.0 - c;
	vec3 p = normalize(vP);
	float rainbow = 1.0 - step(0.7, vC.a);
	float hl = step(0.7, vC.a) * (1.0 - step(0.95, vC.a));
	float t = TIME;
	// Film thickness: slow swirls, draining toward the bottom.
	float th = 0.5 + 0.22 * sin(p.x * 4.0 + t * 0.9 + vSeed + sin(p.y * 5.0 - t * 0.6) * 1.8)
		+ 0.18 * sin(p.z * 6.0 - t * 0.5 + vSeed * 0.5) - 0.3 * p.y;
	th += rainbow * (0.35 * sin(p.y * 3.0 + t * 2.2) + t * 0.25);
	vec3 film = 0.5 + 0.5 * cos(6.2831 * (th * 2.4 / (0.35 + c) + vec3(0.0, 0.33, 0.67)));
	vec3 col = mix(vC.rgb, film, mix(0.3, 0.92, rainbow));
	// A gentle glow inside: the colour reads even in the bubble's thin middle.
	float core = 0.18 + 0.1 * hl * (0.5 + 0.5 * sin(t * 6.0 + vSeed)) + 0.22 * rainbow;
	col *= 1.0 + 0.45 * rainbow;
	vec3 r = reflect(-v, n);
	float win = smoothstep(0.92, 0.97, dot(r, normalize(vec3(-0.45, 0.6, 0.65))))
		+ 0.6 * smoothstep(0.95, 0.985, dot(r, normalize(vec3(0.6, 0.3, 0.75))));
	float rim = pow(f, 1.5);
	// FRENZY: liquid gold with the film's shimmer still running through it.
	vec3 goldc = vec3(1.0, 0.62, 0.08) * (0.8 + 0.45 * film.g) + vec3(0.25, 0.18, 0.0) * film.r;
	col = mix(col, goldc, gold * (1.0 - rainbow * 0.6));
	col = col * (0.85 + rim * 0.55 + hl * 0.35 * rim) + win * 0.95;
	ALBEDO = col;
	ALPHA = clamp(core + rim * 0.78 + win * 0.7 + gold * 0.12 + hl * rim * 0.2, 0.0, 1.0);
}
