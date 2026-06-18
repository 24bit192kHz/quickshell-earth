#version 440

layout(location = 0) in vec2 coord;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float seasonAngle;
    float visualSunAngleProp;
    float utcDaysMod;
    float cameraTilt;
    float time;
};

layout(binding = 1) uniform sampler2D earthTex;
layout(binding = 2) uniform sampler2D cloudTex;
layout(binding = 3) uniform sampler2D nightTex;
layout(binding = 4) uniform sampler2D bumpTex;
layout(binding = 5) uniform sampler2D waterTex;

#define PI 3.14159265359

vec3 rotateX(vec3 p, float a) {
    float c = cos(a), s = sin(a);
    return vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
}

vec3 rotateY(vec3 p, float a) {
    float c = cos(a), s = sin(a);
    return vec3(p.x * c + p.z * s, p.y, -p.x * s + p.z * c);
}

float fract_safe(float v) {
    return v - floor(v);
}

// Simple 2D hash for noise
float hash21(vec2 p) {
    return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// 2D Value Noise
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
    float x = coord.x * 2.0 - 1.0;
    float y = 1.0 - coord.y * 2.0;
    
    float z2 = 1.0 - x*x - y*y;
    if (z2 < 0.0) {
        fragColor = vec4(0.0);
        return;
    }
    float z = sqrt(z2);
    vec3 sphereNorm = vec3(x, y, z);
    
    // Rotate the geometric normal by cameraTilt to allow looking at the poles
    // This spins the physical globe under the camera without changing the light source direction.
    vec3 earthNorm = rotateX(sphereNorm, -cameraTilt);

    float tilt = 0.4084;
    float poleDir = visualSunAngleProp - seasonAngle;
    
    vec3 np = vec3(
        sin(tilt) * cos(poleDir),
        cos(tilt),
        sin(tilt) * sin(poleDir)
    );

    vec3 baseSunVec = normalize(vec3(cos(visualSunAngleProp), 0.0, sin(visualSunAngleProp)));
    vec3 sunVec = rotateX(baseSunVec, -cameraTilt);

    float greenwichAngle = visualSunAngleProp - (utcDaysMod - 0.5) * 2.0 * PI;
    
    vec3 greenwichVec = normalize(vec3(cos(greenwichAngle), 0.0, sin(greenwichAngle)));
    greenwichVec = normalize(greenwichVec - dot(greenwichVec, np) * np);
    
    vec3 eastVec = normalize(cross(np, greenwichVec));
    
    vec3 eqPlane = earthNorm - dot(earthNorm, np) * np;
    float eqLen = length(eqPlane);
    eqPlane = eqPlane / max(0.0001, eqLen);
    
    // Longitude is angle from Greenwich
    float absoluteLon = atan(dot(eqPlane, eastVec), dot(eqPlane, greenwichVec));
    float cloudLon = absoluteLon + (utcDaysMod * 0.06 * PI); // slight drift
    
    // Latitude
    float earthLat = asin(dot(earthNorm, np));

    vec2 earthUV = vec2(fract_safe(absoluteLon / (2.0 * PI) + 0.5), 0.5 - earthLat / PI);
    vec2 cloudUV = vec2(fract_safe(cloudLon / (2.0 * PI) + 0.5), earthUV.y);

    vec2 texel = vec2(1.0 / 8192.0, 1.0 / 4096.0);
    
    // Raw diffuse dot
    float nDotL = dot(sphereNorm, sunVec);
    
    // Bump mapping
    float waterMask = texture(waterTex, earthUV).r;
    float bump = texture(bumpTex, earthUV).r;
    
    // Disable bump mapping on water to hide JPEG compression blocks
    float bumpScale = 0.003 * (1.0 - waterMask); 
    
    float dbDu = (texture(bumpTex, earthUV + vec2(texel.x, 0.0)).r - bump) / texel.x;
    float dbDv = (texture(bumpTex, earthUV + vec2(0.0, texel.y)).r - bump) / texel.y;
    
    // Apply bump mapping to the local earth normal, then rotate back to camera space for lighting
    vec3 bumpNormLocal = normalize(earthNorm - vec3(dbDu, dbDv, 0.0) * bumpScale);
    vec3 bumpNorm = rotateX(bumpNormLocal, cameraTilt);
    
    float bumpDiffuse = max(dot(bumpNorm, sunVec), 0.0);
    
    // We use bumpDiffuse mostly, but blend back to raw sphere normal at the very edge of the dark side
    // to prevent weird hard artifacts on the terminator.
    float diffuse = mix(max(nDotL, 0.0), bumpDiffuse, smoothstep(-0.1, 0.1, nDotL));

    // Water & Specular
    vec3 viewVec = vec3(0.0, 0.0, 1.0);
    vec3 halfVec = normalize(sunVec + viewVec);
    float specBase = max(dot(bumpNorm, halfVec), 0.0);
    // Softer, wider specular highlight for the ocean
    float specular = pow(specBase, 35.0) * waterMask * 1.0;
    // Add a broad, very soft specular for a "wet/glossy" atmosphere reflection
    float softSpecular = pow(max(dot(sphereNorm, halfVec), 0.0), 8.0) * 0.1;

    // Day Color with Specular
    vec3 dayColor = texture(earthTex, earthUV).rgb;
    dayColor = dayColor * diffuse + vec3(1.0, 0.95, 0.8) * specular + vec3(1.0) * softSpecular;

    // Atmospheric Scattering (Edge Glow and Sunset)
    float viewDot = max(dot(sphereNorm, viewVec), 0.0);
    float atmosThickness = pow(1.0 - viewDot, 3.5);
    
    // Rayleigh scattering shifts color at sunset (when nDotL is near 0)
    // High altitude is blue, low altitude (near terminator) is orange/red
    float twilight = smoothstep(-0.05, 0.0, nDotL) * (1.0 - smoothstep(0.0, 0.05, nDotL));
    vec3 atmosColorBlue = vec3(0.3, 0.6, 1.0) * atmosThickness * smoothstep(-0.2, 0.5, nDotL) * 1.2;
    vec3 atmosColorOrange = vec3(1.0, 0.4, 0.1) * atmosThickness * twilight * 1.5;
    
    dayColor += atmosColorBlue + atmosColorOrange;

    // Night Color
    vec3 nightColor = texture(nightTex, earthUV).rgb * vec3(1.0, 0.9, 0.7);
    // Night lights look best when exaggerated slightly and fading out gracefully
    nightColor *= 2.0;

    // Terminator transition
    float terminator = smoothstep(-0.15, 0.15, nDotL);
    vec3 color = mix(nightColor, dayColor, terminator);

    // Clouds
    // Warp cloud UV slightly over time for dynamic billowing
    vec2 cloudWarp = vec2(noise(cloudUV * 15.0 + time * 0.02), noise(cloudUV * 15.0 - time * 0.02)) * 0.003;
    vec4 cloudPixel = texture(cloudTex, cloudUV + cloudWarp);
    float cloudAlpha = cloudPixel.r * 0.9;
    
    // Cloud shadows
    vec2 shadowOffset = -sunVec.xy * texel * 15.0; 
    float cloudShadowAlpha = texture(cloudTex, cloudUV + cloudWarp + shadowOffset).r * 0.9;
    float cloudShadow = 1.0 - (cloudShadowAlpha * smoothstep(0.0, 0.2, nDotL) * 0.4);
    
    // Apply cloud shadow to earth
    color *= cloudShadow;
    
    // Add clouds on top
    vec3 cloudLitColor = mix(vec3(1.0, 0.6, 0.4), vec3(1.0), smoothstep(0.0, 0.3, nDotL));
    cloudLitColor *= max(dot(sphereNorm, sunVec), 0.0); 
    cloudLitColor += vec3(0.1, 0.15, 0.2) * (1.0 - max(dot(sphereNorm, sunVec), 0.0));
    
    // ── Lightning Storms ──
    // Only happens on the dark side (terminator < 0.2), in dense clouds
    float darkSide = 1.0 - smoothstep(-0.2, 0.2, nDotL);
    if (darkSide > 0.0 && cloudAlpha > 0.6) {
        // Create large "cells" for storm systems
        vec2 stormGrid = cloudUV * 30.0 + time * 0.05;
        vec2 stormCell = floor(stormGrid);
        vec2 stormFract = fract(stormGrid);
        
        // Is this cell active?
        float stormActive = step(0.96, hash21(stormCell)); // 4% chance of a storm cluster
        
        if (stormActive > 0.0) {
            // Generate a random center for the flash within the cell
            vec2 flashCenter = vec2(hash21(stormCell + 1.2), hash21(stormCell + 3.4));
            float distToCenter = length(stormFract - flashCenter);
            
            // Diffuse glow based on distance
            float flashGlow = smoothstep(0.6, 0.0, distToCenter);
            
            // Chaotic pulsing
            float flashTime = hash21(stormCell + floor(time * 12.0));
            float pulse = step(0.85, flashTime);
            
            // TLEs (Red sprites) - occasionally tint the top of the flash red
            vec3 flashColor = mix(vec3(0.7, 0.8, 1.0), vec3(1.0, 0.2, 0.4), step(0.98, hash21(stormCell + floor(time * 3.0))));
            
            float lightningIntensity = pulse * flashGlow * cloudAlpha * darkSide * 3.5;
            cloudLitColor += flashColor * lightningIntensity;
        }
    }
    
    color = mix(color, cloudLitColor, cloudAlpha * max(terminator, darkSide)); // Make clouds visible at night if illuminated by lightning
    
    // Night side clouds obscure city lights
    color = mix(color, vec3(0.01), cloudAlpha * (1.0 - terminator) * 0.8);
    
    fragColor = vec4(color, qt_Opacity);
}
