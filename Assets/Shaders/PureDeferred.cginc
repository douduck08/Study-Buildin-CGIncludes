#include "UnityCG.cginc"
#include "UnityStandardInput.cginc"
#include "CommonCore.cginc"

// #include "UnityStandardConfig.cginc"
// #include "UnityPBSLighting.cginc"
// #include "UnityStandardUtils.cginc"
// #include "UnityGBuffer.cginc"
// #include "UnityStandardBRDF.cginc"
// #include "AutoLight.cginc"

struct VertexOutputDeferred {
    float4 pos                            : SV_POSITION;
    float4 tex                            : TEXCOORD0;
    float3 eyeVec                         : TEXCOORD1;
    float4 tangentToWorldAndPackedData[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
    half4 ambientOrLightmapUV             : TEXCOORD5;    // SH or Lightmap UVs
    #if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
        float3 posWorld                   : TEXCOORD6;
    #endif
};

struct FragmentCommonData {
    half3 diffColor, specColor;
    // Note: smoothness & oneMinusReflectivity for optimization purposes, mostly for DX9 SM2.0 level.
    // Most of the math is being done on these (1-x) values, and that saves a few precious ALU slots.
    half oneMinusReflectivity, smoothness;
    float3 normalWorld;
    float3 eyeVec;
    half alpha;
    float3 posWorld;

    #if UNITY_STANDARD_SIMPLE
        half3 reflUVW;
    #endif

    #if UNITY_STANDARD_SIMPLE
        half3 tangentSpaceNormal;
    #endif
};

// inline FragmentCommonData SpecularSetup (float4 i_tex) {
//     half4 specGloss = SpecularGloss(i_tex.xy);
//     half3 specColor = specGloss.rgb;
//     half smoothness = specGloss.a;

//     half oneMinusReflectivity;
//     half3 diffColor = EnergyConservationBetweenDiffuseAndSpecular (Albedo(i_tex), specColor, /*out*/ oneMinusReflectivity);

//     FragmentCommonData o = (FragmentCommonData)0;
//     o.diffColor = diffColor;
//     o.specColor = specColor;
//     o.oneMinusReflectivity = oneMinusReflectivity;
//     o.smoothness = smoothness;
//     return o;
// }

// inline FragmentCommonData FragmentSetup (inout float4 i_tex, float3 i_eyeVec, half3 i_viewDirForParallax, float4 tangentToWorld[3], float3 i_posWorld) {
//     i_tex = Parallax(i_tex, i_viewDirForParallax);

//     half alpha = Alpha(i_tex.xy);
//     #if defined(_ALPHATEST_ON)
//         clip (alpha - _Cutoff);
//     #endif

//     FragmentCommonData o = SpecularSetup (i_tex);
//     o.normalWorld = PerPixelWorldNormal(i_tex, tangentToWorld);
//     o.eyeVec = NormalizePerPixelNormal(i_eyeVec);
//     o.posWorld = i_posWorld;

//     // NOTE: shader relies on pre-multiply alpha-blend (_SrcBlend = One, _DstBlend = OneMinusSrcAlpha)
//     o.diffColor = PreMultiplyAlpha (o.diffColor, alpha, o.oneMinusReflectivity, /*out*/ o.alpha);
//     return o;
// }

VertexOutputDeferred vertDeferred (VertexInput v) {
    UNITY_SETUP_INSTANCE_ID(v);
    VertexOutputDeferred o;
    UNITY_INITIALIZE_OUTPUT(VertexOutputDeferred, o);

    float4 posWorld = mul(unity_ObjectToWorld, v.vertex);
    #if UNITY_REQUIRE_FRAG_WORLDPOS
        #if UNITY_PACK_WORLDPOS_WITH_TANGENT
            o.tangentToWorldAndPackedData[0].w = posWorld.x;
            o.tangentToWorldAndPackedData[1].w = posWorld.y;
            o.tangentToWorldAndPackedData[2].w = posWorld.z;
        #else
            o.posWorld = posWorld.xyz;
        #endif
    #endif

    o.pos = UnityObjectToClipPos(v.vertex);
    o.tex = TexCoords(v);
    o.eyeVec = NormalizePerVertexNormal(posWorld.xyz - _WorldSpaceCameraPos);

    float3 normalWorld = UnityObjectToWorldNormal(v.normal);
    #ifdef _TANGENT_TO_WORLD
        float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
        float3x3 tangentToWorld = CreateTangentToWorldPerVertex(normalWorld, tangentWorld.xyz, tangentWorld.w);
        o.tangentToWorldAndPackedData[0].xyz = tangentToWorld[0];
        o.tangentToWorldAndPackedData[1].xyz = tangentToWorld[1];
        o.tangentToWorldAndPackedData[2].xyz = tangentToWorld[2];
    #else
        o.tangentToWorldAndPackedData[0].xyz = 0;
        o.tangentToWorldAndPackedData[1].xyz = 0;
        o.tangentToWorldAndPackedData[2].xyz = normalWorld;
    #endif

    o.ambientOrLightmapUV = 0;
    #ifdef LIGHTMAP_ON
        o.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
    #elif UNITY_SHOULD_SAMPLE_SH
        o.ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, o.ambientOrLightmapUV.rgb);
    #endif
    #ifdef DYNAMICLIGHTMAP_ON
        o.ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
    #endif

