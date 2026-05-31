float4 glassCurrent(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = pos.xy / u.resolution;
    float2 p  = (uv - 0.5f) * float2(u.resolution.x / max(u.resolution.y, 1.0f), 1.0f);
    float  t  = u.familyTime * 0.18f + u.accentPhase * 0.05f;

    float wave    = fast::sin(p.x * 8.0f + t * 2.0f) + fast::cos(p.y * 10.0f - t * 1.6f);
    float caustic = fast::sin((p.x + p.y) * 18.0f + wave * 2.0f - t * 1.8f);
    float frost   = noise2D(uv * 8.0f + float2(t * 0.4f, -t * 0.3f));
    float sheen   = smoothstep(0.55f, 1.0f, 0.5f + 0.5f * caustic);

    float3 base = mix(float3(0.10f, 0.18f, 0.24f), float3(0.78f, 0.92f, 0.98f), frost * 0.9f);
    base += float3(0.85f, 0.95f, 1.0f) * sheen * 0.35f;
    base += float3(0.58f, 0.82f, 0.92f) * pow(max(0.0f, 1.0f - abs(wave) * 0.25f), 4.0f) * 0.22f;
    return float4(saturate(base), 1.0f);
}

float4 synthwaveRun(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = pos.xy / u.resolution;
    float2 p  = uv * 2.0f - 1.0f;
    float  t  = u.familyTime * 0.32f + u.accentPhase * 0.1f;

    float horizon  = smoothstep(-0.02f, 0.02f, p.y + 0.18f);
    float sun      = smoothstep(0.42f, 0.0f, distance(p, float2(0.0f, 0.28f)));
    float grid     = abs(fract((p.x * 8.0f) + 0.5f) - 0.5f);
    float lanes    = smoothstep(0.46f, 0.50f, grid) * smoothstep(-0.92f, 0.05f, -p.y);
    float travel   = fast::sin((p.y + 1.1f) * 18.0f - t * 8.0f);
    float mountain = smoothstep(0.0f, 0.12f, fast::sin(p.x * 5.0f + t) * 0.10f + 0.06f - abs(p.y + 0.06f));

    float3 sky = mix(float3(0.03f, 0.03f, 0.16f), float3(0.84f, 0.24f, 0.52f), uv.y);
    sky += float3(0.95f, 0.52f, 0.22f) * sun * 0.9f;
    sky += float3(0.92f, 0.16f, 0.60f) * lanes * (0.35f + 0.65f * smoothstep(0.0f, 1.0f, travel * 0.5f + 0.5f));
    sky  = mix(sky, float3(0.04f, 0.06f, 0.12f), 1.0f - horizon);
    sky += float3(0.20f, 0.65f, 1.0f) * mountain * 0.42f;
    return float4(saturate(sky), 1.0f);
}

float4 monoMist(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = pos.xy / u.resolution;
    float2 p  = (uv - 0.5f) * 2.0f;
    float  t  = u.familyTime * 0.12f;

    float mistA = noise2D(uv * 3.0f + float2(t, -t * 0.7f));
    float mistB = noise2D(uv * 6.0f - float2(t * 0.5f, t * 0.3f));
    float fog   = smoothstep(0.22f, 0.82f, mistA * 0.6f + mistB * 0.4f);
    float vignette = 1.0f - smoothstep(0.2f, 1.2f, fast::length(p));
    float gray  = mix(0.14f, 0.84f, fog) * (0.78f + 0.22f * vignette);
    return float4(float3(gray), 1.0f);
}

float4 minimalArc(float4 pos, constant Uniforms& u, StyleParams style) {
    float invR  = 1.0f / min(u.resolution.x, u.resolution.y);
    float2 p    = (pos.xy * 2.0f - u.resolution) * invR;
    float  t    = u.familyTime * 0.18f;
    float radius = fast::length(p);
    float arc1  = smoothstep(0.014f, 0.0f, abs(radius - (0.38f + 0.05f * fast::sin(t))));
    float arc2  = smoothstep(0.014f, 0.0f, abs(radius - (0.74f + 0.04f * fast::cos(t * 1.2f))));
    float line  = smoothstep(0.012f, 0.0f, abs(p.y + 0.18f * fast::sin(t * 0.8f)));
    float pulse = 0.5f + 0.5f * fast::sin(fast::atan2(p.y, p.x) * 5.0f - t * 2.0f);

    float3 base = mix(float3(0.94f, 0.95f, 0.97f), float3(0.80f, 0.84f, 0.90f), radius);
    base -= float3(0.18f, 0.22f, 0.28f) * arc1 * (0.4f + 0.6f * pulse);
    base -= float3(0.10f, 0.14f, 0.18f) * arc2 * 0.65f;
    base -= float3(0.16f, 0.18f, 0.20f) * line * 0.38f;
    return float4(saturate(base), 1.0f);
}

float4 ambientHaze(float4 pos, constant Uniforms& u, StyleParams style) {
    float2 uv = pos.xy / u.resolution;
    float2 p  = uv * 2.0f - 1.0f;
    float  t  = u.familyTime * 0.09f;

    float haze = noise2D(uv * 2.2f + float2(t * 0.4f, -t * 0.3f));
    haze += 0.6f * noise2D(uv * 4.6f - float2(t * 0.2f, t * 0.15f));
    haze /= 1.6f;
    float drift = 0.5f + 0.5f * fast::sin(p.x * 2.2f + p.y * 1.8f + t * 2.0f);
    float2 gp   = p - float2(0.15f, -0.08f);
    float glow  = fast::exp(-2.5f * dot(gp, gp));

    float3 col = mix(float3(0.11f, 0.10f, 0.15f), float3(0.42f, 0.46f, 0.58f), haze);
    col = mix(col, float3(0.74f, 0.62f, 0.68f), drift * 0.18f);
    col += float3(0.92f, 0.84f, 0.88f) * glow * 0.22f;
    return float4(saturate(col), 1.0f);
}
