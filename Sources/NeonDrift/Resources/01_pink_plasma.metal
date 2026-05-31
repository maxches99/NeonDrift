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
    uint theme;
    uint family;
    uint variant;
    uint palettePreset;
    float intensity;
    float contrast;
    float noiseAmount;
    float zoom;
};

constant uint THEME_FAMILY_PLASMA = 0;
constant uint THEME_FAMILY_FRACTALS = 1;
constant uint THEME_FAMILY_PATTERNS = 2;
constant uint THEME_FAMILY_ATMOSPHERE = 3;

constant uint THEME_VELVET_ROSE = 0;
constant uint THEME_SAKURA = 1;
constant uint THEME_BUBBLEGUM = 2;
constant uint THEME_NEON_ROSE = 3;
constant uint THEME_MIDNIGHT_BLUSH = 4;
constant uint THEME_SILVER = 5;
constant uint THEME_MANDELBROT = 6;
constant uint THEME_JULIA_BLOOM = 7;
constant uint THEME_NEWTON_PETALS = 8;
constant uint THEME_POLAR_LISSAJOUS = 9;
constant uint THEME_MOIRE_DREAM = 10;
constant uint THEME_KALEIDO_WAVE = 11;
constant uint THEME_DOMAIN_COLORING = 12;
constant uint THEME_APOLLONIAN_TILES = 13;
constant uint THEME_GLASS_CURRENT = 14;
constant uint THEME_SYNTHWAVE_RUN = 15;
constant uint THEME_MONO_MIST = 16;
constant uint THEME_MINIMAL_ARC = 17;
constant uint THEME_AMBIENT_HAZE = 18;
constant uint THEME_FOLD_DRIFT = 19;

constant uint PALETTE_ROSE = 0;
constant uint PALETTE_GLASS = 1;
constant uint PALETTE_SYNTHWAVE = 2;
constant uint PALETTE_MONOCHROME = 3;
constant uint PALETTE_MINIMAL = 4;
constant uint PALETTE_AMBIENT = 5;

vertex VertexOut vs_main(uint vertexID [[vertex_id]]) {
    float2 vertices[3] = {
        float2(-1.0, -1.0),
        float2( 3.0, -1.0),
        float2(-1.0,  3.0)
    };

    VertexOut out;
    out.position = float4(vertices[vertexID], 0.0, 1.0);
    return out;
}

float3 palette(float t, float3 a, float3 b, float3 c, float3 d) {
    return a + b * cos(6.28318530 * (c * t + d));
}

float2 cmul(float2 a, float2 b) {
    return float2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

float2 cdiv(float2 a, float2 b) {
    float denom = max(dot(b, b), 1e-5);
    return float2(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / denom;
}

float2 cpow3(float2 z) {
    return cmul(cmul(z, z), z);
}

float2 rotate2D(float2 p, float angle) {
    float s = sin(angle);
    float c = cos(angle);
    return float2(c * p.x - s * p.y, s * p.x + c * p.y);
}

float hash21(float2 p) {
    p = fract(p * float2(123.34, 456.21));
    p += dot(p, p + 45.32);
    return fract(p.x * p.y);
}

float noise2D(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);

    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));

    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float4 transformedPos(float4 pos, constant Uniforms& u, float zoom) {
    float2 center = u.resolution * 0.5;
    float safeZoom = max(zoom, 0.2);
    float2 scaled = (pos.xy - center) / safeZoom + center;
    return float4(scaled, pos.z, pos.w);
}

