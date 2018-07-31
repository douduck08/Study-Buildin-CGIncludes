#ifndef COMMON_CG_INCLUDED
#define COMMON_CG_INCLUDED

#include "UnityCG.cginc"

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

// -------------------------------------------------------------------
// Point/Vector helper for different space
// ** Should be uesd in vertext shader with vertex data input being named as `v`.
// |       Method        |  Type  |
// | POSITION_IN_WORLD   | float4 |
// | NORMAL_IN_WORLD     | float3 |
// | TANGENT_IN_WORLD    | float4 |
// | BINORMAL_IN_WORLD   | float3 |
// | BINORMAL_IN_OBJECT  | float3 |
#define POSITION_IN_WORLD mul(unity_ObjectToWorld, v.vertex)
#define NORMAL_IN_WORLD UnityObjectToWorldNormal(v.normal)
#define TANGENT_IN_WORLD float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w)
#define BINORMAL_IN_WORLD(normalWorld, tangentWorld) cross(normalWorld, tangentWorld.xyz) * tangentWorld.w * unity_WorldTransformParams.w
#define BINORMAL_IN_OBJECT cross(normalize(v.normal), normalize(v.tangent.xyz) ) * v.tangent.w

// Calculate transform matrix in different space
inline float3x3 GetObjectToTangentRotation(float3 normal, float4 tangent, float3 binormal) {
    return float3x3(tangent.xyz, binormal, normal);
}

// -------------------------------------------------------------------
// Utility helper
#define NOTMAL_TO_COLOR(normal) normal * 0.5 + 0.5

// -------------------------------------------------------------------
// Define data structure FragOutputDeferred
struct FragOutputDeferred {
    half4 outGBuffer0 : SV_Target0;    // RT0: diffuse color (rgb), occlusion (a) - sRGB rendertarget
    half4 outGBuffer1 : SV_Target1;    // RT1: spec color (rgb), smoothness (a) - sRGB rendertarget
    half4 outGBuffer2 : SV_Target2;    // RT2: normal (rgb), --unused, very low precision-- (a)
    half4 outEmission : SV_Target3;    // RT3: emission (rgb), --unused-- (a)
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    half4 outShadowMask : SV_Target4;  // RT4: shadowmask (rgba)
#endif
};

inline void SetupDummyData (out FragOutputDeferred o) {
    UNITY_INITIALIZE_OUTPUT(FragOutputDeferred, o);
    o.outGBuffer0 = 1;
    o.outGBuffer1 = 1;
    o.outGBuffer2 = 0;
    o.outEmission = 0;
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    o.outShadowMask = 1;
#endif
}

#endif // COMMON_CG_INCLUDED