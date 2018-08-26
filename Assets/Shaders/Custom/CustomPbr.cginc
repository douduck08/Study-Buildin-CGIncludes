#ifndef CUSTOM_PBR_INCLUDED
#define CUSTOM_PBR_INCLUDED

#include "UnityCG.cginc"
#include "../Includes/CommonCG.cginc"

struct v2f {
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

float4 _Color;
sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _DetailTex;
float4 _DetailTex_ST;

void vert (appdata_full v, out v2f o) {
    UNITY_INITIALIZE_OUTPUT (v2f, o);
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.uv.zw = TRANSFORM_TEX(v.texcoord, _DetailTex);
    o.normal = UnityObjectToWorldNormal(v.normal);
}

// forward path
float4 fragForward (v2f i) : SV_TARGET {
    UNITY_SETUP_INSTANCE_ID(i);

    float4 albedo = tex2D(_MainTex, i.uv.xy);
    float4 detail = tex2D(_DetailTex, i.uv.zw);
    float4 color = albedo * detail * _Color;

    i.normal = normalize(i.normal);
    
    return float4(NOTMAL_TO_COLOR(i.normal), 1);
}

#endif // CUSTOM_PBR_INCLUDED