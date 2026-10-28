shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform sampler2D albedo_tex : source_color, filter_nearest;
uniform float grime_strength : hint_range(0.0, 0.6) = 0.14;
uniform float base_darken : hint_range(0.0, 1.0) = 0.74;
uniform float base_height = 1.6;

varying vec3 wpos;

float hash12(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash12(i);
	float b = hash12(i + vec2(1.0, 0.0));
	float c = hash12(i + vec2(0.0, 1.0));
	float d = hash12(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 c = texture(albedo_tex, UV).rgb;

	// world-space weathering and vertical rain streaks
	float n = vnoise(wpos.xz * 0.18 + vec2(wpos.y * 0.06));
	float streak = vnoise(vec2(wpos.x * 2.7 + wpos.z * 2.7, wpos.y * 0.55));
	float dirt = smoothstep(0.32, 0.88, n * 0.85 + streak * 0.15);
	c *= 1.0 - grime_strength * dirt;

	// grime collects at the base of the facade
	float base = 1.0 - smoothstep(0.12, base_height, wpos.y);
	c *= mix(1.0, base_darken, base);

	// break up perfectly flat swatches
	float lum = dot(c, vec3(0.299, 0.587, 0.114));
	c = mix(c, vec3(lum), 0.06);

	ALBEDO = c;
	ROUGHNESS = 0.80 + 0.14 * n;
	METALLIC = 0.0;
}
