#include "UnityCG.cginc"
#include "UnityInstancing.cginc"
#include "UnityStandardInput.cginc"
#include "UnityStandardConfig.cginc"
#include "UnityStandardBRDF.cginc"
#include "UnityPBSLighting.cginc"

#include "Includes/CommonCG.cginc"
#include "Includes/CommonVariables.cginc"
#include "Includes/DeferredCore.cginc"
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

void vertDeferred (VertexInput v, out VertOutputDeferred o) {
    UNITY_INITIALIZE_OUTPUT(VertOutputDeferred, o);
    SETUP_INSTANCE_DATA_VERTEX(v, o);

    SETUP_POSITION_IN_WORLD(posWorld);
    SETUP_NORMAL_IN_WORLD(normalWorld);
    #ifdef _TANGENT_TO_WORLD
        SETUP_TANGENT_IN_WORLD(tangentWorld);  // not always need
    #else
        float4 tangentWorld = 0;
    #endif

    o.pos = UnityObjectToClipPos(v.vertex);
    o.tex = TexCoords(v);
    o.viewDir = NORMALIZE_PER_VERTEX(_WorldSpaceCameraPos - posWorld.xyz);

    #ifdef _PARALLAXMAP
        GET_OBJECT_TO_TANGENT_ROTATION(v, rotation);
        float3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
        SetupPackedData(o, posWorld, normalWorld, tangentWorld, viewDirForParallax);
    #else
        #ifdef _TANGENT_TO_WORLD
        SetupPackedData(o, posWorld, normalWorld, tangentWorld, float3(0, 0, 0));
    #endif

    // setup o.ambientOrLightmapUV
    SetupLightmapUV (o, normalWorld);
}

void fragDeferred (VertOutputDeferred i, out FragOutputDeferred o) {
    #if (SHADER_TARGET < 30)
        o = DummyFragOutputDeferred();
        return;
    #endif

    SETUP_INSTANCE_DATA_PIXEL(i);

    // apply dither and clip
    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

    // apply height map
    i.tex = Parallax(i.tex, GET_VIEW_DIR_IN_TANGENT(i));

    // alpha test and clip
    half alpha = Alpha(i.tex.xy);
    #if defined(_ALPHATEST_ON)
        clip (alpha - _Cutoff);
    #endif

    // Setup PBSCommonData
    DECLARE_STRUCT(PBSCommonData, pbsData);
    half2 metallicGloss = MetallicGloss(i.tex.xy);
    half metallic = metallicGloss.x;
    pbsData.smoothness = metallicGloss.y;
    pbsData.diffColor = DiffuseAndSpecularFromMetallic (Albedo(i.tex), metallic, /*out*/ pbsData.specColor, /*out*/ pbsData.oneMinusReflectivity);
    pbsData.diffColor = PreMultiplyAlpha (pbsData.diffColor, alpha, pbsData.oneMinusReflectivity, /*out*/ pbsData.alpha);

    // Get posWorld, normalWorld, viewDir
    float3 posWorld = GET_POSITION_IN_WORLD(i);
    float3 normalWorld = GET_NORMAL_IN_WORLD(i);
    float3 viewDir = NORMALIZE_PER_PIXEL(i.viewDir);

    // GI
    DECLARE_STRUCT(UnityLight, dummyLight); // prepare an empty UnityLight, but no analytic input in this pass
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

    UnityStandardDataToGbuffer(data, o.outGBuffer0, o.outGBuffer1, o.outGBuffer2);

    // Emissive lighting buffer
    o.outEmission = half4(emissiveColor, 1);

    // Baked direct lighting occlusion if any
    #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
        o.outShadowMask = UnityGetRawBakedOcclusions(i.ambientOrLightmapUV.xy, IN_WORLDPOS(i));
    #endif
}