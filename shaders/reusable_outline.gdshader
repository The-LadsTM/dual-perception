
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_prepass_alpha;

uniform sampler2D sprite_texture : source_color, filter_nearest, repeat_disable;
uniform bool billboard_enabled = true;
uniform float pour_angle = 0.0;
uniform bool is_hovered = false;
uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.1, 1.0);
uniform float outline_width : hint_range(1.0, 5.0) = 2.0;

void vertex() {
    vec3 origin = MODEL_MATRIX[3].xyz;
    float scale_x = length(MODEL_MATRIX[0].xyz);
    float scale_y = length(MODEL_MATRIX[1].xyz);

    vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
    vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);

    vec2 point = VERTEX.xy * vec2(scale_x, scale_y);
    point = mat2(vec2(cos(pour_angle), sin(pour_angle)),
                 vec2(-sin(pour_angle), cos(pour_angle))) * point;
    vec3 world_pos = origin + right * point.x + up * point.y;

    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
    if (!billboard_enabled) {
        POSITION = PROJECTION_MATRIX * MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
    }
}

vec4 sample_sprite(vec2 uv) {
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
        return vec4(0.0);
    }
    return texture(sprite_texture, uv);
}

void fragment() {
    vec4 original = sample_sprite(UV);
    ALBEDO = original.rgb;
    ALPHA = original.a;
}
