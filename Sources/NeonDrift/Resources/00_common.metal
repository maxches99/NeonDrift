#include <metal_stdlib>
using namespace metal;

struct Uniforms {
    float  time;
    float2 resolution;
    uint   frame;
    uint   theme;
    uint   themeFamily;
    uint   themeVariant;
    uint   previousTheme;
    uint   previousThemeFamily;
    uint   previousThemeVariant;
    float  transitionProgress;
    float2 mandelbrotCenter;
    float  mandelbrotZoom;
    uint   mandelbrotEpoch;
    float  familyTime;
    float  accentPhase;
    uint   palettePreset;
    uint   previousPalettePreset;
    float  intensity;
    float  previousIntensity;
    float  contrast;
    float  previousContrast;
    float  noiseAmount;
    float  previousNoiseAmount;
    float  zoom;
    float  previousZoom;
};

struct VertexOut {
    float4 position [[position]];
};

struct StyleParams {
    uint  theme;
    uint  family;
    uint  variant;
    uint  palettePreset;
    float intensity;
    float contrast;
    float noiseAmount;
    float zoom;
};

constant uint THEME_FAMILY_PLASMA     = 0;
constant uint THEME_FAMILY_FRACTALS   = 1;
constant uint THEME_FAMILY_PATTERNS   = 2;
constant uint THEME_FAMILY_ATMOSPHERE = 3;

constant uint THEME_VELVET_ROSE      = 0;
constant uint THEME_SAKURA           = 1;
constant uint THEME_BUBBLEGUM        = 2;
constant uint THEME_NEON_ROSE        = 3;
constant uint THEME_MIDNIGHT_BLUSH   = 4;
constant uint THEME_SILVER           = 5;
constant uint THEME_MANDELBROT       = 6;
constant uint THEME_JULIA_BLOOM      = 7;
constant uint THEME_NEWTON_PETALS    = 8;
constant uint THEME_POLAR_LISSAJOUS  = 9;
constant uint THEME_MOIRE_DREAM      = 10;
constant uint THEME_KALEIDO_WAVE     = 11;
constant uint THEME_DOMAIN_COLORING  = 12;
constant uint THEME_APOLLONIAN_TILES = 13;
constant uint THEME_GLASS_CURRENT    = 14;
constant uint THEME_SYNTHWAVE_RUN    = 15;
constant uint THEME_MONO_MIST        = 16;
constant uint THEME_MINIMAL_ARC      = 17;
constant uint THEME_AMBIENT_HAZE     = 18;
constant uint THEME_FOLD_DRIFT       = 19;

constant uint PALETTE_ROSE       = 0;
constant uint PALETTE_GLASS      = 1;
constant uint PALETTE_SYNTHWAVE  = 2;
constant uint PALETTE_MONOCHROME = 3;
constant uint PALETTE_MINIMAL    = 4;
constant uint PALETTE_AMBIENT    = 5;

// ── Math helpers ─────────────────────────────────────────────────────────────

inline float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * fast::cos(6.28318530f * (c * t + d));
}

inline float2 cmul(float2 a, float2 b) {
    return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

inline float2 cdiv(float2 a, float2 b) {
    float denom = max(dot(b, b), 1e-5f);
    return float2(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / denom;
}

inline float2 rotate2D(float2 p, float angle) {
    float s = fast::sin(angle);
    float c = fast::cos(angle);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

inline float hash21(float2 p) {
    p = fract(p * float2(123.34f, 456.21f));
    p += dot(p, p + 45.32f);
    return fract(p.x * p.y);
}

inline float noise2D(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0f - 2.0f * f);
    float a = hash21(i);
    float b = hash21(i + float2(1.0f, 0.0f));
    float c = hash21(i + float2(0.0f, 1.0f));
    float d = hash21(i + float2(1.0f, 1.0f));
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}
