#include <flutter/runtime_effect.glsl>

// uniforms set from Dart, in order:
// 0: size.width
// 1: size.height
// 2: threshold   (how much greener-than-other-channels counts as background)
// 3: smoothing   (edge feather width)
uniform vec2 uSize;
uniform float uThreshold;
uniform float uSmoothing;
uniform sampler2D uTexture;

out vec4 fragColor;

void main() {
  vec2 uv = FlutterFragCoord().xy / uSize;
  vec4 color = texture(uTexture, uv);

  float maxChannel = max(color.r, max(color.g, color.b));
  float minChannel = min(color.r, min(color.g, color.b));
  float chroma = maxChannel - minChannel;
  float luma = dot(color.rgb, vec3(0.2126, 0.7152, 0.0722));

  // Remove the green/cyan/blue studio background behind the signer. Keeping
  // RGB untouched preserves the person's normal color.
  float greenKey = color.g - max(color.r, color.b);
  float cyanKey = min(color.g, color.b) - color.r;
  float blueKey = color.b - max(color.r, color.g);

  float greenDominance = max(greenKey, color.g - color.r);
    float keyThreshold = clamp(uThreshold, 0.05, 0.8);
    float keySmoothing = max(uSmoothing, 0.01);
    float greenScreen = smoothstep(
      keyThreshold - keySmoothing, keyThreshold + keySmoothing, greenDominance) *
      smoothstep(0.04, 0.16, chroma);
    float cyanScreen = smoothstep(
      keyThreshold - keySmoothing, keyThreshold + keySmoothing, cyanKey) *
      smoothstep(0.04, 0.17, chroma);
    float blueScreen = smoothstep(
      keyThreshold - keySmoothing, keyThreshold + keySmoothing, blueKey) *
      smoothstep(0.06, 0.18, chroma);
  float keyedBackground = max(max(greenScreen, cyanScreen), blueScreen);

  float alpha = 1.0 - keyedBackground;

  float topBottomBand = max(
    1.0 - smoothstep(0.00, 0.08, uv.y),
    smoothstep(0.92, 1.00, uv.y)
  );

  // Remove only black/white bars at the frame edge. This avoids deleting black
  // hair or clothing in the middle of the video.
  float blackBar = 1.0 - smoothstep(0.03, 0.12, luma);
  float whiteBar = smoothstep(0.86, 0.96, luma) * (1.0 - smoothstep(0.05, 0.14, chroma));
  alpha *= 1.0 - (max(blackBar, whiteBar) * topBottomBand);

  // Fade the sampled video's extreme top/bottom rows. This catches antialiased
  // frame-edge lines without changing the layout around the video.
  float verticalEdge = smoothstep(0.005, 0.035, uv.y) *
      smoothstep(0.005, 0.035, 1.0 - uv.y);
  alpha *= verticalEdge;

  fragColor = vec4(color.rgb * alpha, alpha * color.a);
}
