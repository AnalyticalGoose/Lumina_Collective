shader_type spatial;

uniform vec4 bg_color : source_color;
uniform float uv_scale : hint_range(0.0, 10.0, 0.1) = 1.0;
uniform float percentage : hint_range(0.0, 1.0) = 1.0;
uniform float speed = 1.0;

uniform float wave_1_speed = -1.0;
uniform float wave_2_speed = 1.0;

uniform float wave_1_freq = 1.2;
uniform float wave_2_freq = 1.0;

uniform float wave_1_amp = 0.015;
uniform float wave_2_amp = 0.01;

uniform vec3 sun_dir = vec3(-0.2, 0.4, 1.0);
uniform vec4 water_colour : source_color = vec4(0.2, 0.4, 0.6, 1.0);
uniform vec4 foam_colour : source_color = vec4(0.8, 0.9, 1.0, 1.0);
uniform vec4 sky_colour : source_color = vec4(0.2, 0.6, 0.8, 1.0);
uniform vec4 specular_colour : source_color = vec4(1.0, 1.0, 1.0, 1.0);

vec2 hash(vec2 p) {
    p = vec2(dot(p,vec2(127.1,311.7)), dot(p,vec2(269.5,183.3)));
    return -1.0 + 2.0*fract(sin(p)*43758.5453123);
}

float noise(in vec2 p) {
    const float K1 = 0.366025404;
    const float K2 = 0.211324865;
    vec2 i = floor(p + (p.x+p.y)*K1);
    vec2 a = p - i + (i.x+i.y)*K2;
    float m = step(a.y,a.x);
    vec2 o = vec2(m,1.0-m);
    vec2 b = a - o + K2;
    vec2 c = a - 1.0 + 2.0*K2;
    vec3 h = max(0.5-vec3(dot(a,a), dot(b,b), dot(c,c)), 0.0);
    vec3 n = h*h*h*h*vec3(dot(a,hash(i+0.0)), dot(b,hash(i+o)), dot(c,hash(i+1.0)));
    return dot(n, vec3(70.0));
}

float height(vec2 p, float t) {
    float acc = 0.0;
    for (int i = 0; i < 4; i++) {
        for (int j = 0; j < 4; j++) {
            int seed = i + 5*j;
            float theta = 6.28318 * 1.618 * 10.0*float(seed);
            float up = cos(theta) * p.x - sin(theta) * p.y;
            float vp = sin(theta) * p.x + cos(theta) * p.y;
            float initial_phase = 6.28318 * 1.618 * float(seed);
            float k = pow(2.0, float(i));
            float phase = initial_phase + up*k + cos(vp) + 3.0*t + 0.5*k*t;
            float A = cos(phase)/(k*k);
            acc += A;
        }
    }
    return acc;
}

vec4 hn_fdm(vec2 p, float t) {
    float h = height(p, t);
    vec2 vx = vec2(0.1, 0.0);
    vec2 vy = vec2(0.0, 0.1);
    float hx = height(p+vx, t);
    float hy = height(p+vy, t);
    float dx = (hx - h);
    float dy = (hy - h);

    vec3 v1 = normalize(vec3(vx.x, 0.0, dx));
    vec3 v2 = normalize(vec3(0.0, vy.y, dy));
    vec3 norm = cross(v1, v2);

    return vec4(norm, h);
}

vec4 wave(vec2 uv, vec4 wave_color, float level, float freq, float amp, float sin_shift, float speed1) {
    float sinus = sin((uv.x + sin_shift + TIME * speed1) * freq) * amp;
    float shifted_level = (1.0 + 2.0 * amp) * level - amp;
    float threshold = step(1.0 - sinus - shifted_level, uv.y);
    return wave_color * threshold;
}

void fragment() {
    vec2 uv = UV;
    vec2 uv_screen = (uv - 0.5) * uv_scale;

    vec4 nh = hn_fdm(uv_screen * 10.0, TIME * speed);
    float h = nh.w;
    vec3 norm = nh.xyz;

    vec3 color;
    if (dot(sun_dir, norm) > 0.98) {
        color = specular_colour.rgb;
    } else {
        color = mix(water_colour.rgb, sky_colour.rgb, dot(norm, normalize(vec3(0.0, 0.2, 1.0))));
    }

    vec2 uv2 = vec2(uv.y, 1.0 - uv.x);
    vec4 shadowWaveColor = vec4(color * 0.6, 1.0);
    vec4 wave1 = wave(uv2, shadowWaveColor, percentage, wave_1_freq, wave_1_amp, 0.0, wave_1_speed);
    vec4 wave2 = wave(uv2, vec4(color, 1.0), percentage, wave_2_freq, wave_2_amp, 0.7785 * TIME, wave_2_speed);
    vec4 combined_waves = mix(wave1, wave2, wave2.a);

    vec3 final_color = mix(bg_color.rgb, combined_waves.rgb, combined_waves.a);

    ALBEDO = final_color;
    METALLIC = 0.0;
    ROUGHNESS = 0.5;
}