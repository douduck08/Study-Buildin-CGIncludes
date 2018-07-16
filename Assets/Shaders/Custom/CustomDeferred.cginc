#include "UnityCG.cginc"
#include "UnityStandardInput.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityStandardBRDF.cginc"
#include "UnityPBSLighting.cginc"

#include "Includes/CommonVariables.cginc"
#include "Includes/CommonUtils.cginc"
#include "Includes/GIHelper.cginc"

// define in UnityStandardInput:
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

struct VertexOutputDeferred {
    float4 pos                            : SV_POSITION;
    float4 tex                            : TEXCOORD0;
    float3 viewDir                        : TEXCOORD1;
    float4 tangentToWorldAndPackedData[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
    half4 ambientOrLightmapUV             : TEXCOORD5;    // SH or Lightmap UVs
    #if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
        float3 posWorld                   : TEXCOORD6;
    #endif
};

VertexOutputDeferred vertDeferred (VertexInput v) {
    UNITY_SETUP_INSTANCE_ID(v);
    INITIALIZE_STRUCT(VertexOutputDeferred, o);

    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
    o.pos = UnityObjectToClipPos(v.vertex);
    o.tex = TexCoords(v);
    o.viewDir = NormalizePerVertexNormal(_WorldSpaceCameraPos - posWorld.xyz);

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

    // o.tangentToWorldAndPackedData[3]
    GET_NORMAL_IN_WORLD(v, normalWorld);
    #ifdef _TANGENT_TO_WORLD
        GET_TANGENT_IN_WORLD(v, tangentWorld);
        GET_TANGENT_TO_WORLD_ROTATION(normalWorld, tangentWorld, tangentToWorldRotation);
        o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
        o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
        o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];
    #else
        o.tangentToWorldAndPackedData[0].xyz = 0;
        o.tangentToWorldAndPackedData[1].xyz = 0;
        o.tangentToWorldAndPackedData[2].xyz = normalWorld;
    #endif

    #ifdef _PARALLAXMAP
        GET_WORLD_TO_TANGENT_ROTATION(v, rotation);
        half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
        o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
        o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
        o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
    #endif

    // o.ambientOrLightmapUV
    o.ambientOrLightmapUV = 0;
    #ifdef LIGHTMAP_ON
        o.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
    #elif UNITY_SHOULD_SAMPLE_SH
        o.ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, o.ambientOrLightmapUV.rgb);
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        o.ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif

    return o;
}

float3 UnpackedNormalInWorld (float4 tex, float4 tangentToWorld[3]) {
#ifdef _NORMALMAP
    half3 tangent = tangentToWorld[0].xyz;
    half3 binormal = tangentToWorld[1].xyz;
    half3 normal = tangentToWorld[2].xyz;

    #if UNITY_TANGENT_ORTHONORMALIZE
        normal = NormalizePerPixelNormal(normal);
        // ortho-normalize Tangent
        tangent = normalize (tangent - normal * dot(tangent, normal));
        // recalculate Binormal
        half3 newB = cross(normal, tangent);
        binormal = newB * sign (dot (newB, binormal));
    #endif

    half3 normalTangent = NormalInTangentSpace(tex);
    float3 normalWorld = NormalizePerPixelNormal(tangent * normalTangent.x + binormal * normalTangent.y + normal * normalTangent.z);
#else
    float3 normalWorld = normalize(tangentToWorld[2].xyz);
#endif
    return normalWorld;
}

