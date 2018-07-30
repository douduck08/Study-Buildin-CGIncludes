#ifndef FULL_REWRITE_INCLUDED
#define FULL_REWRITE_INCLUDED

#include "UnityCG.cginc"

struct VertInput {
    float4 vertex   : POSITION;
    half3 normal    : NORMAL;
    float2 uv0      : TEXCOORD0;
    float2 uv1      : TEXCOORD1;
#if defined(DYNAMICLIGHTMAP_ON) || defined(UNITY_PASS_META)
    float2 uv2      : TEXCOORD2;
#endif
#ifdef _TANGENT_TO_WORLD
    half4 tangent   : TANGENT;
#endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
};

struct VertOutput {
    float4 pos : SV_POSITION;
    float4 tex : TEXCOORD0;
};

void vert (VertInput v, out VertOutput o) {
    UNITY_INITIALIZE_OUTPUT (VertOutput, o);
    o.pos = UnityObjectToClipPos(v.vertex);
}

float4 _Color;

// forward path
float4 fragForward (VertOutput i) : SV_TARGET {
    return _Color;
}

// deferred path
struct FragOutputDeferred {
    half4 outGBuffer0 : SV_Target0;
    half4 outGBuffer1 : SV_Target1;
    half4 outGBuffer2 : SV_Target2;
    half4 outEmission : SV_Target3;    // RT3: emission (rgb), --unused-- (a)
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    half4 outShadowMask : SV_Target4;  // RT4: shadowmask (rgba)
#endif
};

void fragDeferred (VertOutput i, out FragOutputDeferred o) {
    UNITY_INITIALIZE_OUTPUT (FragOutputDeferred, o);
    o.outGBuffer0 = half4(_Color.rgb, 0);
    o.outGBuffer1 = half4(0, 0, 0, 0.5);
    o.outGBuffer2 = half4(0, 0, 0, 1.0);
}

#endif // FULL_REWRITE_INCLUDED