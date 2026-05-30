// 01_pink_plasma.metal
// -----------------------------------------------------------------------------
// Soft pink sine-wave plasma for a desktop wallpaper background.
// Keeps the classic branchless trig-field structure, but maps the energy into
// layered rose, magenta, and pearl tones instead of RGB cycling.
// -----------------------------------------------------------------------------

#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float  time;
    float2 resolution;
    float2 mouse;
    uint   frame;
    uint   theme;
};

fragment float4 fs_main(float4 pos [[position]],
                        constant Uniforms& u [[buffer(0)]]) {
    float2 uv = pos.xy / u.resolution;
    float2 p = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float t = u.time * 0.24;

    float v = 0.0;
    v += sin((p.x * 1.55 + t * 1.20) * 4.4);
    v += sin((p.y * 1.35 - t * 0.95) * 5.2);
    v += sin((p.x + p.y + t * 0.72) * 4.8);
    v += sin(sqrt(dot(p, p) + 0.18) * 8.5 - t * 1.75);
    v += 0.55 * sin((p.x - p.y) * 7.0 + t * 1.35);
    v *= 0.22;

    float glow = 0.5 + 0.5 * sin(v * 3.14159265);
    float ribbon = 0.5 + 0.5 * sin(v * 6.28318530 + uv.x * 2.4 - uv.y * 1.8);
    float bloom = smoothstep(0.36, 1.0, glow);

    float3 deepRose = float3(0.18, 0.015, 0.105);
    float3 velvet   = float3(0.46, 0.035, 0.245);
    float3 fuchsia  = float3(0.95, 0.135, 0.560);
    float3 blush    = float3(1.00, 0.530, 0.760);
    float3 pearl    = float3(1.00, 0.875, 0.940);

    if (u.theme == 1) {
        deepRose = float3(0.145, 0.050, 0.100);
        velvet   = float3(0.480, 0.170, 0.260);
        fuchsia  = float3(1.000, 0.375, 0.585);
        blush    = float3(1.000, 0.685, 0.790);
        pearl    = float3(1.000, 0.930, 0.965);
    } else if (u.theme == 2) {
        deepRose = float3(0.115, 0.025, 0.150);
        velvet   = float3(0.390, 0.075, 0.420);
        fuchsia  = float3(1.000, 0.250, 0.820);
        blush    = float3(1.000, 0.620, 0.920);
        pearl    = float3(0.960, 0.880, 1.000);
    } else if (u.theme == 3) {
        deepRose = float3(0.060, 0.000, 0.075);
        velvet   = float3(0.290, 0.000, 0.260);
        fuchsia  = float3(1.000, 0.030, 0.620);
        blush    = float3(1.000, 0.300, 0.710);
        pearl    = float3(1.000, 0.760, 0.920);
    } else if (u.theme == 4) {
        deepRose = float3(0.035, 0.020, 0.070);
        velvet   = float3(0.190, 0.055, 0.170);
        fuchsia  = float3(0.650, 0.110, 0.390);
        blush    = float3(0.940, 0.455, 0.680);
        pearl    = float3(1.000, 0.800, 0.900);
    } else if (u.theme == 5) {
        deepRose = float3(0.030, 0.032, 0.040);
        velvet   = float3(0.185, 0.195, 0.215);
        fuchsia  = float3(0.610, 0.635, 0.680);
        blush    = float3(0.870, 0.885, 0.925);
        pearl    = float3(1.000, 0.965, 0.985);
    }

    float3 col = mix(deepRose, velvet, glow);
    col = mix(col, fuchsia, ribbon * 0.58);
    col = mix(col, blush, bloom * 0.45);
    col += pearl * pow(bloom, 3.0) * 0.28;

    float vignette = 1.0 - smoothstep(0.18, 1.28, length(p));
    col *= 0.70 + 0.30 * vignette;

    return float4(saturate(col), 1.0);
}
