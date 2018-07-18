#ifndef DEFERRED_CORE_INCLUDED
#define DEFERRED_CORE_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityStandardInput.cginc"

#include "CommonCG.cginc"

// define data structures
struct VertOutputDeferred {
    float4 pos                            : SV_POSITION;
    float4 tex                            : TEXCOORD0;
    float3 viewDir                        : TEXCOORD1;
    float4 tangentToWorldAndPackedData[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
    half4 ambientOrLightmapUV             : TEXCOORD5;    // SH or Lightmap UVs
    #if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
        float3 posWorld                   : TEXCOORD6;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

inline void SetupPackedData (inout VertOutputDeferred o, float4 posWorld, float3 normalWorld, float4 tangentWorld, float3 viewDirForParallax) {
    // position in world space
    #if UNITY_REQUIRE_FRAG_WORLDPOS
        #if UNITY_PACK_WORLDPOS_WITH_TANGENT
            o.tangentToWorldAndPackedData[0].w = posWorld.x;
            o.tangentToWorldAndPackedData[1].w = posWorld.y;
            o.tangentToWorldAndPackedData[2].w = posWorld.z;
        #else
            o.posWorld = posWorld.xyz;
        #endif
    #endif

    // tangent to world rotation
    #ifdef _TANGENT_TO_WORLD
        GET_TANGENT_TO_WORLD_ROTATION(normalWorld, tangentWorld, tangentToWorldRotation);
        o.tangentToWorldAndPackedData[0].xyz = tangentToWorldRotation[0];
        o.tangentToWorldAndPackedData[1].xyz = tangentToWorldRotation[1];
        o.tangentToWorldAndPackedData[2].xyz = tangentToWorldRotation[2];
    #else
        o.tangentToWorldAndPackedData[0].xyz = 0;
        o.tangentToWorldAndPackedData[1].xyz = 0;
        o.tangentToWorldAndPackedData[2].xyz = normalWorld;
    #endif

    // view dir in tangent
    #ifdef _PARALLAXMAP
        o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
        o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
        o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
    #endif
}

inline void SetupLightmapUV (inout VertOutputDeferred o, float3 normalWorld) {
    #ifdef LIGHTMAP_ON
        o.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
    #elif UNITY_SHOULD_SAMPLE_SH
        o.ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, o.ambientOrLightmapUV.rgb);
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        o.ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif
}

struct FragOutputDeferred {
    half4 outGBuffer0 : SV_Target0;
    half4 outGBuffer1 : SV_Target1;
    half4 outGBuffer2 : SV_Target2;
    half4 outEmission : SV_Target3;    // RT3: emission (rgb), --unused-- (a)
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    half4 outShadowMask : SV_Target4;  // RT4: shadowmask (rgba)
#endif
};

inline FragOutputDeferred DummyFragOutputDeferred () {
    FragOutputDeferred o;
    UNITY_INITIALIZE_OUTPUT(FragOutputDeferred, o);
    o.outGBuffer0 = 1;
    o.outGBuffer1 = 1;
    o.outGBuffer2 = 0;
    o.outEmission = 0;
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    o.outShadowMask = 1;
#endif
    return o;
}

// some help function to set or get data
// Get normal in world space
float3 UnpackedNormalInWorld (float4 tex, float4 tangentToWorld[3]) {
#ifdef _NORMALMAP
    half3 tangent = tangentToWorld[0].xyz;
    half3 binormal = tangentToWorld[1].xyz;
    half3 normal = tangentToWorld[2].xyz;

    #if UNITY_TANGENT_ORTHONORMALIZE
        normal = NORMALIZE_PER_PIXEL(normal);
        // ortho-normalize Tangent
        tangent = normalize (tangent - normal * dot(tangent, normal));
        // recalculate Binormal
        half3 newB = cross(normal, tangent);
        binormal = newB * sign (dot (newB, binormal));
    #endif

    half3 normalTangent = NormalInTangentSpace(tex);  // sample nomal textures
    float3 normalWorld = NORMALIZE_PER_PIXEL(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z);
#else
    float3 normalWorld = normalize(tangentToWorld[2].xyz);
#endif
    return normalWorld;
}

#define GET_NORMAL_IN_WORLD(i) UnpackedNormalInWorld(i.tex, i.tangentToWorldAndPackedData)

// Get position in world space
#if UNITY_REQUIRE_FRAG_WORLDPOS
    #if UNITY_PACK_WORLDPOS_WITH_TANGENT
        #define GET_POSITION_IN_WORLD(i) float3(i.tangentToWorldAndPackedData[0].w, i.tangentToWorldAndPackedData[1].w, i.tangentToWorldAndPackedData[2].w)
    #else
        #define GET_POSITION_IN_WORLD(i) i.posWorld
    #endif
#else
    GET_POSITION_IN_WORLD(i) half3(0,0,0)
#endif

#ifdef _PARALLAXMAP
    #define GET_VIEW_DIR_IN_TANGENT(i) NORMALIZE_PER_PIXEL(float3(i.tangentToWorldAndPackedData[0].w, i.tangentToWorldAndPackedData[1].w, i.tangentToWorldAndPackedData[2].w))
#else
    #define GET_VIEW_DIR_IN_TANGENT(i) half3(0,0,0)
#endif

#endif // DEFERRED_CORE_INCLUDED