float3 applyPalettePreset(float3 col, float luminance, uint palettePreset) {
    switch (palettePreset) {
        case PALETTE_GLASS: {
            float3 tint = mix(float3(0.78, 0.90, 1.0), float3(0.55, 0.82, 0.96), luminance);
            return mix(col, tint, 0.26);
        }
        case PALETTE_SYNTHWAVE: {
            float3 tint = mix(float3(0.08, 0.10, 0.28), float3(1.0, 0.32, 0.62), luminance);
            return mix(col, tint, 0.32);
        }
        case PALETTE_MONOCHROME: {
            float gray = dot(col, float3(0.299, 0.587, 0.114));
            return mix(float3(gray), float3(gray * 1.08), 0.55 + 0.45 * luminance);
        }
        case PALETTE_MINIMAL: {
            float3 tint = mix(float3(0.18, 0.20, 0.23), float3(0.90, 0.92, 0.95), luminance);
            return mix(col, tint, 0.38);
        }
        case PALETTE_AMBIENT: {
            float3 tint = mix(float3(0.18, 0.14, 0.22), float3(0.62, 0.70, 0.82), luminance);
            return mix(col, tint, 0.20);
        }
        case PALETTE_ROSE:
        default: {
            float3 tint = mix(float3(0.28, 0.06, 0.20), float3(1.0, 0.72, 0.88), luminance);
            return mix(col, tint, 0.18);
        }
    }
}

float3 stylize(float3 col, float2 uv, constant Uniforms& u, StyleParams style) {
    float luminance = dot(col, float3(0.299, 0.587, 0.114));
    col = applyPalettePreset(col, luminance, style.palettePreset);
    col = pow(max(col, 0.0), float3(max(style.intensity, 0.01)));
    col = (col - 0.5) * style.contrast + 0.5;

    float grain = noise2D(uv * u.resolution * 0.22 + float2(u.time * 13.0, float(u.frame) * 0.031));
    col += (grain - 0.5) * style.noiseAmount;
    return saturate(col);
}