    #ifdef _PARALLAXMAP
        TANGENT_SPACE_ROTATION;
        half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
        o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
        o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
        o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
    #endif

    return o;
}

void fragDeferred ( VertexOutputDeferred i,
    out half4 outGBuffer0 : SV_Target0, out half4 outGBuffer1 : SV_Target1, out half4 outGBuffer2 : SV_Target2,
    out half4 outEmission : SV_Target3      // RT3: emission (rgb), --unused-- (a)
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    , out half4 outShadowMask : SV_Target4  // RT4: shadowmask (rgba)
#endif
)
{
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

    UNITY_APPLY_DITHER_CROSSFADE(i.pos.xy);

    // IN_VIEWDIR4PARALLAX(i)
    #if (SHADER_TARGET < 30) || UNITY_STANDARD_SIMPLE
        half3 viewDir4Parallax = normalize(half3(i.tangentToWorldAndPackedData[0].w, i.tangentToWorldAndPackedData[1].w, i.tangentToWorldAndPackedData[2].w));
    #else
            // will normalize per-pixel instead
        half3 viewDir4Parallax = half3(i.tangentToWorldAndPackedData[0].w, i.tangentToWorldAndPackedData[1].w, i.tangentToWorldAndPackedData[2].w);
    #endif

    // IN_WORLDPOS(i)
    #if UNITY_REQUIRE_FRAG_WORLDPOS
        #if UNITY_PACK_WORLDPOS_WITH_TANGENT
            half3 in_worldPos =  half3(i.tangentToWorldAndPackedData[0].w, i.tangentToWorldAndPackedData[1].w, i.tangentToWorldAndPackedData[2].w);
        #else
            half3 in_worldPos = i.posWorld;
        #endif
    #else
        half3 in_worldPos = half3(0,0,0);
    #endif

    // FRAGMENT_SETUP(s)
    // FragmentCommonData x = FragmentSetup(i.tex, i.eyeVec, IN_VIEWDIR4PARALLAX(i), i.tangentToWorldAndPackedData, IN_WORLDPOS(i));
    FragmentCommonData s = FragmentSetup(i.tex, i.eyeVec, viewDir4Parallax, i.tangentToWorldAndPackedData, in_worldPos);

    // no analytic lights in this pass
    UnityLight dummyLight = DummyLight ();
    half atten = 1;

    // only GI
    half occlusion = Occlusion(i.tex.xy);
    #if UNITY_ENABLE_REFLECTION_BUFFERS
        bool sampleReflectionsInDeferred = false;
    #else
        bool sampleReflectionsInDeferred = true;
    #endif

    UnityGI gi = FragmentGI (s, occlusion, i.ambientOrLightmapUV, atten, dummyLight, sampleReflectionsInDeferred);

    half3 emissiveColor = UNITY_BRDF_PBS (s.diffColor, s.specColor, s.oneMinusReflectivity, s.smoothness, s.normalWorld, -s.eyeVec, gi.light, gi.indirect).rgb;

    #ifdef _EMISSION
        emissiveColor += Emission (i.tex.xy);
    #endif

    #ifndef UNITY_HDR_ON
        emissiveColor.rgb = exp2(-emissiveColor.rgb);
    #endif

    UnityStandardData data;
    data.diffuseColor   = s.diffColor;
    data.occlusion      = occlusion;
    data.specularColor  = s.specColor;
    data.smoothness     = s.smoothness;
    data.normalWorld    = s.normalWorld;

    UnityStandardDataToGbuffer(data, outGBuffer0, outGBuffer1, outGBuffer2);

    // Emissive lighting buffer
    outEmission = half4(emissiveColor, 1);

    // Baked direct lighting occlusion if any
    #if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
        outShadowMask = UnityGetRawBakedOcclusions(i.ambientOrLightmapUV.xy, IN_WORLDPOS(i));
    #endif
}