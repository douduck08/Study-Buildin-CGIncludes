// Upgrade NOTE: replaced 'mul(UNITY_MATRIX_MVP,*)' with 'UnityObjectToClipPos(*)'

#ifndef CUSTOM_SHADOW_INCLUDED
#define CUSTOM_SHADOW_INCLUDED

#include "UnityCG.cginc"

struct appdata {
    float4 position : POSITION;
    float3 normal : NORMAL;
};

#if defined(SHADOWS_CUBE)
struct v2f {
    float4 position : SV_POSITION;
    float3 lightVec : TEXCOORD0;
};

v2f vertShadow (appdata v) {
    v2f o;
    o.position = UnityObjectToClipPos(v.position);
    o.lightVec = mul(unity_ObjectToWorld, v.position).xyz - _LightPositionRange.xyz;
    return o;
}

half4 fragShadow (v2f i) : SV_TARGET {
    float depth = length(i.lightVec) + unity_LightShadowBias.x;
    depth *= _LightPositionRange.w;
    return UnityEncodeCubeShadowDepth(depth);
}

#else // SHADOWS_DEPTH
float4 vertShadow (appdata v) : SV_POSITION {
    float4 position = UnityClipSpaceShadowCasterPos(v.position.xyz, v.normal);
    return UnityApplyLinearShadowBias(position);
}

half4 fragShadow () : SV_TARGET {
    return 0;
}
#endif

#endif // CUSTOM_SHADOW_INCLUDED
