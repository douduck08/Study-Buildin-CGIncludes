#ifndef COMMON_UTILITIES_INCLUDED
#define COMMON_UTILITIES_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardConfig.cginc"
// #include "UnityStandardUtils.cginc"

// Create and initialize structure variable, depend on platform
#if defined(UNITY_COMPILER_HLSL) || defined(SHADER_API_PSSL) || defined(UNITY_COMPILER_HLSLCC)
#define INITIALIZE_STRUCT(type, name) type name = (type)0;
#else
#define INITIALIZE_STRUCT(type, name) type name;
#endif

// Normalize vector in vertex/fragment shader, depend on SHADER_TARGET
inline float3 NormalizePerVertexNormal (float3 n) {
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

// Calculate vector transform in different space
#define GET_NORMAL_IN_WORLD(vertex, name) float3 name = UnityObjectToWorldNormal(vertex.normal)
#define GET_TANGENT_IN_WORLD(vertex, name) float4 name = float4(UnityObjectToWorldDir(vertex.tangent.xyz), vertex.tangent.w)

#define GET_TANGENT_TO_WORLD_ROTATION(normalWorld, tangentWorld, name) \
    float3 binormalWorld = cross(normalWorld, tangentWorld.xyz) * tangentWorld.w * unity_WorldTransformParams.w; \
    float3x3 name = float3x3(tangentWorld.xyz, binormalWorld, normalWorld)

#define GET_WORLD_TO_TANGENT_ROTATION(vertex, name) \
    float3 binormal = cross(normalize(vertex.normal), normalize(vertex.tangent.xyz) ) * vertex.tangent.w; \
    float3x3 name = float3x3(vertex.tangent.xyz, binormal, vertex.normal)

#endif // COMMON_UTILITIES_INCLUDED