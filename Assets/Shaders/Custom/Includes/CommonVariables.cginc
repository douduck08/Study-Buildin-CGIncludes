#ifndef COMMON_VARIABLES_INCLUDED
#define COMMON_VARIABLES_INCLUDED

struct PBSCommonData {
    half alpha;
    half3 diffColor, specColor;
    // Note: smoothness & oneMinusReflectivity for optimization purposes, mostly for DX9 SM2.0 level.
    // Most of the math is being done on these (1-x) values, and that saves a few precious ALU slots.
    half oneMinusReflectivity, smoothness;

    float3 normalWorld;
    float3 viewDir;
    float3 posWorld;

    // #if UNITY_STANDARD_SIMPLE
    //     half3 reflUVW;
    // #endif

    // #if UNITY_STANDARD_SIMPLE
    //     half3 tangentSpaceNormal;
    // #endif
};

#endif // COMMON_VARIABLES_INCLUDED