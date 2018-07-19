#ifndef LIGHTING_HELPER_INCLUDED
#define LIGHTING_HELPER_INCLUDED

#include "UnityCG.cginc"
#include "UnityStandardInput.cginc"
#include "UnityShaderVariables.cginc"
#include "UnityPBSLighting.cginc"

struct PBSCommonData {
    half alpha, occlusion;
    half oneMinusReflectivity, smoothness;
    half3 diffColor, specColor;

    float3 normalWorld;
    float3 viewDir;
    float3 posWorld;
};

// Prepare UnityGIInput for UnityGlobalIllumination()
inline UnityGIInput PrepareUnityGIInput (float3 posWorld, float3 viewDir, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light) {
    UnityGIInput d;
    d.light = light;
    d.worldPos = posWorld;
    d.worldViewDir = viewDir;
    d.atten = atten;
    #if defined(LIGHTMAP_ON) || defined(DYNAMICLIGHTMAP_ON)
        d.ambient = 0;
        d.lightmapUV = i_ambientOrLightmapUV;
    #else
        d.ambient = i_ambientOrLightmapUV.rgb;
        d.lightmapUV = 0;
    #endif

    d.probeHDR[0] = unity_SpecCube0_HDR;
    d.probeHDR[1] = unity_SpecCube1_HDR;
    #if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION)
      d.boxMin[0] = unity_SpecCube0_BoxMin; // .w holds lerp value for blending
    #endif
    #ifdef UNITY_SPECCUBE_BOX_PROJECTION
      d.boxMax[0] = unity_SpecCube0_BoxMax;
      d.probePosition[0] = unity_SpecCube0_ProbePosition;
      d.boxMax[1] = unity_SpecCube1_BoxMax;
      d.boxMin[1] = unity_SpecCube1_BoxMin;
      d.probePosition[1] = unity_SpecCube1_ProbePosition;
    #endif

    return d;
}

inline UnityGIInput PrepareUnityGIInput (PBSCommonData data, half4 i_ambientOrLightmapUV, half atten, UnityLight light) {
    return PrepareUnityGIInput (data.posWorld, data.viewDir, data.occlusion, i_ambientOrLightmapUV, atten, light);
}

inline UnityGIInput PrepareUnityGIInput (PBSCommonData data, half4 i_ambientOrLightmapUV) {
    UnityLight dummyLight; // prepare an empty UnityLight, but no analytic input in this pass
    UNITY_INITIALIZE_OUTPUT(UnityLight, dummyLight);
    return PrepareUnityGIInput (data.posWorld, data.viewDir, data.occlusion, i_ambientOrLightmapUV, 1, dummyLight);
}

inline Unity_GlossyEnvironmentData SetupGlossyEnvironmentData (PBSCommonData data) {
    return UnityGlossyEnvironmentSetup(data.smoothness, data.viewDir, data.normalWorld, data.specColor);
}

// -------------------------------------------------------------------
// Prepare for modifying custom Unity GI
// -------------------------------------------------------------------
#ifndef GI_BASE
    #define GI_BASE UnityGI_Base
#endif

#ifndef GI_INDIRECT_SPECULAR
    #define GI_INDIRECT_SPECULAR UnityGI_IndirectSpecular
#endif

inline UnityGI GlobalIllumination (UnityGIInput data, half occlusion, half3 normalWorld) {
    return GI_BASE(data, occlusion, normalWorld);
}

inline UnityGI GlobalIllumination (UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn) {
    UnityGI o_gi = GI_BASE(data, occlusion, normalWorld);
    o_gi.indirect.specular = GI_INDIRECT_SPECULAR(data, occlusion, glossIn);
    return o_gi;
}

#endif // LIGHTING_HELPER_INCLUDED