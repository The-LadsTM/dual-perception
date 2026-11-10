shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never;

uniform float remaining : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill_color : source_color = vec4(1.0, 0.76, 0.22, 1.0);
uniform vec4 track_color : source_color = vec4(0.20, 0.13, 0.09, 1.0);

void vertex() {
	vec2 scale = vec2(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz));
	vec3 view_center = MODELVIEW_MATRIX[3].xyz;
	POSITION = PROJECTION_MATRIX * vec4(view_center + vec3(VERTEX.xy * scale, 0.0), 1.0);
}

void fragment() {
	vec2 point = UV - vec2(0.5);
	float radius = length(point);
	float edge = max(fwidth(radius), 0.001);
	float turn = fract(atan(point.x, -point.y) / TAU + 1.0);
	float sector_edge = clamp(fwidth(turn), 0.001, 0.012);
	float filled = remaining >= 1.0 ? 1.0 : 1.0 - smoothstep(remaining - sector_edge, remaining + sector_edge, turn);
	ALBEDO = mix(track_color.rgb, fill_color.rgb, filled);
	ALPHA = 1.0 - smoothstep(0.48 - edge, 0.48 + edge, radius);
}
