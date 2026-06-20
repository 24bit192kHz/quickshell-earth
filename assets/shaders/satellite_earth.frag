#version 440

layout(location = 0) in vec2 coord;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float angle;
    float tilt;
    float lightDirX;
    float lightDirY;
    float lightDirZ;
    float time;
};

layout(binding = 1) uniform sampler2D moonTex; // This is actually earthTex in this context
layout(binding = 2) uniform sampler2D cloudTex;
layout(binding = 3) uniform sampler2D nightTex;

const float PI  = 3.14159265359;
const float TAU = 6.28318530718;

vec3 rotateX(vec3 p, float a) {
    float c = cos(a), s = sin(a);
    return vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
}

vec3 rotateY(vec3 p, float a) {
    float c = cos(a), s = sin(a);
    return vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c);
}

vec2 sphereToUV(vec3 p) {
    float lon = atan(p.x, p.z);
    float lat = asin(clamp(p.y, -1.0, 1.0));
    return vec2(lon / TAU + 0.5, 0.5 - lat / PI);
}

float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

float noise(vec2 p) {
    vec2 i = floor(p);
    vec2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void main() {
    vec2 uv = coord * 2.0 - 1.0;
    float r = length(uv);

    if (r > 1.0) {
        fragColor = vec4(0.0);
        return;
    }

    float z = sqrt(1.0 - r * r);
    vec3 N = vec3(uv.x, -uv.y, z);

    vec3 pMoon = rotateY(rotateX(N, tilt), angle * TAU);
    vec2 moonUV = sphereToUV(pMoon);
    
    vec2 dx = dFdx(moonUV);
    vec2 dy = dFdy(moonUV);
    if (abs(dx.x) > 0.5) dx.x -= sign(dx.x);
    if (abs(dy.x) > 0.5) dy.x -= sign(dy.x);
    
    vec3 earthColor = textureGrad(moonTex, moonUV, dx, dy).rgb;

    // Multi-octave fluid noise (FBM) for realistic atmospheric flow
    float n1 = noise(moonUV * 6.0 + time * 0.01);
    float n2 = noise(moonUV * 12.0 - time * 0.02 + vec2(100.0));
    float n3 = noise(moonUV * 24.0 + time * 0.03 + vec2(200.0));
    
    float flowX = n1 + 0.5 * n2 + 0.25 * n3;
    float flowY = n2 + 0.5 * n3 + 0.25 * n1;
    
    vec2 cloudWarp = vec2(
        (flowX - 0.875) * 0.015,
        (flowY - 0.875) * 0.005
    );
    
    vec2 warpedCloudUV = moonUV + cloudWarp;

    // Read Clouds
    float cloudAlpha = textureGrad(cloudTex, warpedCloudUV, dx, dy).r;
    
    // Dynamic lighting based on the true 3D light vector
    vec3 L = normalize(vec3(lightDirX, lightDirY, lightDirZ));
    float NdotL = dot(N, L);

    // Earth atmosphere terminator
    float diffuse = smoothstep(-0.15, 0.15, NdotL);

    // City lights
    vec3 nightColor = textureGrad(nightTex, moonUV, dx, dy).rgb * vec3(1.0, 0.9, 0.7);
    nightColor *= 2.0;

    // Blend day and night
    vec3 color = mix(nightColor, earthColor, diffuse);

    // Very dark ambient starlight
    float ambient = 0.015;
    color += earthColor * vec3(0.9, 0.95, 1.0) * ambient;

    // Cloud shadow (offset towards the sun)
    vec2 shadowOffset = -vec2(lightDirX, -lightDirY) * 0.005;
    float cloudShadowAlpha = textureGrad(cloudTex, warpedCloudUV + shadowOffset, dx, dy).r * 0.9;
    float cloudShadow = 1.0 - (cloudShadowAlpha * smoothstep(0.0, 0.2, NdotL) * 0.4);
    
    color *= cloudShadow;

    // Dimmer, realistic sunlight
    vec3 sunColor = vec3(0.85, 0.83, 0.8);
    
    // Cloud lighting
    float cloudLight = max(NdotL, 0.0);
    vec3 cloudLitColor = mix(vec3(1.0, 0.6, 0.4), vec3(1.0), smoothstep(0.0, 0.3, NdotL));
    cloudLitColor *= cloudLight;
    cloudLitColor += vec3(0.1, 0.15, 0.2) * (1.0 - cloudLight);

    color = mix(color, cloudLitColor * sunColor, cloudAlpha);

    color *= sunColor;

    // Atmospheric rim scatter (very simple)
    float rim = 1.0 - max(dot(N, vec3(0.0, 0.0, 1.0)), 0.0);
    rim = smoothstep(0.6, 1.0, rim);
    vec3 atmosColor = vec3(0.3, 0.6, 1.0);
    color += atmosColor * rim * diffuse * 0.5;

    // Anti-aliased edge
    float aa = smoothstep(1.0, 0.98, r);
    fragColor = vec4(color, aa * qt_Opacity);
}
