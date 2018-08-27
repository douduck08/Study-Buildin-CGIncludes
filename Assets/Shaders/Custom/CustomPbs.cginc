#ifndef CUSTOM_PBS_INCLUDED
#define CUSTOM_PBS_INCLUDED

#include "UnityCG.cginc"
#include "UnityPBSLighting.cginc"

#include "../Includes/CommonCG.cginc"

struct v2f {
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;
    float3 worldPos : TEXCOORD2;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

float4 _Color;
float _Metallic;
float _Smoothness;

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
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
}

// forward path: simple Blinn-Phong model
float4 fragForwardSimple (v2f i) : SV_TARGET {
    UNITY_SETUP_INSTANCE_ID(i);

    float3 main = tex2D(_MainTex, i.uv.xy).rgb;
    float3 detail = tex2D(_DetailTex, i.uv.zw).rgb;
    float3 albedo = main * detail * _Color.rgb;
    float3 specColor;
    float oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, /*out*/specColor, /*out*/oneMinusReflectivity);

    i.normal = normalize(i.normal);
    // return float4(NOTMAL_TO_COLOR(i.normal), 1);

    float3 lightDir = _WorldSpaceLightPos0.xyz;
    float3 lightColor = _LightColor0.rgb;
    float3 diffuse = albedo * lightColor * saturate(dot(lightDir, i.normal));

    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);
    float3 halfDir = normalize(lightDir + viewDir);
    float3 spec = specColor * pow(saturate(dot(halfDir, i.normal)), _Smoothness * 128);

    return float4(spec + diffuse, 1);
}

// forward path: pbs model
float4 fragForwardPbs (v2f i) : SV_TARGET {
    UNITY_SETUP_INSTANCE_ID(i);

    float3 main = tex2D(_MainTex, i.uv.xy).rgb;
    float3 detail = tex2D(_DetailTex, i.uv.zw).rgb;
    float3 albedo = main * detail * _Color.rgb;

    float3 specColor;
    float oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, /*out*/specColor, /*out*/oneMinusReflectivity);

    i.normal = normalize(i.normal);
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

    UnityLight light;
    light.color = _LightColor0.rgb;
    light.dir = _WorldSpaceLightPos0.xyz;
    light.ndotl = saturate(dot(i.normal, light.dir));

    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    return UNITY_BRDF_PBS(albedo, specColor, oneMinusReflectivity, _Smoothness, i.normal, viewDir, light, indirectLight);
}

#endif // CUSTOM_PBS_INCLUDED