void fragDeferred (VertexOutputDeferred i,
    out half4 outGBuffer0 : SV_Target0, out half4 outGBuffer1 : SV_Target1, out half4 outGBuffer2 : SV_Target2,
    out half4 outEmission : SV_Target3      // RT3: emission (rgb), --unused-- (a)
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    , out half4 outShadowMask : SV_Target4  // RT4: shadowmask (rgba)
#endif
) {
    #if (SHADER_TARGET < 30)
        outGBuffer0 = 1;
        outGBuffer1 = 1;
        outGBuffer2 = 0;
        outEmission = 0;
        #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
            outShadowMask = 1;
        #endif
        return;
    #endif

    // apply dither and clip
    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

    // apply height map
    #ifdef _PARALLAXMAP
        float3 viewDirForParallax = NormalizePerPixelNormal(float3(i.tangentToWorldAndPackedData[0].w, i.tangentToWorldAndPackedData[1].w, i.tangentToWorldAndPackedData[2].w));
    #else
        float3 viewDirForParallax = half3(0,0,0);
    #endif
    i.tex = Parallax(i.tex, viewDirForParallax);

    // alpha test and clip
    half alpha = Alpha(i.tex.xy);
    #if defined(_ALPHATEST_ON)
        clip (alpha - _Cutoff);
    #endif

    // Setup PBSCommonData
    INITIALIZE_STRUCT(PBSCommonData, pbsData);
    half2 metallicGloss = MetallicGloss(i.tex.xy);
    half metallic = metallicGloss.x;
    pbsData.smoothness = metallicGloss.y;
    pbsData.diffColor = DiffuseAndSpecularFromMetallic (Albedo(i.tex), metallic, /*out*/ pbsData.specColor, /*out*/ pbsData.oneMinusReflectivity);
    pbsData.diffColor = PreMultiplyAlpha (pbsData.diffColor, alpha, pbsData.oneMinusReflectivity, /*out*/ pbsData.alpha);

    // Setup normalWorld, viewDir, posWorld
    float3 normalWorld = UnpackedNormalInWorld(i.tex, i.tangentToWorldAndPackedData);
    float3 viewDir = NormalizePerPixelNormal(i.viewDir);
    #if UNITY_REQUIRE_FRAG_WORLDPOS
        #if UNITY_PACK_WORLDPOS_WITH_TANGENT
            float3 posWorld = half3(i.tangentToWorldAndPackedData[0].w, i.tangentToWorldAndPackedData[1].w, i.tangentToWorldAndPackedData[2].w);
        #else
            float3 posWorld = i.posWorld;
        #endif
    #else
        float3 posWorld = half3(0,0,0);
    #endif

    // GI
    INITIALIZE_STRUCT(UnityLight, dummyLight); // prepare an empty UnityLight, but no analytic input in this pass
    half atten = 1;
    half occlusion = Occlusion(i.tex.xy);
    UnityGIInput giInput = PrepareUnityGIInput(posWorld, viewDir, occlusion, i.ambientOrLightmapUV, atten, dummyLight);

    #if UNITY_ENABLE_REFLECTION_BUFFERS
        Unity_GlossyEnvironmentData g = UnityGlossyEnvironmentSetup(pbsData.smoothness, viewDir, normalWorld, pbsData.specColor);
        UnityGI gi = UnityGlobalIllumination (giInput, occlusion, normalWorld, g);
    #else
        UnityGI gi = UnityGlobalIllumination (giInput, occlusion, normalWorld);
    #endif

    // PBS model
    half3 emissiveColor = BRDF1_Unity_PBS (pbsData.diffColor, pbsData.specColor, pbsData.oneMinusReflectivity, pbsData.smoothness, normalWorld, viewDir, gi.light, gi.indirect).rgb;

    #ifdef _EMISSION
        emissiveColor += Emission (i.tex.xy);
    #endif

    #ifndef UNITY_HDR_ON
        emissiveColor.rgb = exp2(-emissiveColor.rgb);
    #endif

    UnityStandardData data;
    data.diffuseColor   = pbsData.diffColor;
    data.occlusion      = occlusion;
    data.specularColor  = pbsData.specColor;
    data.smoothness     = pbsData.smoothness;
    data.normalWorld    = normalWorld;

    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    // Emissive lighting buffer
    outEmission = half4(emissiveColor, 1);

    // Baked direct lighting occlusion if any
    #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
        outShadowMask = UnityGetRawBakedOcclusions(i.ambientOrLightmapUV.xy, IN_WORLDPOS(i));
    #endif
}