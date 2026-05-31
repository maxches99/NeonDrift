float4 polarLissajous(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv  = pos.xy / u.resolution;
    float invR = 1.0f / min(u.resolution.x, u.resolution.y);
    float2 p   = (pos.xy * 2.0f - u.resolution) * invR;
    float  r   = fast::length(p);
    float  a   = fast::atan2(p.y, p.x);
    float  t   = u.familyTime * 0.55f + u.accentPhase * 0.18f;

    float rose = fast::sin(a * 7.0f + fast::sin(t * 0.7f) * 1.6f) * fast::cos(r * 16.0f - t * 2.4f);
    float liss = fast::sin((p.x * 4.0f + t * 1.3f) * (2.1f + 0.4f * fast::sin(t * 0.3f)))
               + fast::cos((p.y * 3.0f - t * 1.1f) * (3.4f + 0.3f * fast::cos(t * 0.23f)));
    float mesh = fast::sin((r + 0.18f * liss) * 34.0f - t * 3.6f);
    float glow = smoothstep(0.55f, 0.98f, 0.5f + 0.5f * mesh);

    float3 col = palette(
        rose * 0.18f + liss * 0.08f + uv.x * 0.22f - uv.y * 0.15f + t * 0.04f,
        float3(0.26f, 0.24f, 0.30f),
        float3(0.52f, 0.34f, 0.42f),
        float3(1.00f, 0.82f, 0.64f),
        float3(0.76f, 0.14f, 0.22f)
    );

    col += float3(1.0f, 0.70f, 0.88f) * glow * (0.35f + 0.65f * smoothstep(0.0f, 1.0f, rose * 0.5f + 0.5f));
    col += float3(0.55f, 0.90f, 1.0f) * pow(max(0.0f, 1.0f - abs(liss) * 0.35f), 4.0f) * 0.16f;
    return float4(saturate(col), 1.0f);
}

float4 moireDream(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv  = pos.xy / u.resolution;
    float invR = 1.0f / min(u.resolution.x, u.resolution.y);
    float2 p   = (pos.xy * 2.0f - u.resolution) * invR;
    float  t   = u.familyTime * 0.42f + u.accentPhase * 0.12f;

    float2 q1 = p + float2(0.18f * fast::sin(t), 0.16f * fast::cos(t * 1.2f));
    float2 q2 = p + float2(0.22f * fast::cos(t * 0.9f), -0.14f * fast::sin(t * 1.1f));

    float ringA = fast::sin(fast::length(q1) * 42.0f - t * 3.2f);
    float ringB = fast::sin(fast::length(q2 * float2(1.12f, 0.88f)) * 40.0f + t * 2.7f);
    float spokes = fast::sin(fast::atan2(p.y, p.x) * 18.0f + t * 1.8f);
    float field  = ringA + ringB + 0.55f * spokes;
    float bands  = 0.5f + 0.5f * fast::sin(field * 2.2f + uv.x * 5.0f - uv.y * 3.0f);
    float highlight = pow(bands, 7.0f);

    float3 col = palette(
        bands * 0.9f + t * 0.03f,
        float3(0.20f, 0.21f, 0.26f),
        float3(0.48f, 0.39f, 0.34f),
        float3(0.90f, 0.78f, 0.72f),
        float3(0.02f, 0.18f, 0.30f)
    );

    col += float3(1.0f, 0.52f, 0.76f) * highlight * 0.46f;
    col += float3(0.48f, 0.88f, 1.0f) * pow(max(0.0f, ringA * ringB), 2.0f) * 0.18f;
    return float4(saturate(col), 1.0f);
}

float4 kaleidoWave(float4 pos, constant Uniforms& u, StyleParams style) {
    float invR   = 1.0f / min(u.resolution.x, u.resolution.y);
    float2 p     = (pos.xy * 2.0f - u.resolution) * invR;
    float  t     = u.familyTime * 0.44f + u.accentPhase * 0.15f;

    float segments = 6.0f + floor(1.5f + 1.5f * fast::sin(u.familyTime * 0.1f + float(style.variant) * 0.7f));
    float angle    = fast::atan2(p.y, p.x);
    float radius   = fast::length(p);
    float sector   = 6.28318530f / segments;
    angle = abs(fmod(angle + sector * 0.5f, sector) - sector * 0.5f);

    float2 k = rotate2D(float2(fast::cos(angle), fast::sin(angle)) * radius, t * 0.3f);

    float wave  = fast::sin(k.x * 16.0f + t * 2.4f) + fast::cos(k.y * 18.0f - t * 2.1f);
    float fold  = fast::sin((k.x + k.y) * 22.0f - t * 3.0f);
    float spark = smoothstep(0.78f, 0.99f, 0.5f + 0.5f * fast::sin(wave * fold * 2.6f));

    float3 col = palette(
        angle / sector + wave * 0.08f + radius * 0.16f + t * 0.04f,
        float3(0.24f, 0.18f, 0.30f),
        float3(0.58f, 0.40f, 0.36f),
        float3(1.00f, 0.82f, 0.58f),
        float3(0.78f, 0.06f, 0.30f)
    );

    col += float3(1.0f, 0.62f, 0.84f) * spark * 0.45f;
    col += float3(0.42f, 0.90f, 1.0f) * pow(max(0.0f, 1.0f - abs(fold)), 5.0f) * 0.16f;
    return float4(saturate(col), 1.0f);
}

