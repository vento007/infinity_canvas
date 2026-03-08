#include <flutter/runtime_effect.glsl>

uniform vec2 uCenter;
uniform float uRadius;
uniform float uTime;
uniform float uStyle;
uniform float uIntensity;
uniform float uState;
uniform float uSeed;

out vec4 fragColor;

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
  vec2 p = FlutterFragCoord().xy - uCenter;
  float safeRadius = max(uRadius, 0.0001);
  vec2 uv = p / safeRadius;
  float d = length(uv);
  float angle = atan(uv.y, uv.x);

  float n = fbm(uv * 3.0 + vec2(uSeed * 1.7, uTime * 0.18));
  float warp = (n - 0.5) * 0.24;
  d += warp * smoothstep(0.12, 1.2, d);

  float core = exp(-d * d * 3.8);
  float mid = exp(-d * 2.2);
  float halo = exp(-d * 1.1);
  float ringA = exp(-abs(d - 0.62) * 12.0);
  float ringB = exp(-abs(d - 0.92) * 9.0);

  float spin = 0.5 + 0.5 * sin(angle * (4.0 + uStyle * 0.8) + uTime * (2.6 + uStyle * 1.2) + uSeed * 4.0);
  float flow = 0.6 + 0.4 * sin((d * 8.0) - uTime * (4.0 + uStyle * 0.7) + n * 6.0 + uSeed * 2.5);
  float pulse = 0.84 + 0.16 * sin(uTime * (3.0 + uStyle * 0.9) + d * 7.0 + uSeed);

  float style0 = core * 1.55 + mid * 1.05 + halo * 0.92 * flow; // projectile
  float style1 = ringA * 1.55 + ringB * 0.98 + halo * 0.62; // impact
  float style2 = ringA * 1.10 + mid * 0.78 + halo * 0.88 * spin; // tower aura
  float style3 = core * 1.18 + ringA * 0.88 + halo * 0.82 * flow; // creep

  float shape = style0;
  if (uStyle > 0.5) shape = style1;
  if (uStyle > 1.5) shape = style2;
  if (uStyle > 2.5) shape = style3;

  float hueBase = 0.56 + 0.15 * uStyle + 0.10 * uState;
  float hueShift = 0.14 * sin(uTime * 0.72 + angle * 2.2 + d * 10.0 + uSeed * 2.8);
  float huePulse = 0.06 * sin(uTime * 1.9 + d * 15.0 + uSeed * 3.6);
  float sat = mix(0.88, 1.00, smoothstep(0.0, 1.0, uStyle / 3.0));
  vec3 coreColor = hsv2rgb(vec3(fract(hueBase + hueShift + huePulse), sat, 1.22));
  vec3 edgeColor = hsv2rgb(vec3(fract(hueBase + 0.31 - hueShift * 0.62), sat, 1.08));
  vec3 bloomColor = hsv2rgb(vec3(fract(hueBase - 0.24 + hueShift * 0.72), sat, 1.18));

  float edgeMix = smoothstep(0.28, 1.25, d);
  vec3 color = mix(coreColor, edgeColor, edgeMix);
  color += bloomColor * (halo * 0.42 + ringB * 0.25);

  float strength = shape * pulse * (0.90 + 0.28 * spin) * uIntensity;
  float emissiveFloor = (0.12 + 0.22 * core + 0.12 * ringB) * uIntensity;
  vec3 rgb = color * strength + bloomColor * emissiveFloor;
  float alpha = clamp((core * 1.05 + halo * 0.72 + ringA * 0.44) * uIntensity, 0.0, 1.0);
  fragColor = vec4(rgb, alpha);
}
