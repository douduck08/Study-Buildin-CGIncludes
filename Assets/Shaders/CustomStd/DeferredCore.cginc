#ifndef DEFERRED_CORE_INCLUDED
#define DEFERRED_CORE_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityStandardInput.cginc"

#include "../Includes/CommonCG.cginc"
#include "../Includes/StandardGIHelper.cginc"

// -------------------------------------------------------------------
// Define data structure VertOutputDeferred
// -------------------------------------------------------------------
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

// some helper function to set data to VertOutputDeferred
inline void SetupPosWorld (inout VertOutputDeferred o, float4 posWorld) {
    #if UNITY_REQUIRE_FRAG_WORLDPOS
        #if UNITY_PACK_WORLDPOS_WITH_TANGENT
            o.tangentToWorldAndPackedData[0].w = posWorld.x;
            o.tangentToWorldAndPackedData[1].w = posWorld.y;
            o.tangentToWorldAndPackedData[2].w = posWorld.z;
        #else
            o.posWorld = posWorld.xyz;
        #endif
    #endif
}

inline void SetupNormalWorld (inout VertOutputDeferred o, float3 normalWorld) {
    o.tangentToWorldAndPackedData[0].xyz = 0;
    o.tangentToWorldAndPackedData[1].xyz = 0;
    o.tangentToWorldAndPackedData[2].xyz = normalWorld;
}

inline void SetupTangentToWorld (inout VertOutputDeferred o, float3 normalWorld, float4 tangentWorld, float3 binormalWorld) {
    o.tangentToWorldAndPackedData[0].xyz = tangentWorld.xyz;
    o.tangentToWorldAndPackedData[1].xyz = binormalWorld;
    o.tangentToWorldAndPackedData[2].xyz = normalWorld;
}

