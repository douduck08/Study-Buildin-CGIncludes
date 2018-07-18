#ifndef COMMON_CG_INCLUDED
#define COMMON_CG_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityStandardInput.cginc"

// Create and initialize structure variable, depend on platform
#if defined(UNITY_COMPILER_HLSL) || defined(SHADER_API_PSSL) || defined(UNITY_COMPILER_HLSLCC)
    #define DECLARE_STRUCT(type, name) type name = (type)0;
#else
    #define DECLARE_STRUCT(type, name) type name;
#endif

// Normalize vector in vertex/fragment shader, depend on SHADER_TARGET
#if (SHADER_TARGET < 30)
    #define NORMALIZE_PER_VERTEX(n) normalize(n)
    #define NORMALIZE_PER_PIXEL(n) n // will normalize per-pixel instead
#else
    #define NORMALIZE_PER_VERTEX(n) n
    #define NORMALIZE_PER_PIXEL(n) normalize(n)
#endif

// Setup data about instancing and vr
#define SETUP_INSTANCE_DATA_VERTEX(v, o) \
    UNITY_SETUP_INSTANCE_ID(v); \
    UNITY_TRANSFER_INSTANCE_ID(v, o); \
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o)
#define SETUP_INSTANCE_DATA_PIXEL(i) UNITY_SETUP_INSTANCE_ID(i)

// Setup point in different space
#define SETUP_POSITION_IN_WORLD(name) float4 name = mul(unity_ObjectToWorld, v.vertex)
#define SETUP_NORMAL_IN_WORLD(name) float3 name = UnityObjectToWorldNormal(v.normal)
#define SETUP_TANGENT_IN_WORLD(name) float4 name = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w)

// Calculate transform matrix in different space
#define GET_TANGENT_TO_WORLD_ROTATION(normalWorld, tangentWorld, name) \
    float3 binormalWorld = cross(normalWorld, tangentWorld.xyz) * tangentWorld.w * unity_WorldTransformParams.w; \
    float3x3 name = float3x3(tangentWorld.xyz, binormalWorld, normalWorld)

#define GET_OBJECT_TO_TANGENT_ROTATION(vertex, name) \
    float3 binormal = cross(normalize(vertex.normal), normalize(vertex.tangent.xyz) ) * vertex.tangent.w; \
    float3x3 name = float3x3(vertex.tangent.xyz, binormal, vertex.normal)

#endif // COMMON_CG_INCLUDED