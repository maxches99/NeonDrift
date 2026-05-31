float4 classicPlasma(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv  = pos.xy / u.resolution;
    float invR = 1.0f / min(u.resolution.x, u.resolution.y);
    float2 p   = (pos.xy * 2.0f - u.resolution) * invR;
    float  t   = u.familyTime * 0.24f + u.accentPhase * 0.1f;

    float v = 0.0f;
    v += fast::sin((p.x * 1.55f + t * 1.20f) * 4.4f);
    v += fast::sin((p.y * 1.35f - t * 0.95f) * 5.2f);
    v += fast::sin((p.x + p.y + t * 0.72f) * 4.8f);
    v += fast::sin(fast::sqrt(dot(p, p) + 0.18f) * 8.5f - t * 1.75f);
    v += 0.55f * fast::sin((p.x - p.y) * 7.0f + t * 1.35f);
    v *= 0.22f;

    float glow   = 0.5f + 0.5f * fast::sin(v * 3.14159265f);
    float ribbon = 0.5f + 0.5f * fast::sin(v * 6.28318530f + uv.x * 2.4f - uv.y * 1.8f);
    float bloom  = smoothstep(0.36f, 1.0f, glow);

    float3 deepRose = float3(0.18f,  0.015f, 0.105f);
    float3 velvet   = float3(0.46f,  0.035f, 0.245f);
    float3 fuchsia  = float3(0.95f,  0.135f, 0.560f);
    float3 blush    = float3(1.00f,  0.530f, 0.760f);
    float3 pearl    = float3(1.00f,  0.875f, 0.940f);

    switch (style.theme) {
        case THEME_SAKURA:
            deepRose = float3(0.145f, 0.050f, 0.100f);
            velvet   = float3(0.480f, 0.170f, 0.260f);
            fuchsia  = float3(1.000f, 0.375f, 0.585f);
            blush    = float3(1.000f, 0.685f, 0.790f);
            pearl    = float3(1.000f, 0.930f, 0.965f);
            break;
        case THEME_BUBBLEGUM:
            deepRose = float3(0.115f, 0.025f, 0.150f);
            velvet   = float3(0.390f, 0.075f, 0.420f);
            fuchsia  = float3(1.000f, 0.250f, 0.820f);
            blush    = float3(1.000f, 0.620f, 0.920f);
            pearl    = float3(0.960f, 0.880f, 1.000f);
            break;
        case THEME_NEON_ROSE:
            deepRose = float3(0.060f, 0.000f, 0.075f);
            velvet   = float3(0.290f, 0.000f, 0.260f);
            fuchsia  = float3(1.000f, 0.030f, 0.620f);
            blush    = float3(1.000f, 0.300f, 0.710f);
            pearl    = float3(1.000f, 0.760f, 0.920f);
            break;
        case THEME_MIDNIGHT_BLUSH:
            deepRose = float3(0.035f, 0.020f, 0.070f);
            velvet   = float3(0.190f, 0.055f, 0.170f);
            fuchsia  = float3(0.650f, 0.110f, 0.390f);
            blush    = float3(0.940f, 0.455f, 0.680f);
            pearl    = float3(1.000f, 0.800f, 0.900f);
            break;
        case THEME_SILVER:
            deepRose = float3(0.030f, 0.032f, 0.040f);
            velvet   = float3(0.185f, 0.195f, 0.215f);
            fuchsia  = float3(0.610f, 0.635f, 0.680f);
            blush    = float3(0.870f, 0.885f, 0.925f);
            pearl    = float3(1.000f, 0.965f, 0.985f);
            break;
        default: break;
    }

    float3 col = mix(deepRose, velvet, glow);
    col = mix(col, fuchsia, ribbon * 0.58f);
    col = mix(col, blush,   bloom  * 0.45f);
    col += pearl * pow(bloom, 3.0f) * 0.28f;

    float vignette = 1.0f - smoothstep(0.18f, 1.28f, fast::length(p));
    col *= 0.70f + 0.30f * vignette;

    return float4(saturate(col), 1.0f);
}
