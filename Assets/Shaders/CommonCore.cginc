inline half3 NormalizePerVertexNormal (float3 n) {
    // takes float to avoid overflow
    #if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
        return normalize(n);
    #else
        return n; // will normalize per-pixel instead
    #endif
}

inline float3 NormalizePerPixelNormal (float3 n) {
    #if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
        return n;
    #else
        return normalize(n);
    #endif
}