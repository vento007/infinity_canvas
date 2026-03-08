#include <flutter/runtime_effect.glsl>

uniform vec2 uA;
uniform vec2 uB;
uniform float uWidth;
uniform float uTime;
uniform float uIntensity;
uniform float uVariant;
uniform float uSeed;

out vec4 fragColor;

vec2 segmentDistanceAndT(vec2 p, vec2 a, vec2 b) {
  vec2 ab = b - a;
  float len2 = max(dot(ab, ab), 0.0001);
  float t = clamp(dot(p - a, ab) / len2, 0.0, 1.0);
  vec2 c = a + ab * t;
  float d = length(p - c);
  return vec2(d, t);
}

float hash12(vec2 p) {
  vec3 p3 = fract(vec3(p.xyx) * 0.1031);
  p3 += dot(p3, p3.yzx + 33.33);
  return fract((p3.x + p3.y) * p3.z);
}

float noise2(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  float a = hash12(i);
  float b = hash12(i + vec2(1.0, 0.0));
  float c = hash12(i + vec2(0.0, 1.0));
  float d = hash12(i + vec2(1.0, 1.0));
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  mat2 m = mat2(1.6, 1.2, -1.2, 1.6);
  for (int i = 0; i < 4; i++) {
    v += a * noise2(p);
    p = m * p;
    a *= 0.5;
  }
  return v;
}

vec3 hsv2rgb(vec3 c) {
  vec3 p = abs(fract(c.xxx + vec3(0.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
  vec3 rgb = clamp(p - 1.0, 0.0, 1.0);
  return c.z * mix(vec3(1.0), rgb, c.y);
}

void main() {
  vec2 p = FlutterFragCoord().xy;
  vec2 dt = segmentDistanceAndT(p, uA, uB);
  float widthSafe = max(uWidth, 0.0001);
  float dist = dt.x / widthSafe;
  float t = dt.y;

  vec2 flowUV = vec2(t * 7.0, dist * 2.4) + vec2(uTime * 0.21, -uTime * 0.14) + vec2(uSeed * 1.7, uSeed * 0.9);
  float grain = hash12(p * 0.015 + vec2(uSeed, uTime * 0.08)) - 0.5;
  float warpNoise = fbm(flowUV * 1.4) - 0.5;
  dist += (grain * 0.06 + warpNoise * 0.13) * (0.35 + 0.65 * smoothstep(0.1, 1.5, dist));

  float core = exp(-dist * dist * (4.2 + uVariant * 1.9));
  float mid = exp(-dist * (2.1 + uVariant * 0.52));
  float glow = exp(-dist * (0.88 + uVariant * 0.28));
  float edge = smoothstep(0.42, 1.35, dist);
  float filament = exp(-abs(dist - (0.22 + 0.04 * sin(uTime * 1.8 + t * 14.0))) * 18.0);

  float flowPhase = (t * (9.0 + uVariant * 4.0)) - (uTime * (1.2 + uVariant * 0.9));
  float flowA = 0.66 + 0.34 * sin(flowPhase * 6.2831853 + uSeed * 3.7);
  float flowB = 0.70 + 0.30 * sin((flowPhase * 1.93 + warpNoise * 0.9) * 6.2831853 + uSeed * 1.2);
  float flow = mix(flowA, flowB, 0.52);
  float pulse = 0.86 + 0.14 * sin((uTime * 2.4) + t * 12.0 + uSeed * 5.1);

  float hueBase = mix(0.53, 0.88, uVariant);
  float hueShift = 0.15 * sin(uTime * 0.72 + t * 9.0 + warpNoise * 3.8 + uSeed * 2.5);
  float huePulse = 0.08 * sin(uTime * 1.6 + t * 17.0 + uSeed * 4.1);
  vec3 coreColor = hsv2rgb(vec3(fract(hueBase + hueShift + huePulse), 0.90, 1.20));
  vec3 edgeColor = hsv2rgb(vec3(fract(hueBase + 0.27 - hueShift * 0.6), 0.96, 1.08));
  vec3 bloomColor = hsv2rgb(vec3(fract(hueBase - 0.22 + hueShift * 0.8), 0.98, 1.14));

  float strength = (core * 1.55 + mid * 0.92 + glow * 0.98 + filament * 0.58) * flow * pulse * uIntensity;
  vec3 color = mix(coreColor, edgeColor, edge);
  color += bloomColor * (glow * 0.52 + filament * 0.34);

  float laneFloor = (0.18 + 0.26 * core + 0.14 * filament) * uIntensity;
  vec3 rgb = color * strength + bloomColor * laneFloor;
  float alpha = clamp((core * 1.28 + mid * 0.72 + glow * 0.84) * uIntensity, 0.0, 1.0);
  fragColor = vec4(rgb, alpha);
}