inline void SetupViewDirForParallax (inout VertOutputDeferred o, float3 viewDirForParallax) {
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

// some helper function to get data from VertOutputDeferred
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

// -------------------------------------------------------------------
// Define helper for FragOutputDeferred
// -------------------------------------------------------------------
// Data info of GBuffer
// RT0: diffuse color (rgb), occlusion (a) - sRGB rendertarget
// RT1: spec color (rgb), smoothness (a) - sRGB rendertarget
// RT2: normal (rgb), --unused, very low precision-- (a)

inline FragOutputDeferred SetupFragOutputDeferred (PBSCommonData data, half4 emissiveColor) {
    FragOutputDeferred o;
    UNITY_INITIALIZE_OUTPUT(FragOutputDeferred, o);
    o.outGBuffer0 = half4(data.diffColor, data.occlusion);
    o.outGBuffer1 = half4(data.specColor, data.smoothness);
    o.outGBuffer2 = half4(data.normalWorld * 0.5f + 0.5f, 1.0f);
    o.outEmission = emissiveColor;
    return o;
}

inline FragOutputDeferred SetupFragOutputDeferred (PBSCommonData data, half3 emissiveColor) {
    return SetupFragOutputDeferred (data, half4(emissiveColor, 1));
}

// -------------------------------------------------------------------
// Standard Deferred Pass vertex/fragment shader
// -------------------------------------------------------------------

// use the vertex input data define in UnityStandardInput:
// struct VertexInput {
//     float4 vertex   : POSITION;
//     half3 normal    : NORMAL;
//     float2 uv0      : TEXCOORD0;
//     float2 uv1      : TEXCOORD1;
// #if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
//     float2 uv2      : TEXCOORD2;
// #endif
// #ifdef _TANGENT_TO_WORLD
//     half4 tangent   : TANGENT;
// #endif
//     UNITY_VERTEX_INPUT_INSTANCE_ID
// };

void vertDeferred (VertexInput v, out VertOutputDeferred o) {
    UNITY_INITIALIZE_OUTPUT(VertOutputDeferred, o);
    SETUP_INSTANCE_DATA_VERTEX(v, o);

    float4 posWorld = POSITION_IN_WORLD;
    o.pos = UnityObjectToClipPos(v.vertex);
    o.tex = TexCoords(v);
    o.viewDir = NORMALIZE_PER_VERTEX(_WorldSpaceCameraPos - posWorld.xyz);
    SetupPosWorld(o, posWorld);

    float3 normalWorld = NORMAL_IN_WORLD;

    #ifdef _TANGENT_TO_WORLD
        float4 tangentWorld = TANGENT_IN_WORLD;
        float3 binormalWorld = BINORMAL_IN_WORLD(normalWorld, tangentWorld);
        SetupTangentToWorld(o, normalWorld, tangentWorld, binormalWorld);
    #else
        SetupNormalWorld(o, normalWorld);
    #endif

    #ifdef _PARALLAXMAP
        float3x3 rotation = GetObjectToTangentRotation(v.normal, v.tangent, BINORMAL_IN_OBJECT);
        float3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
        SetupViewDirForParallax(o, viewDirForParallax);
    #endif

    SetupLightmapUV (o, normalWorld);
}

void fragDeferred (VertOutputDeferred i, out FragOutputDeferred o) {
    #if (SHADER_TARGET < 30)
        SetupDummyData(/*out*/o)
        return;
    #endif

    SETUP_INSTANCE_DATA_PIXEL(i);

    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy); // apply dither and clip

    i.tex = Parallax(i.tex, GET_VIEW_DIR_IN_TANGENT(i)); // apply height map

    // alpha test and clip
    half alpha = Alpha(i.tex.xy);
    #if defined(_ALPHATEST_ON)
        clip (alpha - _Cutoff);
    #endif

    // Setup PBSCommonData
    DECLARE_STRUCT(PBSCommonData, pbsData);
    pbsData.occlusion = Occlusion(i.tex.xy);

    half2 metallicGloss = MetallicGloss(i.tex.xy);
    half metallic = metallicGloss.x;
    pbsData.smoothness = metallicGloss.y;
    pbsData.diffColor = DiffuseAndSpecularFromMetallic (Albedo(i.tex), metallic, /*out*/ pbsData.specColor, /*out*/ pbsData.oneMinusReflectivity);
    pbsData.diffColor = PreMultiplyAlpha (pbsData.diffColor, alpha, pbsData.oneMinusReflectivity, /*out*/ alpha);

    pbsData.posWorld = GET_POSITION_IN_WORLD(i);
    pbsData.normalWorld = GET_NORMAL_IN_WORLD(i);
    pbsData.viewDir = NORMALIZE_PER_PIXEL(i.viewDir);

    // GI
    UnityGIInput giInput = PrepareUnityGIInput(pbsData, i.ambientOrLightmapUV);

    #if UNITY_ENABLE_REFLECTION_BUFFERS
        Unity_GlossyEnvironmentData g = SetupGlossyEnvironmentData(pbsData);
        UnityGI gi = GlobalIllumination (giInput, pbsData.occlusion, pbsData.normalWorld, g);
    #else
        UnityGI gi = GlobalIllumination (giInput, pbsData.occlusion, pbsData.normalWorld);
    #endif

    // PBS model
    half3 emissiveColor = BRDF1_Unity_PBS (pbsData.diffColor, pbsData.specColor, pbsData.oneMinusReflectivity, pbsData.smoothness, pbsData.normalWorld, pbsData.viewDir, gi.light, gi.indirect).rgb;

    #ifdef _EMISSION
        emissiveColor += Emission (i.tex.xy);
    #endif

    #ifndef UNITY_HDR_ON
        emissiveColor.rgb = exp2(-emissiveColor.rgb);
    #endif

    o = SetupFragOutputDeferred (pbsData, emissiveColor);

    // Baked direct lighting occlusion if any
    #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
        o.outShadowMask = UnityGetRawBakedOcclusions(i.ambientOrLightmapUV.xy, IN_WORLDPOS(i));
    #endif
}

#endif // DEFERRED_CORE_INCLUDED