shader_type canvas_item;

// Subtle cinematic grade for the sunset city: cool shadows, warm highlights,
// a soft S-curve and a gentle vignette. Sits below the HUD.

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float strength = 0.55;

void fragment() {
	vec3 c = texture(screen_texture, SCREEN_UV).rgb;
	float lum = dot(c, vec3(0.299, 0.587, 0.114));

	vec3 cool = vec3(0.86, 0.94, 1.04);
	vec3 warm = vec3(1.06, 1.00, 0.90);
	vec3 tint = mix(cool, warm, smoothstep(0.12, 0.92, lum));
	c = mix(c, c * tint, strength);

	// gentle contrast
	c = (c - 0.5) * (1.0 + 0.05 * strength) + 0.5;

	// vignette
	vec2 q = SCREEN_UV - vec2(0.5);
	c *= 1.0 - dot(q, q) * 0.42 * strength;

	COLOR = vec4(clamp(c, vec3(0.0), vec3(1.0)), 1.0);
}
