#ifndef FULL_REWRITE_INCLUDED
#define FULL_REWRITE_INCLUDED

#include "UnityCG.cginc"
#include "Includes/CommonCG.cginc"

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
    
    return color;
}

// deferred path
void fragDeferred (v2f i, out FragOutputDeferred o) {
    UNITY_SETUP_INSTANCE_ID(i);

    float4 albedo = tex2D(_MainTex, i.uv.xy);
    float4 detail = tex2D(_DetailTex, i.uv.zw);
    float4 color = albedo * detail * _Color;

    i.normal = normalize(i.normal);

    UNITY_INITIALIZE_OUTPUT (FragOutputDeferred, o);
    o.outGBuffer0 = half4(color.rgb, 0);
    o.outGBuffer1 = half4(i.normal, 0.5);
    o.outGBuffer2 = half4(0, 0, 0, 1.0);
    o.outEmission = half4(0, 0, 0, 0);
}

#endif // FULL_REWRITE_INCLUDED