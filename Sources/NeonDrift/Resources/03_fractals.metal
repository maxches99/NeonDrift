float4 mandelbrot(float4 pos, constant Uniforms& u, StyleParams style) {
    float invR  = 1.0f / min(u.resolution.x, u.resolution.y);
    float2 p    = (pos.xy * 2.0f - u.resolution) * invR;
    float  epoch = float(u.mandelbrotEpoch);
    // slow tilt animation — keep full precision sin/cos for camera stability
    float  angle  = 0.035f * sin(u.familyTime * 0.071f + epoch * 1.7f + u.accentPhase * 0.12f);
    float  zoom   = u.mandelbrotZoom;
    float2 center = u.mandelbrotCenter;

    float s = sin(angle), c = cos(angle);
    float2 z0 = float2(c * p.x - s * p.y, s * p.x + c * p.y) * zoom + center;
    float2 z  = float2(0.0f);

    const int maxIter = 128;
    float iter = 0.0f;
    for (int i = 0; i < maxIter; ++i) {
        z = float2(z.x * z.x - z.y * z.y, 2.0f * z.x * z.y) + z0;
        if (dot(z, z) > 16.0f) {
            float logRadius  = log(dot(z, z)) * 0.5f;
            float smoothIter = float(i) + 1.0f - log2(max(logRadius, 0.0001f));
            iter = smoothIter / float(maxIter);
            break;
        }
    }

    float escaped  = step(0.0001f, iter);
    float band     = 0.5f + 0.5f * fast::sin(iter * 72.0f - u.familyTime * 0.85f + u.accentPhase);
    float halo     = pow(smoothstep(0.0f, 0.58f, iter), 0.85f);
    float3 col     = palette(
        iter * 1.65f + u.familyTime * 0.018f + u.accentPhase * 0.04f,
        float3(0.42f, 0.36f, 0.40f),
        float3(0.47f, 0.36f, 0.34f),
        float3(0.92f, 0.74f, 0.58f),
        float3(0.01f, 0.18f, 0.34f)
    );

    float3 interior  = float3(0.018f, 0.015f, 0.028f);
    float3 edgeGlow  = float3(1.0f, 0.62f, 0.82f) * pow(band, 5.0f) * halo;
    col = mix(interior, col, escaped);
    col += edgeGlow * escaped;
    col += float3(0.55f, 0.24f, 0.38f) * fast::exp(-zoom * 1.4f) * 0.08f * escaped;
    return float4(saturate(col), 1.0f);
}

float4 juliaBloom(float4 pos, constant Uniforms& u, StyleParams style) {
    float invR = 1.0f / min(u.resolution.x, u.resolution.y);
    float2 p   = (pos.xy * 2.0f - u.resolution) * invR;
    float2 c   = float2(
        -0.78f + 0.12f * fast::sin(u.familyTime * 0.19f + u.accentPhase * 0.4f),
         0.16f + 0.08f * fast::cos(u.familyTime * 0.23f + float(style.variant) * 0.3f)
    );

    float angle = u.familyTime * 0.08f + u.accentPhase * 0.1f;
    float2 z    = rotate2D(p, angle) * 1.45f;

    const int maxIter = 96;
    float iter = 0.0f, trap = 10.0f;
    for (int i = 0; i < maxIter; ++i) {
        z = cmul(z, z) + c;
        trap = min(trap, abs(z.x * z.y));
        float radius2 = dot(z, z);
        if (radius2 > 24.0f) {
            float smoothIter = float(i) + 1.0f - log2(max(log2(radius2), 0.0001f));
            iter = smoothIter / float(maxIter);
            break;
        }
    }

    float escaped   = step(0.0001f, iter);
    float petals    = 0.5f + 0.5f * fast::sin(fast::atan2(p.y, p.x) * 8.0f + u.familyTime * 0.7f + iter * 22.0f + u.accentPhase);
    float orbitGlow = fast::exp(-22.0f * trap);
    float3 col      = palette(
        iter * 1.2f + petals * 0.35f + u.familyTime * 0.04f + u.accentPhase * 0.08f,
        float3(0.30f, 0.18f, 0.32f),
        float3(0.60f, 0.42f, 0.34f),
        float3(0.80f, 0.75f, 0.55f),
        float3(0.85f, 0.10f, 0.22f)
    );

    col = mix(float3(0.018f, 0.016f, 0.030f), col, escaped);
    col += float3(1.0f, 0.58f, 0.82f) * pow(petals, 4.0f) * 0.26f;
    col += float3(0.72f, 0.94f, 1.0f) * orbitGlow * 0.85f;
    return float4(saturate(col), 1.0f);
}

float4 newtonPetals(float4 pos, constant Uniforms& u, StyleParams style) {
    float invR = 1.0f / min(u.resolution.x, u.resolution.y);
    float2 p   = (pos.xy * 2.0f - u.resolution) * invR;
    float2 z   = p * 1.9f;

    const int maxIter = 28;
    float accum = 0.0f;
    for (int i = 0; i < maxIter; ++i) {
        float2 z2 = cmul(z, z);
        float2 z3 = cmul(z2, z);
        float2 f  = z3 - float2(1.0f, 0.0f);
        float2 df = 3.0f * z2;
        z -= cdiv(f, df);
        accum += fast::exp(-3.5f * fast::length(f));
    }

    float2 roots[3] = {
        float2( 1.0f,  0.0f),
        float2(-0.5f,  0.8660254f),
        float2(-0.5f, -0.8660254f)
    };

    float d0 = fast::length(z - roots[0]);
    float d1 = fast::length(z - roots[1]);
    float d2 = fast::length(z - roots[2]);

    float3 rootColor = float3(0.95f, 0.48f, 0.70f);
    if (d1 < d0 && d1 < d2)
        rootColor = float3(0.46f, 0.92f, 0.96f);
    else if (d2 < d0 && d2 < d1)
        rootColor = float3(0.98f, 0.82f, 0.46f);

    float basin   = fast::exp(-6.0f * min(d0, min(d1, d2)));
    float rings   = 0.5f + 0.5f * fast::sin(accum * 2.4f + fast::length(p) * 12.0f - u.familyTime * 1.3f + u.accentPhase);
    float shimmer = pow(rings, 6.0f) * (0.35f + basin);
    float3 base   = mix(float3(0.020f, 0.018f, 0.030f), rootColor * 0.68f, saturate(accum / 7.5f));
    float3 col    = base + rootColor * shimmer;
    col += float3(1.0f, 0.95f, 0.98f) * pow(basin, 2.0f) * 0.18f;
    return float4(saturate(col), 1.0f);
}
