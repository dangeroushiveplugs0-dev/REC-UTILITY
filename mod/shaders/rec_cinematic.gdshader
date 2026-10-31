shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
uniform float exposure : hint_range(0.8, 1.3) = 1.025;
uniform float contrast : hint_range(0.8, 1.3) = 1.045;
uniform float saturation : hint_range(0.0, 1.5) = 1.08;
uniform float aberration_strength : hint_range(0.0, 0.006) = 0.0018;
uniform float vignette_strength : hint_range(0.0, 0.4) = 0.13;

void fragment() {
	vec2 centered_uv = SCREEN_UV - vec2(0.5);
	float edge_distance = length(centered_uv) * 1.41421356;
	vec2 radial_direction = normalize(centered_uv + vec2(0.00001));
	float edge_fade = smoothstep(0.12, 0.9, edge_distance);
	vec2 channel_offset = radial_direction * aberration_strength * edge_fade;

	vec2 red_uv = clamp(SCREEN_UV + channel_offset, vec2(0.0), vec2(1.0));
	vec2 blue_uv = clamp(SCREEN_UV - channel_offset, vec2(0.0), vec2(1.0));
	vec3 graded;
	graded.r = texture(screen_texture, red_uv).r;
	graded.g = texture(screen_texture, SCREEN_UV).g;
	graded.b = texture(screen_texture, blue_uv).b;

	graded *= exposure;
	float luminance = dot(graded, vec3(0.2126, 0.7152, 0.0722));
	graded = mix(vec3(luminance), graded, saturation);
	graded = (graded - vec3(0.5)) * contrast + vec3(0.5);

	float vignette = 1.0 - vignette_strength * smoothstep(0.28, 1.0, edge_distance);
	COLOR = vec4(max(graded * vignette, vec3(0.0)), 1.0);
}
