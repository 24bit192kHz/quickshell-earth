#version 440

layout(location = 0) in vec2 coord;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    float utcDaysMod;
    float cameraTilt;
    float time;
    float gmst;
    float sunRa;
    float sunDec;
    float userLonRad;
    float userOffsetAngle;
    float cloudOpacity;
};

layout(binding = 1) uniform sampler2D ringTex;

const float PI = 3.14159265359;

vec3 rotateX(vec3 p, float a) {
    float c = cos(a), s = sin(a);
    return vec3(p.x, p.y * c - p.z * s, p.y * s + p.z * c);
}

void main() {
    // coord goes from 0 to 1 over the 3x enlarged ring plane.
    // We want the planet to be size 1.0, so the quad goes from -1.5 to 1.5.
    float x = (coord.x - 0.5) * 3.0;
    float y = (0.5 - coord.y) * 3.0; // Y is up

    // The ring is on the planet's equatorial plane. 
    // In camera coords, planet's north pole is tilted by -cameraTilt.
    // So the ring plane equation is y*cos(cameraTilt) + z*sin(cameraTilt) = 0.
    float sinT = sin(cameraTilt);
    float cosT = cos(cameraTilt);
    
    // Avoid division by zero when looking exactly edge-on.
    if (abs(sinT) < 0.001) {
        if (abs(y) > 0.02) {
            fragColor = vec4(0.0);
            return;
        }
        sinT = 0.001 * sign(sinT);
    }
    
    float z = -y * cosT / sinT;
    
    // Check occlusion by the planet
    float r2 = x*x + y*y;
    if (r2 <= 1.0) {
        float sphereFrontZ = sqrt(1.0 - r2);
        if (z <= sphereFrontZ) {
            // Ring is inside or behind the planet, so don't draw it.
            fragColor = vec4(0.0);
            return;
        }
    }
    
    // Convert to planet equatorial coordinates
    vec3 P_cam = vec3(x, y, z);
    vec3 P_planet = rotateX(P_cam, -cameraTilt); // P_planet.y should be 0
    
    float dist = length(P_planet);
    
    // Saturn ring limits relative to planet radius
    // Inner edge ~ 1.11, Outer edge ~ 2.27
    if (dist < 1.11 || dist > 2.27) {
        fragColor = vec4(0.0);
        return;
    }
    
    // Calculate UV for the 1D ring texture based on radius
    float u = (dist - 1.11) / (2.27 - 1.11);
    vec4 texColor = texture(ringTex, vec2(u, 0.5));
    
    // Shadow from the planet
    // We need the sun direction in planet coordinates.
    float localSiderealTime = gmst + userLonRad - userOffsetAngle;
    float sunLocalRa = sunRa - localSiderealTime;
    float cosSD = cos(sunDec);
    vec3 sunVec = normalize(vec3(sin(sunLocalRa) * cosSD, sin(sunDec), cos(sunLocalRa) * cosSD));
    
    // Ray from P_planet towards the sun: P + t * sunVec
    // Does it intersect the unit sphere?
    // |P + t*D|^2 = 1 => t^2 + 2t(P.D) + |P|^2 - 1 = 0
    float b = 2.0 * dot(P_planet, sunVec);
    float c = dist * dist - 1.0;
    float discriminant = b * b - 4.0 * c; // a = 1
    
    float shadow = 1.0;
    if (discriminant > 0.0) {
        float t1 = (-b - sqrt(discriminant)) / 2.0;
        float t2 = (-b + sqrt(discriminant)) / 2.0;
        // If either t > 0, the ray hits the planet
        if (t1 > 0.0 || t2 > 0.0) {
            shadow = 0.05; // deep shadow
        }
    }
    
    // Add lighting (ring is lit by sun depending on the sun angle)
    float illumination = max(abs(sunVec.y), 0.05); // Sun illuminates ring depending on its elevation above ring plane
    
    texColor.rgb *= shadow * illumination * 2.5; // Boost brightness slightly
    
    fragColor = texColor * qt_Opacity;
}
