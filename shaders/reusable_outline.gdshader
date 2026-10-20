
shader_type spatial;
render_mode unshaded, blend_mix, cull_disabled, depth_prepass_alpha;

uniform sampler2D sprite_texture : source_color, filter_nearest, repeat_disable;
uniform bool is_hovered = false;
uniform vec4 outline_color : source_color = vec4(1.0, 0.85, 0.1, 1.0);
uniform float outline_width : hint_range(1.0, 5.0) = 2.0;

void vertex() {
    // Reserve transparent space so outlines also work at the texture edges.
    vec2 texture_size = vec2(textureSize(sprite_texture, 0));
    vec2 expansion = vec2(1.0);
    if (is_hovered) {
        expansion += vec2(outline_width * 2.0) / texture_size;
    }
    VERTEX.xy *= expansion;

    vec3 origin = MODEL_MATRIX[3].xyz;
    float scale_x = length(MODEL_MATRIX[0].xyz);
    float scale_y = length(MODEL_MATRIX[1].xyz);

    vec3 right = normalize(INV_VIEW_MATRIX[0].xyz);
    vec3 up = normalize(INV_VIEW_MATRIX[1].xyz);

    vec3 world_pos = origin
        + right * VERTEX.x * scale_x
        + up * VERTEX.y * scale_y;

    POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world_pos, 1.0);
}

vec4 sample_sprite(vec2 uv) {
    if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
        return vec4(0.0);
    }
    return texture(sprite_texture, uv);
}

void fragment() {
    vec2 pixel_size = 1.0 / vec2(textureSize(sprite_texture, 0));
    vec2 expansion = vec2(1.0);
    if (is_hovered) {
        expansion += vec2(outline_width * 2.0) * pixel_size;
    }
    vec2 sprite_uv = (UV - vec2(0.5)) * expansion + vec2(0.5);
    vec4 original = sample_sprite(sprite_uv);

    float nearby_alpha = 0.0;

    if (is_hovered) {
        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                vec2 offset = vec2(float(x), float(y))
                    * pixel_size * outline_width;

                nearby_alpha = max(
                    nearby_alpha,
                    sample_sprite(sprite_uv + offset).a
                );
            }
        }
    }

    ALBEDO = original.rgb;
    ALPHA = original.a;

    if (is_hovered && original.a < 0.05 && nearby_alpha > 0.1) {
        ALBEDO = outline_color.rgb;
        ALPHA = outline_color.a;
    }
}
