vertex VertexOut vs_main(uint vertexID [[vertex_id]]) {
    float2 vertices[3] = {
        float2(-1.0f, -1.0f),
        float2( 3.0f, -1.0f),
        float2(-1.0f,  3.0f)
    };
    VertexOut out;
    out.position = float4(vertices[vertexID], 0.0f, 1.0f);
    return out;
}

static float4 transformedPos(float4 pos, constant Uniforms& u, float zoom) {
    float2 center   = u.resolution * 0.5f;
    float  safeZoom = max(zoom, 0.2f);
    float2 scaled   = (pos.xy - center) / safeZoom + center;
    return float4(scaled, pos.z, pos.w);
}

static float3 applyPalettePreset(float3 col, float luminance, uint palettePreset) {
    switch (palettePreset) {
        case PALETTE_GLASS: {
            float3 tint = mix(float3(0.78f, 0.90f, 1.0f), float3(0.55f, 0.82f, 0.96f), luminance);
            return mix(col, tint, 0.26f);
        }
        case PALETTE_SYNTHWAVE: {
            float3 tint = mix(float3(0.08f, 0.10f, 0.28f), float3(1.0f, 0.32f, 0.62f), luminance);
            return mix(col, tint, 0.32f);
        }
        case PALETTE_MONOCHROME: {
            float gray = dot(col, float3(0.299f, 0.587f, 0.114f));
            return mix(float3(gray), float3(gray * 1.08f), 0.55f + 0.45f * luminance);
        }
        case PALETTE_MINIMAL: {
            float3 tint = mix(float3(0.18f, 0.20f, 0.23f), float3(0.90f, 0.92f, 0.95f), luminance);
            return mix(col, tint, 0.38f);
        }
        case PALETTE_AMBIENT: {
            float3 tint = mix(float3(0.18f, 0.14f, 0.22f), float3(0.62f, 0.70f, 0.82f), luminance);
            return mix(col, tint, 0.20f);
        }
        case PALETTE_ROSE:
        default: {
            float3 tint = mix(float3(0.28f, 0.06f, 0.20f), float3(1.0f, 0.72f, 0.88f), luminance);
            return mix(col, tint, 0.18f);
        }
    }
}

static float3 stylize(float3 col, float2 uv, constant Uniforms& u, StyleParams style) {
    float luminance = dot(col, float3(0.299f, 0.587f, 0.114f));
    col = applyPalettePreset(col, luminance, style.palettePreset);
    if (abs(style.intensity - 1.0f) > 0.02f)
        col = pow(max(col, 0.0f), float3(max(style.intensity, 0.01f)));
    if (abs(style.contrast - 1.0f) > 0.02f)
        col = (col - 0.5f) * style.contrast + 0.5f;
    if (style.noiseAmount > 0.005f) {
        float grain = noise2D(uv * u.resolution * 0.22f + float2(u.time * 13.0f, float(u.frame) * 0.031f));
        col += (grain - 0.5f) * style.noiseAmount;
    }
    return saturate(col);
}

static float4 renderTheme(float4 pos, constant Uniforms& u, StyleParams style) {
    float4 adjustedPos = transformedPos(pos, u, style.zoom);

    switch (style.family) {
        case THEME_FAMILY_PLASMA:
            return classicPlasma(adjustedPos, u, style);
        case THEME_FAMILY_FRACTALS:
            switch (style.theme) {
                case THEME_MANDELBROT:    return mandelbrot(adjustedPos, u, style);
                case THEME_JULIA_BLOOM:   return juliaBloom(adjustedPos, u, style);
                case THEME_NEWTON_PETALS: return newtonPetals(adjustedPos, u, style);
                case THEME_FOLD_DRIFT:    return foldDrift(pos, u, style);
                default:                  return classicPlasma(adjustedPos, u, style);
            }
        case THEME_FAMILY_PATTERNS:
            switch (style.theme) {
                case THEME_POLAR_LISSAJOUS:  return polarLissajous(adjustedPos, u, style);
                case THEME_MOIRE_DREAM:      return moireDream(adjustedPos, u, style);
                case THEME_KALEIDO_WAVE:     return kaleidoWave(adjustedPos, u, style);
                case THEME_DOMAIN_COLORING:  return domainColoring(adjustedPos, u, style);
                case THEME_APOLLONIAN_TILES: return apollonianTiles(adjustedPos, u, style);
                default:                     return classicPlasma(adjustedPos, u, style);
            }
        case THEME_FAMILY_ATMOSPHERE:
            switch (style.theme) {
                case THEME_GLASS_CURRENT: return glassCurrent(adjustedPos, u, style);
                case THEME_SYNTHWAVE_RUN: return synthwaveRun(adjustedPos, u, style);
                case THEME_MONO_MIST:     return monoMist(adjustedPos, u, style);
                case THEME_MINIMAL_ARC:   return minimalArc(adjustedPos, u, style);
                case THEME_AMBIENT_HAZE:  return ambientHaze(adjustedPos, u, style);
                default:                  return ambientHaze(adjustedPos, u, style);
            }
        default:
            return classicPlasma(adjustedPos, u, style);
    }
}

fragment float4 fs_main(float4 pos [[position]],
                        constant Uniforms& u [[buffer(0)]]) {
    StyleParams currentStyle  = { u.theme, u.themeFamily, u.themeVariant,
                                  u.palettePreset, u.intensity, u.contrast,
                                  u.noiseAmount, u.zoom };
    StyleParams previousStyle = { u.previousTheme, u.previousThemeFamily, u.previousThemeVariant,
                                  u.previousPalettePreset, u.previousIntensity, u.previousContrast,
                                  u.previousNoiseAmount, u.previousZoom };

    float2 uv = pos.xy / u.resolution;
    if (u.transitionProgress >= 1.0f)
        return float4(stylize(renderTheme(pos, u, currentStyle).rgb, uv, u, currentStyle), 1.0f);

    float3 currentColor  = stylize(renderTheme(pos, u, currentStyle).rgb,  uv, u, currentStyle);
    float3 previousColor = stylize(renderTheme(pos, u, previousStyle).rgb, uv, u, previousStyle);
    float  blend = smoothstep(0.0f, 1.0f, u.transitionProgress);
    return float4(mix(previousColor, currentColor, blend), 1.0f);
}
