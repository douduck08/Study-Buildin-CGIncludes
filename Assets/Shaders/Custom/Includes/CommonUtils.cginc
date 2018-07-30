#ifndef COMMON_UTILS_INCLUDED
#define COMMON_UTILS_INCLUDED

#define NOTMAL_TO_COLOR(normal) normal * 0.5 + 0.5

struct FragOutputDeferred {
    half4 outGBuffer0 : SV_Target0;
    half4 outGBuffer1 : SV_Target1;
    half4 outGBuffer2 : SV_Target2;
    half4 outEmission : SV_Target3;    // RT3: emission (rgb), --unused-- (a)
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    half4 outShadowMask : SV_Target4;  // RT4: shadowmask (rgba)
#endif
};

#endif // COMMON_UTILS_INCLUDED
