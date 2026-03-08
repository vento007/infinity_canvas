#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uTime;

out vec4 fragColor;

float distanceToGrid(vec2 uv, float density) {
  vec2 g = abs(fract(uv * density) - 0.5);
  return min(g.x, g.y);
}

vec3 neonGridColor(
  float dist,
  vec3 coreColor,
  vec3 edgeColor,
  float sharpness,
  float softness,
  float glowStrength
) {
  float core = exp(-dist * sharpness);
  float glow = exp(-dist * softness);
  return mix(coreColor, edgeColor, 1.0 - core) * (core + glow * glowStrength);
}

void main() {
  vec2 sizeSafe = max(uSize, vec2(1.0, 1.0));
  vec2 frag = FlutterFragCoord().xy;
  vec2 uv = frag / sizeSafe;

  vec2 centered = uv * 2.0 - 1.0;
  centered.x *= sizeSafe.x / sizeSafe.y;

  float t = uTime;

  vec3 baseA = vec3(0.015, 0.03, 0.07);
  vec3 baseB = vec3(0.01, 0.06, 0.11);
  vec3 color = mix(baseA, baseB, uv.y);

  float radial = max(0.0, 1.0 - length(centered) * 0.9);
  color += vec3(0.02, 0.10, 0.14) * radial;

  vec2 uvFine = uv + vec2(t * 0.01, t * 0.006);
  vec2 uvMajor = uv + vec2(-t * 0.004, t * 0.003);

  float dFine = distanceToGrid(uvFine, 22.0);
  float dMajor = distanceToGrid(uvMajor, 6.0);

  vec3 fineCore = neonGridColor(
    dFine,
    vec3(0.34, 0.96, 1.00),
    vec3(0.03, 0.33, 0.55),
    175.0,
    28.0,
    0.72
  );
  vec3 fineHalo = neonGridColor(
    dFine,
    vec3(0.34, 0.96, 1.00),
    vec3(0.02, 0.20, 0.34),
    64.0,
    8.0,
    1.15
  );

  vec3 majorCore = neonGridColor(
    dMajor,
    vec3(0.98, 0.38, 0.96),
    vec3(0.34, 0.08, 0.48),
    132.0,
    21.0,
    0.78
  );
  vec3 majorHalo = neonGridColor(
    dMajor,
    vec3(0.98, 0.38, 0.96),
    vec3(0.26, 0.06, 0.36),
    52.0,
    7.0,
    1.22
  );

  color += fineCore * 0.23;
  color += fineHalo * 0.17;
  color += majorCore * 0.26;
  color += majorHalo * 0.20;

  float scan = 0.5 + 0.5 * sin((uv.y + t * 0.08) * 260.0);
  color += vec3(0.06, 0.10, 0.14) * scan * 0.035;

  fragColor = vec4(color, 1.0);
}
