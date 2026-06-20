#version 440

layout(location = 0) in vec2 coord;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float localSiderealTime;
    float userTiltOffset;
    float aspect;
};

layout(binding = 1) uniform sampler2D bgTex;

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

float hash13(vec3 p3) {
    p3  = fract(p3 * .1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

float noise(vec3 p) {
    vec3 i = floor(p);
    vec3 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    return mix(
        mix(mix(hash13(i + vec3(0,0,0)), hash13(i + vec3(1,0,0)), f.x),
            mix(hash13(i + vec3(0,1,0)), hash13(i + vec3(1,1,0)), f.x), f.y),
        mix(mix(hash13(i + vec3(0,0,1)), hash13(i + vec3(1,0,1)), f.x),
            mix(hash13(i + vec3(0,1,1)), hash13(i + vec3(1,1,1)), f.x), f.y), f.z);
}

float fbm(vec3 p) {
    float f = 0.0;
    float w = 0.5;
    for(int i = 0; i < 4; i++) {
        f += w * noise(p);
        p *= 2.05;
        w *= 0.5;
    }
    return f;
}

vec3 renderStars(vec3 ray) {
    vec3 color = vec3(0.0);
    // 3 layers of infinite procedural stars
    for(int i = 1; i <= 3; i++) {
        float scale = 300.0 * float(i);
        vec3 p = ray * scale;
        vec3 ip = floor(p);
        vec3 fp = fract(p);
        
        float h1 = hash13(ip);
        float h2 = hash13(ip + 12.34);
        float h3 = hash13(ip + 56.78);
        
        vec3 starPos = vec3(h1, h2, h3);
        float dist = length(fp - starPos);
        
        // Very sharp, vector-like stars
        float size = mix(0.01, 0.06, hash13(ip * 2.0));
        float brightness = smoothstep(size, 0.0, dist);
        
        // Slight color variation (blue/white/orange giants)
        vec3 starColor = mix(vec3(1.0, 0.9, 0.8), vec3(0.8, 0.9, 1.0), h3);
        if(h1 > 0.95) starColor = vec3(1.0, 0.5, 0.2); // rare red giants
        
        // Random twinkle based on spatial position
        float twinkle = 0.5 + 0.5 * sin(h2 * 100.0);
        
        color += starColor * brightness * twinkle * (1.2 / float(i));
    }
    return color;
}

void main() {
    vec2 ndc = coord * 2.0 - 1.0;
    ndc.x *= aspect;
    
    // 90 degree FOV (z = -1.0)
    vec3 ray = normalize(vec3(ndc.x, -ndc.y, -1.5));
    
    // Apply camera tilt (with 1:10 parallax effect)
    ray = rotateX(ray, userTiltOffset * 0.1);
    
    // Apply sidereal rotation (with 1:10 parallax effect)
    ray = rotateY(ray, -localSiderealTime * 0.1);
    
    // 1. Procedural Stars (Vector math)
    vec3 bg = renderStars(ray);
    
    // 2. Procedural Milky Way Dust Band
    // The Milky Way is inclined ~60 degrees to the celestial equator
    vec3 mwRay = rotateX(ray, -60.0 * PI / 180.0);
    
    // Band structure along the galactic equator
    float mwMask = smoothstep(0.4, 0.0, abs(mwRay.y)); 
    
    // Cloudy noise layers
    float mwNoise = fbm(mwRay * 3.0);
    mwNoise *= fbm(mwRay * 12.0) * 1.5;
    
    // Galactic glow
    vec3 mwColor = vec3(0.04, 0.06, 0.12) * mwNoise * mwMask * 3.0;
    
    // Galactic center (brighter, warmer)
    float centerDist = length(vec2(mwRay.x - 1.0, mwRay.y));
    mwColor += vec3(0.15, 0.1, 0.05) * smoothstep(1.0, 0.0, centerDist) * mwMask * mwNoise * 2.0;
    
    bg += mwColor;
    
    fragColor = vec4(bg * qt_Opacity, 1.0);
}