float4 domainColoring(float4 pos, constant Uniforms& u, StyleParams style) {
    float invR = 1.0f / min(u.resolution.x, u.resolution.y);
    float2 p   = (pos.xy * 2.0f - u.resolution) * invR;
    float  t   = u.familyTime * 0.22f + u.accentPhase * 0.08f;
    float2 z   = rotate2D(p * 1.25f, t * 0.35f);
    float2 w   = cmul(cmul(z, z), z) - float2(1.0f, 0.0f);
    w = cdiv(w, z * z + float2(0.22f, -0.08f));

    float phase     = fast::atan2(w.y, w.x);
    float magnitude = fast::length(w);
    float hueDriver = phase / 6.28318530f + 0.5f;
    float logMag    = fast::log2(max(magnitude, 1e-4f));
    float contour   = 0.5f + 0.5f * fast::cos(logMag * 8.0f);
    float grid      = 0.5f + 0.5f * fast::cos(phase * 10.0f);

    float3 col = palette(
        hueDriver + t * 0.03f,
        float3(0.36f, 0.34f, 0.38f),
        float3(0.52f, 0.40f, 0.36f),
        float3(1.0f,  1.0f,  1.0f),
        float3(0.02f, 0.16f, 0.32f)
    );

    col *= 0.55f + 0.45f * contour;
    col += float3(1.0f, 0.70f, 0.86f) * pow(grid, 8.0f) * 0.24f;
    col += float3(0.62f, 0.92f, 1.0f) * fast::exp(-5.0f * abs(logMag)) * 0.18f;
    return float4(saturate(col), 1.0f);
}

float4 apollonianTiles(float4 pos, constant Uniforms& u, StyleParams style) {
    float invR = 1.0f / min(u.resolution.x, u.resolution.y);
    float2 p   = (pos.xy * 2.0f - u.resolution) * invR;
    float  t   = u.familyTime * 0.28f + u.accentPhase * 0.10f;
    float2 z   = rotate2D(p * 1.05f, t * 0.12f);

    float orbit      = 0.0f;
    float minBubble  = 10.0f;
    float cellGlow   = 0.0f;
    float macroBubble = 10.0f;

    for (int i = 0; i < 6; ++i) {
        z = abs(z);
        if (z.x < z.y) { float tmp = z.x; z.x = z.y; z.y = tmp; }

        z = z * 1.38f - float2(0.92f, 0.18f);
        z = rotate2D(z, 0.16f * fast::sin(t + float(i) * 0.7f));

        float radius2  = clamp(dot(z, z), 0.05f, 12.0f);
        float invScale = clamp(0.84f / radius2, 0.22f, 1.65f);
        z *= invScale;

        float bubble = abs(fast::length(z - float2(0.62f, 0.0f)) - 0.32f);
        minBubble  = min(minBubble, bubble);
        orbit     += fast::exp(-14.0f * bubble);
        cellGlow  += fast::exp(-7.0f  * fast::length(z - float2(0.62f, 0.0f)));
        if (i < 3) macroBubble = min(macroBubble, bubble);
    }

    float r          = fast::length(z);
    float bubbleMask = fast::exp(-26.0f * minBubble);
    float macroMask  = fast::exp(-18.0f * macroBubble);
    float softRings  = 0.5f + 0.5f * fast::sin(7.0f * r - orbit * 0.8f - t * 1.1f);
    float spokes     = 0.5f + 0.5f * fast::cos(fast::atan2(z.y, z.x) * 4.0f + orbit * 0.45f);
    float web        = smoothstep(0.70f, 0.94f, 0.52f * softRings + 0.48f * spokes + macroMask * 0.45f);
    float mist       = smoothstep(0.12f, 1.1f, orbit * 0.12f + cellGlow * 0.10f);

    float3 col = palette(
        macroMask * 0.18f + r * 0.09f + t * 0.015f,
        float3(0.14f, 0.08f, 0.08f),
        float3(0.28f, 0.16f, 0.14f),
        float3(0.82f, 0.72f, 0.62f),
        float3(0.78f, 0.11f, 0.24f)
    );

    col  = mix(col * 0.42f, col, 0.12f + 0.88f * mist * macroMask);
    col += float3(1.0f, 0.62f, 0.80f) * web * macroMask * 0.22f;
    col += float3(0.62f, 0.94f, 1.0f) * pow(macroMask, 1.8f) * 0.16f;
    col += float3(1.0f, 0.90f, 0.84f) * smoothstep(0.80f, 0.98f, macroMask) * 0.14f;
    return float4(saturate(col), 1.0f);
}
