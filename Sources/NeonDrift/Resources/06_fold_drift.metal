// Based on "RayMarching starting point" by Martijn Steinrucken (The Art of Code)
// Source: https://www.shadertoy.com/view/7sscW4 — MIT License

#define FOLD_MAX_STEPS 48
#define FOLD_MAX_DIST  8.0f
#define FOLD_SURF_DIST 0.003f

static float2x2 foldRot2(float a) {
    float s = fast::sin(a), c = fast::cos(a);
    return float2x2(float2(c, -s), float2(s, c));
}

static float foldSDF(float3 p, float t) {
    float2 uv = p.xz;
    uv.x = abs(uv.x);
    float tf = 12.0f + t;
    float2 q = float2(1, 0);
    float th = 0.4f * p.y - 0.6f * tf;
    float m  = 1.8f;
    for (float i = 0.0f; i < 6.0f; i++) {
        uv -= m * q;
        th += 0.5f * p.y + 0.05f * tf;
        uv  = foldRot2(th) * uv;
        uv.x = abs(uv.x);
        m *= 0.05f * fast::cos(8.0f * fast::length(uv)) + 0.55f;
    }
    return 0.5f * (fast::length(uv) - 2.0f * m);
}

static float foldRM(float3 ro, float3 rd, float t) {
    float dO = 0.0f;
    for (int i = 0; i < FOLD_MAX_STEPS; i++) {
        float dS = foldSDF(ro + rd * dO, t);
        dO += dS;
        if (dO > FOLD_MAX_DIST || abs(dS) < FOLD_SURF_DIST) break;
    }
    return dO;
}

static float3 foldNormal(float3 p, float t) {
    float d   = foldSDF(p, t);
    float2 e  = float2(0.001f, 0);
    return fast::normalize(d - float3(foldSDF(p - e.xyy, t), foldSDF(p - e.yxy, t), foldSDF(p - e.yyx, t)));
}

static float3 foldRayDir(float2 uv, float3 ro, float3 la, float fl) {
    float3 f = fast::normalize(la - ro);
    float3 r = fast::normalize(cross(float3(0, 1, 0), f));
    return fast::normalize(fl * f + uv.x * r + uv.y * cross(f, r));
}

static float3 foldEnv(float3 dir, float t) {
    float3 d = fast::normalize(dir);
    float u  = fast::atan2(d.z, d.x) * 0.15915f + 0.5f;
    float v  = d.y * 0.5f + 0.5f;
    float ripple = 0.5f + 0.5f * fast::sin(u * 14.0f + t * 0.18f) * fast::cos(v * 9.0f - t * 0.24f);
    return mix(float3(0.01f, 0.005f, 0.04f), float3(0.08f, 0.03f, 0.14f), v)
         + float3(0.12f, 0.05f, 0.20f) * ripple;
}

float4 foldDrift(float4 pos, constant Uniforms& u, StyleParams style) {
    float invR = 1.0f / min(u.resolution.x, u.resolution.y);
    float2 uv  = (pos.xy * 2.0f - u.resolution) * invR;
    float  t   = u.familyTime;
    float  ang = t * 0.05f + u.accentPhase * 0.08f;
    float3 ro  = float3(5.5f * fast::cos(ang), 0.5f * fast::sin(t * 0.13f), 5.5f * fast::sin(ang));
    float3 rd  = foldRayDir(uv, ro, float3(0, 0, 0), 2.0f);
    float3 col = float3(0);
    float  d   = foldRM(ro, rd, t);
    if (d < FOLD_MAX_DIST) {
        float3 p = ro + rd * d;
        float3 n = foldNormal(p, t);
        float3 r = reflect(rd, n);
        float  dif = max(dot(n, fast::normalize(float3(1, 2, 3))), 0.0f);
        col = float3(dif * 0.4f + 0.3f) * foldEnv(r, t) * (1.0f + r.y);
        col = clamp(col, 0.0f, 1.0f);
        float3 e = float3(1.0f);
        col *= palette(r.y, e, e, e, 0.35f * float3(0.0f, 0.33f, 0.66f));
    }
    return float4(pow(saturate(col), float3(0.4545f)), 1.0f);
}
