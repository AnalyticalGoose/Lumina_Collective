shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix;

// fire uniforms
uniform float detail_strength = 3.0;
uniform float scroll_speed = 1.2;
uniform float fire_height = 1.0;
uniform float fire_shape = 1.5;
uniform float fire_thickness = 0.55;
uniform float fire_sharpness = 1.0;
uniform float intensity = 1.0;

// noise uniforms
uniform int noise_octaves = 6;
uniform float noise_lacunarity = 3.0;
uniform float noise_gain = 0.5;
uniform float noise_amplitude = 1.0;
uniform float noise_frequency = 1.5;

// New uniforms for transparency
uniform float edge_softness = 0.1;
uniform float overall_transparency = 0.9;

// 2D Value noise function
float hash(vec2 p) {
    p = fract(p * 0.3183099 + vec2(0.1, 0.1));
    p *= 17.0;
    return fract(p.x * p.y * (p.x + p.y));
}

// 2D Value noise function (smooth)
float noise(vec2 x) {
    vec2 p = floor(x);
    vec2 f = fract(x);
    float n =
        hash(p)       * (1.0 - f.x) * (1.0 - f.y) +
        hash(p + vec2(1.0, 0.0)) * f.x * (1.0 - f.y) +
        hash(p + vec2(0.0, 1.0)) * (1.0 - f.x) * f.y +
        hash(p + vec2(1.0, 1.0)) * f.x * f.y;
    return n;
}

// Fractional Brownian Motion function (2D)
float fbm(vec2 p) {
    int octaves = noise_octaves;
    float lacunarity = noise_lacunarity;
    float gain = noise_gain;
    float amplitude = noise_amplitude;
    float frequency = noise_frequency;
    float total = 0.0;

    for (int i = 0; i < octaves; i++) {
        total += noise(p * frequency) * amplitude;
        frequency *= lacunarity;
        amplitude *= gain;
    }
    return total * 0.5;
}

void vertex() {
    // Billboarding
    MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
    MODELVIEW_MATRIX = MODELVIEW_MATRIX * mat4(vec4(length(MODEL_MATRIX[0].xyz), 0.0, 0.0, 0.0),
                                               vec4(0.0, length(MODEL_MATRIX[1].xyz), 0.0, 0.0),
                                               vec4(0.0, 0.0, length(MODEL_MATRIX[2].xyz), 0.0),
                                               vec4(0.0, 0.0, 0.0, 1.0));
    MODELVIEW_NORMAL_MATRIX = mat3(MODELVIEW_MATRIX);
}

void fragment() {
    vec2 uv = UV;
    // modified_uv for offset and animating UVs for fire
    vec2 modified_uv = -uv;
    modified_uv.x = mod(modified_uv.x, 1.0) - 0.5;
    modified_uv.y += 0.84; // size vertical

    // fire noise scroll effect
    float scroll = scroll_speed * detail_strength * TIME;

    // sample noise for fire
    float noise = fbm(detail_strength * modified_uv - vec2(0.0, scroll));

    // controls the intensity of noise
    // at different points in uvs. it thus
    // controls the shape of fire
    float fire_intensity = intensity - 16.0 * fire_sharpness * pow(
        max(
            0.0,
            length(
                modified_uv * vec2((1.0 / fire_thickness) + modified_uv.y * fire_shape, 1.0 / fire_height)
            ) - noise * max(0.0, modified_uv.y + 0.25)
        ),
        1.2
    );
    float fire_intensity1 = noise * fire_intensity * (1.5 - pow(1.0 * uv.y, 14.0));
    fire_intensity1 = clamp(fire_intensity1, 0.0, 1.0);

    // compute fire color
    vec3 fire_color = vec3(
        1.5 * fire_intensity1,
        1.5 * pow(fire_intensity1, 3.0),
        pow(fire_intensity1, 6.0)
    );

    // Modify alpha calculation for edge softness
    float distance_from_center = length(uv - vec2(0.5, 0.5));
    float edge_factor = smoothstep(0.5 - edge_softness, 0.5, distance_from_center);

    float alpha = fire_intensity * (1.0 - pow(uv.y, 3.0));
    alpha *= (1.0 - edge_factor) * overall_transparency;

    vec4 final_color = vec4(
        mix(vec3(0.0), fire_color, alpha),
        alpha
    );

    // apply to fragment
    ALBEDO = final_color.rgb;
    ALPHA = final_color.a;
}