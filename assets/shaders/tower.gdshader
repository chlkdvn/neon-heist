shader_type spatial;
render_mode diffuse_burley, specular_schlick_ggx;

uniform vec3 wall_color : source_color = vec3(0.10, 0.08, 0.17);
uniform vec3 lit_color : source_color = vec3(1.0, 0.66, 0.34);
uniform vec3 accent_color : source_color = vec3(1.0, 0.18, 0.55);
uniform vec3 glass_color : source_color = vec3(0.05, 0.08, 0.14);
uniform float floor_height = 3.5;
uniform float window_width = 1.75;
uniform float seed = 0.0;
uniform float tower_height = 40.0;
uniform float half_x = 10.0;
uniform float half_z = 10.0;
uniform float lit_ratio = 0.20;
uniform float accent_energy = 0.9;

varying vec3 lp;
varying vec3 ln;

float hash21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

void vertex() {
	lp = VERTEX;
	ln = NORMAL;
}

void fragment() {
	if (abs(ln.y) > 0.6) {
		ALBEDO = wall_color * 0.55;
		ROUGHNESS = 0.92;
		METALLIC = 0.0;
		EMISSION = vec3(0.0);
	} else {
	float u = abs(ln.x) > 0.5 ? lp.z : lp.x;
	float v = lp.y;
	float half_u = abs(ln.x) > 0.5 ? half_z : half_x;

	vec2 cell = vec2(floor(u / window_width), floor(v / floor_height));
	float fx = fract(u / window_width);
	float fy = fract(v / floor_height);

	float win = step(0.22, fx) * step(fx, 0.78) * step(0.30, fy) * step(fy, 0.80);
	float lit = step(1.0 - lit_ratio, hash21(cell + vec2(seed * 13.0, seed * 7.0)));
	float slab = 1.0 - step(0.05, fy) * step(fy, 0.16);

	vec3 wall = wall_color * (0.86 + 0.14 * hash21(cell * 0.31 + seed));
	ALBEDO = mix(wall, glass_color, win);
	ROUGHNESS = mix(0.9, 0.18, win);
	METALLIC = mix(0.0, 0.55, win);

	vec3 emit = lit_color * win * lit * 0.50;
	emit += accent_color * win * (1.0 - lit) * 0.04;

	// vertical neon corner strips
	float edge = 1.0 - smoothstep(0.0, 0.32, half_u - abs(u));
	emit += accent_color * edge * accent_energy * step(3.0, v);

	// glowing crown and ground band
	float crown = step(tower_height - 1.1, v);
	float base_band = 1.0 - step(0.0, v - 1.2);
	emit += accent_color * (crown * 1.5 + base_band * 0.35);
	emit += lit_color * slab * win * 0.15;

	EMISSION = emit;
	}
}