float4 classicPlasma(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = pos.xy / u.resolution;
    float2 p = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float t = u.familyTime * 0.24 + u.accentPhase * 0.1;

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

    if (style.theme == THEME_SAKURA) {
        deepRose = float3(0.145, 0.050, 0.100);
        velvet   = float3(0.480, 0.170, 0.260);
        fuchsia  = float3(1.000, 0.375, 0.585);
        blush    = float3(1.000, 0.685, 0.790);
        pearl    = float3(1.000, 0.930, 0.965);
    } else if (style.theme == THEME_BUBBLEGUM) {
        deepRose = float3(0.115, 0.025, 0.150);
        velvet   = float3(0.390, 0.075, 0.420);
        fuchsia  = float3(1.000, 0.250, 0.820);
        blush    = float3(1.000, 0.620, 0.920);
        pearl    = float3(0.960, 0.880, 1.000);
    } else if (style.theme == THEME_NEON_ROSE) {
        deepRose = float3(0.060, 0.000, 0.075);
        velvet   = float3(0.290, 0.000, 0.260);
        fuchsia  = float3(1.000, 0.030, 0.620);
        blush    = float3(1.000, 0.300, 0.710);
        pearl    = float3(1.000, 0.760, 0.920);
    } else if (style.theme == THEME_MIDNIGHT_BLUSH) {
        deepRose = float3(0.035, 0.020, 0.070);
        velvet   = float3(0.190, 0.055, 0.170);
        fuchsia  = float3(0.650, 0.110, 0.390);
        blush    = float3(0.940, 0.455, 0.680);
        pearl    = float3(1.000, 0.800, 0.900);
    } else if (style.theme == THEME_SILVER) {
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

float4 mandelbrot(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 p = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float epoch = float(u.mandelbrotEpoch);
    float angle = 0.035 * sin(u.familyTime * 0.071 + epoch * 1.7 + u.accentPhase * 0.12);
    float zoom = u.mandelbrotZoom;
    float2 center = u.mandelbrotCenter;

    float s = sin(angle);
    float c = cos(angle);
    float2 z0 = float2(c * p.x - s * p.y, s * p.x + c * p.y) * zoom + center;
    float2 z = float2(0.0);

    const int maxIter = 128;
    float iter = 0.0;
    for (int i = 0; i < maxIter; ++i) {
        z = float2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + z0;
        if (dot(z, z) > 16.0) {
            float logRadius = log(dot(z, z)) * 0.5;
            float smoothIter = float(i) + 1.0 - log2(max(logRadius, 0.0001));
            iter = smoothIter / float(maxIter);
            break;
        }
    }

    float escaped = step(0.0001, iter);
    float band = 0.5 + 0.5 * sin(iter * 72.0 - u.familyTime * 0.85 + u.accentPhase);
    float halo = pow(smoothstep(0.0, 0.58, iter), 0.85);
    float3 col = palette(
        iter * 1.65 + u.familyTime * 0.018 + u.accentPhase * 0.04,
        float3(0.42, 0.36, 0.40),
        float3(0.47, 0.36, 0.34),
        float3(0.92, 0.74, 0.58),
        float3(0.01, 0.18, 0.34)
    );

    float3 interior = float3(0.018, 0.015, 0.028);
    float3 edgeGlow = float3(1.0, 0.62, 0.82) * pow(band, 5.0) * halo;
    col = mix(interior, col, escaped);
    col += edgeGlow * escaped;
    col += float3(0.55, 0.24, 0.38) * exp(-zoom * 1.4) * 0.08 * escaped;
    return float4(saturate(col), 1.0);
}

float4 juliaBloom(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 p = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float2 c = float2(
        -0.78 + 0.12 * sin(u.familyTime * 0.19 + u.accentPhase * 0.4),
         0.16 + 0.08 * cos(u.familyTime * 0.23 + float(style.variant) * 0.3)
    );

    float angle = u.familyTime * 0.08 + u.accentPhase * 0.1;
    float s = sin(angle);
    float cRot = cos(angle);
    float2 z = float2(cRot * p.x - s * p.y, s * p.x + cRot * p.y) * 1.45;

    const int maxIter = 96;
    float iter = 0.0;
    float trap = 10.0;
    for (int i = 0; i < maxIter; ++i) {
        z = cmul(z, z) + c;
        trap = min(trap, abs(z.x * z.y));
        float radius2 = dot(z, z);
        if (radius2 > 24.0) {
            float smoothIter = float(i) + 1.0 - log2(max(log2(radius2), 0.0001));
            iter = smoothIter / float(maxIter);
            break;
        }
    }

    float escaped = step(0.0001, iter);
    float petals = 0.5 + 0.5 * sin(atan2(p.y, p.x) * 8.0 + u.familyTime * 0.7 + iter * 22.0 + u.accentPhase);
    float orbitGlow = exp(-22.0 * trap);
    float3 col = palette(
        iter * 1.2 + petals * 0.35 + u.familyTime * 0.04 + u.accentPhase * 0.08,
        float3(0.30, 0.18, 0.32),
        float3(0.60, 0.42, 0.34),
        float3(0.80, 0.75, 0.55),
        float3(0.85, 0.10, 0.22)
    );

    col = mix(float3(0.018, 0.016, 0.030), col, escaped);
    col += float3(1.0, 0.58, 0.82) * pow(petals, 4.0) * 0.26;
    col += float3(0.72, 0.94, 1.0) * orbitGlow * 0.85;
    return float4(saturate(col), 1.0);
}

float4 newtonPetals(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 p = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float2 z = p * 1.9;

    const int maxIter = 28;
    float accum = 0.0;
    for (int i = 0; i < maxIter; ++i) {
        float2 z2 = cmul(z, z);
        float2 z3 = cmul(z2, z);
        float2 f = z3 - float2(1.0, 0.0);
        float2 df = 3.0 * z2;
        z -= cdiv(f, df);
        accum += exp(-3.5 * length(f));
    }

    float2 roots[3] = {
        float2(1.0, 0.0),
        float2(-0.5, 0.8660254),
        float2(-0.5, -0.8660254)
    };

    float d0 = length(z - roots[0]);
    float d1 = length(z - roots[1]);
    float d2 = length(z - roots[2]);

    float3 rootColor = float3(0.95, 0.48, 0.70);
    if (d1 < d0 && d1 < d2) {
        rootColor = float3(0.46, 0.92, 0.96);
    } else if (d2 < d0 && d2 < d1) {
        rootColor = float3(0.98, 0.82, 0.46);
    }

    float basin = exp(-6.0 * min(d0, min(d1, d2)));
    float rings = 0.5 + 0.5 * sin(accum * 2.4 + length(p) * 12.0 - u.familyTime * 1.3 + u.accentPhase);
    float shimmer = pow(rings, 6.0) * (0.35 + basin);
    float3 base = mix(float3(0.020, 0.018, 0.030), rootColor * 0.68, saturate(accum / 7.5));
    float3 col = base + rootColor * shimmer;
    col += float3(1.0, 0.95, 0.98) * pow(basin, 2.0) * 0.18;
    return float4(saturate(col), 1.0);
}

float4 polarLissajous(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = pos.xy / u.resolution;
    float2 p = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float r = length(p);
    float a = atan2(p.y, p.x);
    float t = u.familyTime * 0.55 + u.accentPhase * 0.18;

    float rose = sin(a * 7.0 + sin(t * 0.7) * 1.6) * cos(r * 16.0 - t * 2.4);
    float liss = sin((p.x * 4.0 + t * 1.3) * (2.1 + 0.4 * sin(t * 0.3)))
               + cos((p.y * 3.0 - t * 1.1) * (3.4 + 0.3 * cos(t * 0.23)));
    float mesh = sin((r + 0.18 * liss) * 34.0 - t * 3.6);
    float glow = smoothstep(0.55, 0.98, 0.5 + 0.5 * mesh);

    float3 col = palette(
        rose * 0.18 + liss * 0.08 + uv.x * 0.22 - uv.y * 0.15 + t * 0.04,
        float3(0.26, 0.24, 0.30),
        float3(0.52, 0.34, 0.42),
        float3(1.00, 0.82, 0.64),
        float3(0.76, 0.14, 0.22)
    );

    col += float3(1.0, 0.70, 0.88) * glow * (0.35 + 0.65 * smoothstep(0.0, 1.0, rose * 0.5 + 0.5));
    col += float3(0.55, 0.90, 1.0) * pow(max(0.0, 1.0 - abs(liss) * 0.35), 4.0) * 0.16;
    return float4(saturate(col), 1.0);
}

float4 moireDream(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = pos.xy / u.resolution;
    float2 p = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float t = u.familyTime * 0.42 + u.accentPhase * 0.12;

    float2 q1 = p + float2(0.18 * sin(t), 0.16 * cos(t * 1.2));
    float2 q2 = p + float2(0.22 * cos(t * 0.9), -0.14 * sin(t * 1.1));

    float ringA = sin(length(q1) * 42.0 - t * 3.2);
    float ringB = sin(length(q2 * float2(1.12, 0.88)) * 40.0 + t * 2.7);
    float spokes = sin(atan2(p.y, p.x) * 18.0 + t * 1.8);
    float field = ringA + ringB + 0.55 * spokes;
    float bands = 0.5 + 0.5 * sin(field * 2.2 + uv.x * 5.0 - uv.y * 3.0);
    float highlight = pow(bands, 7.0);

    float3 col = palette(
        bands * 0.9 + t * 0.03,
        float3(0.20, 0.21, 0.26),
        float3(0.48, 0.39, 0.34),
        float3(0.90, 0.78, 0.72),
        float3(0.02, 0.18, 0.30)
    );

    col += float3(1.0, 0.52, 0.76) * highlight * 0.46;
    col += float3(0.48, 0.88, 1.0) * pow(max(0.0, ringA * ringB), 2.0) * 0.18;
    return float4(saturate(col), 1.0);
}

float4 kaleidoWave(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 p = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float t = u.familyTime * 0.44 + u.accentPhase * 0.15;

    float segments = 6.0 + floor(1.5 + 1.5 * sin(u.familyTime * 0.1 + float(style.variant) * 0.7));
    float angle = atan2(p.y, p.x);
    float radius = length(p);
    float sector = 6.28318530 / segments;
    angle = abs(fmod(angle + sector * 0.5, sector) - sector * 0.5);

    float2 k = float2(cos(angle), sin(angle)) * radius;
    k = rotate2D(k, t * 0.3);

    float wave = sin(k.x * 16.0 + t * 2.4) + cos(k.y * 18.0 - t * 2.1);
    float fold = sin((k.x + k.y) * 22.0 - t * 3.0);
    float spark = smoothstep(0.78, 0.99, 0.5 + 0.5 * sin(wave * fold * 2.6));

    float3 col = palette(
        angle / sector + wave * 0.08 + radius * 0.16 + t * 0.04,
        float3(0.24, 0.18, 0.30),
        float3(0.58, 0.40, 0.36),
        float3(1.00, 0.82, 0.58),
        float3(0.78, 0.06, 0.30)
    );

    col += float3(1.0, 0.62, 0.84) * spark * 0.45;
    col += float3(0.42, 0.90, 1.0) * pow(max(0.0, 1.0 - abs(fold)), 5.0) * 0.16;
    return float4(saturate(col), 1.0);
}

float4 domainColoring(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 p = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float t = u.familyTime * 0.22 + u.accentPhase * 0.08;
    float2 z = rotate2D(p * 1.25, t * 0.35);
    float2 w = cpow3(z) - float2(1.0, 0.0);
    w = cdiv(w, z * z + float2(0.22, -0.08));

    float phase = atan2(w.y, w.x);
    float magnitude = length(w);
    float hueDriver = phase / 6.28318530 + 0.5;
    float logMag = log2(max(magnitude, 1e-4));
    float contour = 0.5 + 0.5 * cos(logMag * 8.0);
    float grid = 0.5 + 0.5 * cos(phase * 10.0);

    float3 col = palette(
        hueDriver + t * 0.03,
        float3(0.36, 0.34, 0.38),
        float3(0.52, 0.40, 0.36),
        float3(1.0, 1.0, 1.0),
        float3(0.02, 0.16, 0.32)
    );

    col *= 0.55 + 0.45 * contour;
    col += float3(1.0, 0.70, 0.86) * pow(grid, 8.0) * 0.24;
    col += float3(0.62, 0.92, 1.0) * exp(-5.0 * abs(logMag)) * 0.18;
    return float4(saturate(col), 1.0);
}

float4 apollonianTiles(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 p = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float t = u.familyTime * 0.28 + u.accentPhase * 0.10;
    float2 z = rotate2D(p * 1.05, t * 0.12);
    float orbit = 0.0;
    float minBubble = 10.0;
    float cellGlow = 0.0;
    float macroBubble = 10.0;

    for (int i = 0; i < 6; ++i) {
        z = abs(z);
        if (z.x < z.y) {
            float tmp = z.x;
            z.x = z.y;
            z.y = tmp;
        }

        z = z * 1.38 - float2(0.92, 0.18);
        z = rotate2D(z, 0.16 * sin(t + float(i) * 0.7));

        float radius2 = clamp(dot(z, z), 0.05, 12.0);
        float invScale = clamp(0.84 / radius2, 0.22, 1.65);
        z *= invScale;

        float bubble = abs(length(z - float2(0.62, 0.0)) - 0.32);
        minBubble = min(minBubble, bubble);
        orbit += exp(-14.0 * bubble);
        cellGlow += exp(-7.0 * length(z - float2(0.62, 0.0)));
        if (i < 3) {
            macroBubble = min(macroBubble, bubble);
        }
    }

    float r = length(z);
    float bubbleMask = exp(-26.0 * minBubble);
    float macroMask = exp(-18.0 * macroBubble);
    float softRings = 0.5 + 0.5 * sin(7.0 * r - orbit * 0.8 - t * 1.1);
    float spokes = 0.5 + 0.5 * cos(atan2(z.y, z.x) * 4.0 + orbit * 0.45);
    float web = smoothstep(0.70, 0.94, 0.52 * softRings + 0.48 * spokes + macroMask * 0.45);
    float mist = smoothstep(0.12, 1.1, orbit * 0.12 + cellGlow * 0.10);

    float3 col = palette(
        macroMask * 0.18 + r * 0.09 + t * 0.015,
        float3(0.14, 0.08, 0.08),
        float3(0.28, 0.16, 0.14),
        float3(0.82, 0.72, 0.62),
        float3(0.78, 0.11, 0.24)
    );

    col = mix(col * 0.42, col, 0.12 + 0.88 * mist * macroMask);
    col += float3(1.0, 0.62, 0.80) * web * macroMask * 0.22;
    col += float3(0.62, 0.94, 1.0) * pow(macroMask, 1.8) * 0.16;
    col += float3(1.0, 0.90, 0.84) * smoothstep(0.80, 0.98, macroMask) * 0.14;
    return float4(saturate(col), 1.0);
}

// ─── Fold Drift ─────────────────────────────────────────────────────────────
// Based on "RayMarching starting point" by Martijn Steinrucken (The Art of Code)
// Source: https://www.shadertoy.com/view/7sscW4 — MIT License

#define FOLD_MAX_STEPS 48
#define FOLD_MAX_DIST  8.0
#define FOLD_SURF_DIST 0.003

float2x2 foldRot2(float a) {
    float s = sin(a), c = cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

float foldSDF(float3 p, float t) {
    float2 uv = p.xz;
    uv.x = abs(uv.x);
    float tf = 12.0 + t;
    float2 q = float2(1, 0);
    float th = 0.4 * p.y - 0.6 * tf;
    float m = 1.8;
    for (float i = 0.0; i < 6.0; i++) {
        uv -= m * q;
        th += 0.5 * p.y + 0.05 * tf;
        uv = foldRot2(th) * uv;
        uv.x = abs(uv.x);
        m *= 0.05 * cos(8.0 * length(uv)) + 0.55;
    }
    return 0.5 * (length(uv) - 2.0 * m);
}

float foldRM(float3 ro, float3 rd, float t) {
    float dO = 0.0;
    for (int i = 0; i < FOLD_MAX_STEPS; i++) {
        float dS = foldSDF(ro + rd * dO, t);
        dO += dS;
        if (dO > FOLD_MAX_DIST || abs(dS) < FOLD_SURF_DIST) break;
    }
    return dO;
}

float3 foldNormal(float3 p, float t) {
    float d = foldSDF(p, t);
    float2 e = float2(0.001, 0);
    return normalize(d - float3(foldSDF(p - e.xyy, t), foldSDF(p - e.yxy, t), foldSDF(p - e.yyx, t)));
}

float3 foldRayDir(float2 uv, float3 ro, float3 la, float fl) {
    float3 f = normalize(la - ro);
    float3 r = normalize(cross(float3(0, 1, 0), f));
    return normalize(fl * f + uv.x * r + uv.y * cross(f, r));
}

float3 foldEnv(float3 dir, float t) {
    float3 d = normalize(dir);
    float u = atan2(d.z, d.x) * 0.15915 + 0.5;
    float v = d.y * 0.5 + 0.5;
    float ripple = 0.5 + 0.5 * sin(u * 14.0 + t * 0.18) * cos(v * 9.0 - t * 0.24);
    return mix(float3(0.01, 0.005, 0.04), float3(0.08, 0.03, 0.14), v) + float3(0.12, 0.05, 0.20) * ripple;
}

float4 foldDrift(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float t = u.familyTime;
    float ang = t * 0.05 + u.accentPhase * 0.08;
    float3 ro = float3(5.5 * cos(ang), 0.5 * sin(t * 0.13), 5.5 * sin(ang));
    float3 rd = foldRayDir(uv, ro, float3(0, 0, 0), 2.0);
    float3 col = float3(0);
    float d = foldRM(ro, rd, t);
    if (d < FOLD_MAX_DIST) {
        float3 p = ro + rd * d;
        float3 n = foldNormal(p, t);
        float3 r = reflect(rd, n);
        float dif = max(dot(n, normalize(float3(1, 2, 3))), 0.0);
        col = float3(dif * 0.4 + 0.3) * foldEnv(r, t) * (1.0 + r.y);
        col = clamp(col, 0.0, 1.0);
        float3 e = float3(1.0);
        col *= palette(r.y, e, e, e, 0.35 * float3(0.0, 0.33, 0.66));
    }
    return float4(pow(saturate(col), float3(0.4545)), 1.0);
}

float4 glassCurrent(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = pos.xy / u.resolution;
    float2 p = (uv - 0.5) * float2(u.resolution.x / max(u.resolution.y, 1.0), 1.0);
    float t = u.familyTime * 0.18 + u.accentPhase * 0.05;

    float wave = sin(p.x * 8.0 + t * 2.0) + cos(p.y * 10.0 - t * 1.6);
    float caustic = sin((p.x + p.y) * 18.0 + wave * 2.0 - t * 1.8);
    float frost = noise2D(uv * 8.0 + float2(t * 0.4, -t * 0.3));
    float sheen = smoothstep(0.55, 1.0, 0.5 + 0.5 * caustic);

    float3 base = mix(float3(0.10, 0.18, 0.24), float3(0.78, 0.92, 0.98), frost * 0.9);
    base += float3(0.85, 0.95, 1.0) * sheen * 0.35;
    base += float3(0.58, 0.82, 0.92) * pow(max(0.0, 1.0 - abs(wave) * 0.25), 4.0) * 0.22;
    return float4(saturate(base), 1.0);
}

float4 synthwaveRun(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = pos.xy / u.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = u.familyTime * 0.32 + u.accentPhase * 0.1;

    float horizon = smoothstep(-0.02, 0.02, p.y + 0.18);
    float sun = smoothstep(0.42, 0.0, distance(p, float2(0.0, 0.28)));
    float grid = abs(fract((p.x * 8.0) + 0.5) - 0.5);
    float lanes = smoothstep(0.46, 0.50, grid) * smoothstep(-0.92, 0.05, -p.y);
    float travel = sin((p.y + 1.1) * 18.0 - t * 8.0);
    float mountain = smoothstep(0.0, 0.12, sin(p.x * 5.0 + t) * 0.10 + 0.06 - abs(p.y + 0.06));

    float3 sky = mix(float3(0.03, 0.03, 0.16), float3(0.84, 0.24, 0.52), uv.y);
    sky += float3(0.95, 0.52, 0.22) * sun * 0.9;
    sky += float3(0.92, 0.16, 0.60) * lanes * (0.35 + 0.65 * smoothstep(0.0, 1.0, travel * 0.5 + 0.5));
    sky = mix(sky, float3(0.04, 0.06, 0.12), 1.0 - horizon);
    sky += float3(0.20, 0.65, 1.0) * mountain * 0.42;
    return float4(saturate(sky), 1.0);
}

float4 monoMist(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = pos.xy / u.resolution;
    float2 p = (uv - 0.5) * 2.0;
    float t = u.familyTime * 0.12;

    float mistA = noise2D(uv * 3.0 + float2(t, -t * 0.7));
    float mistB = noise2D(uv * 6.0 - float2(t * 0.5, t * 0.3));
    float fog = smoothstep(0.22, 0.82, mistA * 0.6 + mistB * 0.4);
    float vignette = 1.0 - smoothstep(0.2, 1.2, length(p));
    float gray = mix(0.14, 0.84, fog) * (0.78 + 0.22 * vignette);
    return float4(float3(gray), 1.0);
}

float4 minimalArc(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 p = (pos.xy * 2.0 - u.resolution) / min(u.resolution.x, u.resolution.y);
    float t = u.familyTime * 0.18;
    float radius = length(p);
    float arc1 = smoothstep(0.014, 0.0, abs(radius - (0.38 + 0.05 * sin(t))));
    float arc2 = smoothstep(0.014, 0.0, abs(radius - (0.74 + 0.04 * cos(t * 1.2))));
    float line = smoothstep(0.012, 0.0, abs(p.y + 0.18 * sin(t * 0.8)));
    float pulse = 0.5 + 0.5 * sin(atan2(p.y, p.x) * 5.0 - t * 2.0);

    float3 base = mix(float3(0.94, 0.95, 0.97), float3(0.80, 0.84, 0.90), radius);
    base -= float3(0.18, 0.22, 0.28) * arc1 * (0.4 + 0.6 * pulse);
    base -= float3(0.10, 0.14, 0.18) * arc2 * 0.65;
    base -= float3(0.16, 0.18, 0.20) * line * 0.38;
    return float4(saturate(base), 1.0);
}

float4 ambientHaze(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = pos.xy / u.resolution;
    float2 p = uv * 2.0 - 1.0;
    float t = u.familyTime * 0.09;

    float haze = noise2D(uv * 2.2 + float2(t * 0.4, -t * 0.3));
    haze += 0.6 * noise2D(uv * 4.6 - float2(t * 0.2, t * 0.15));
    haze /= 1.6;
    float drift = 0.5 + 0.5 * sin(p.x * 2.2 + p.y * 1.8 + t * 2.0);
    float glow = exp(-2.5 * dot(p - float2(0.15, -0.08), p - float2(0.15, -0.08)));

    float3 col = mix(float3(0.11, 0.10, 0.15), float3(0.42, 0.46, 0.58), haze);
    col = mix(col, float3(0.74, 0.62, 0.68), drift * 0.18);
    col += float3(0.92, 0.84, 0.88) * glow * 0.22;
    return float4(saturate(col), 1.0);
}

float4 renderTheme(float4 pos, constant Uniforms& u, StyleParams style) {
    float4 adjustedPos = transformedPos(pos, u, style.zoom);

    switch (style.family) {
        case THEME_FAMILY_PLASMA:
            return classicPlasma(adjustedPos, u, style);
        case THEME_FAMILY_FRACTALS:
            switch (style.theme) {
                case THEME_MANDELBROT: return mandelbrot(adjustedPos, u, style);
                case THEME_JULIA_BLOOM: return juliaBloom(adjustedPos, u, style);
                case THEME_NEWTON_PETALS: return newtonPetals(adjustedPos, u, style);
                case THEME_FOLD_DRIFT: return foldDrift(pos, u, style);
                default: return classicPlasma(adjustedPos, u, style);
            }
        case THEME_FAMILY_PATTERNS:
            switch (style.theme) {
                case THEME_POLAR_LISSAJOUS: return polarLissajous(adjustedPos, u, style);
                case THEME_MOIRE_DREAM: return moireDream(adjustedPos, u, style);
                case THEME_KALEIDO_WAVE: return kaleidoWave(adjustedPos, u, style);
                case THEME_DOMAIN_COLORING: return domainColoring(adjustedPos, u, style);
                case THEME_APOLLONIAN_TILES: return apollonianTiles(adjustedPos, u, style);
                default: return classicPlasma(adjustedPos, u, style);
            }
        case THEME_FAMILY_ATMOSPHERE:
            switch (style.theme) {
                case THEME_GLASS_CURRENT: return glassCurrent(adjustedPos, u, style);
                case THEME_SYNTHWAVE_RUN: return synthwaveRun(adjustedPos, u, style);
                case THEME_MONO_MIST: return monoMist(adjustedPos, u, style);
                case THEME_MINIMAL_ARC: return minimalArc(adjustedPos, u, style);
                case THEME_AMBIENT_HAZE: return ambientHaze(adjustedPos, u, style);
                default: return ambientHaze(adjustedPos, u, style);
            }
        default:
            return classicPlasma(adjustedPos, u, style);
    }
}

fragment float4 fs_main(float4 pos [[position]],
                        constant Uniforms& u [[buffer(0)]]) {
    StyleParams currentStyle = {
        u.theme,
        u.themeFamily,
        u.themeVariant,
        u.palettePreset,
        u.intensity,
        u.contrast,
        u.noiseAmount,
        u.zoom
    };

    StyleParams previousStyle = {
        u.previousTheme,
        u.previousThemeFamily,
        u.previousThemeVariant,
        u.previousPalettePreset,
        u.previousIntensity,
        u.previousContrast,
        u.previousNoiseAmount,
        u.previousZoom
    };

    float2 uv = pos.xy / u.resolution;
    if (u.transitionProgress >= 1.0) {
        return float4(stylize(renderTheme(pos, u, currentStyle).rgb, uv, u, currentStyle), 1.0);
    }
    float3 currentColor = stylize(renderTheme(pos, u, currentStyle).rgb, uv, u, currentStyle);
    float3 previousColor = stylize(renderTheme(pos, u, previousStyle).rgb, uv, u, previousStyle);
    float blend = smoothstep(0.0, 1.0, u.transitionProgress);
    return float4(mix(previousColor, currentColor, blend), 1.0);
}
