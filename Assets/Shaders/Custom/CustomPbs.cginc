#ifndef CUSTOM_PBS_INCLUDED
#define CUSTOM_PBS_INCLUDED

#include "UnityCG.cginc"
#include "AutoLight.cginc"
#include "UnityPBSLighting.cginc"

#include "../Includes/CommonCG.cginc"

struct v2f {
    float4 pos : SV_POSITION;
    float4 uv : TEXCOORD0;
    float3 normal : TEXCOORD1;
    #if defined(BINORMAL_PER_FRAGMENT)
        float4 tangent : TEXCOORD2;
    #else
        float3 tangent : TEXCOORD2;
        float3 binormal : TEXCOORD3;
    #endif
    float3 worldPos : TEXCOORD4;
    #if defined(VERTEXLIGHT_ON)
        float3 vertexLightColor : TEXCOORD5;
    #endif
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

float4 _Color;
float _Metallic;
float _Smoothness;

sampler2D _MainTex;
float4 _MainTex_ST;
sampler2D _NormalMap;
float _NormalScale;

sampler2D _DetailTex;
float4 _DetailTex_ST;
sampler2D _DetailNormalMap;
float _DetailNormalScale;

void ComputeVertexLightColor (inout v2f o) {
    #if defined(VERTEXLIGHT_ON)
        o.vertexLightColor = Shade4PointLights(
            unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
            unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
            unity_4LightAtten0, o.worldPos, o.normal
        );
    #endif
}

void vert (appdata_full v, out v2f o) {
    UNITY_INITIALIZE_OUTPUT (v2f, o);
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    o.pos = UnityObjectToClipPos(v.vertex);
    o.uv.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
    o.uv.zw = TRANSFORM_TEX(v.texcoord, _DetailTex);
    o.normal = UnityObjectToWorldNormal(v.normal);
    #if defined(BINORMAL_PER_FRAGMENT)
        o.tangent = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
    #else
        o.tangent = UnityObjectToWorldDir(v.tangent.xyz);
        o.binormal = cross(o.normal, o.tangent) * v.tangent.w * unity_WorldTransformParams.w;
    #endif
    o.worldPos = mul(unity_ObjectToWorld, v.vertex);
    #if defined(VERTEXLIGHT_ON)
        ComputeVertexLightColor(/*inout*/o);
    #endif
}

UnityLight CreateLight (v2f i) {
    UnityLight light;

    #if defined(POINT) || defined(POINT_COOKIE) || defined(SPOT)
        light.dir = normalize(_WorldSpaceLightPos0.xyz - i.worldPos);
    #else
        light.dir = _WorldSpaceLightPos0.xyz;
    #endif

    UNITY_LIGHT_ATTENUATION(atten, 0, i.worldPos);
    light.color = _LightColor0.rgb * atten;

    light.ndotl = saturate(dot(i.normal, light.dir));
    return light;
}

UnityIndirect CreateIndirectLight (v2f i) {
    UnityIndirect indirectLight;
    indirectLight.diffuse = 0;
    indirectLight.specular = 0;

    #if defined(VERTEXLIGHT_ON)
        indirectLight.diffuse = i.vertexLightColor;
    #endif

    #if defined(FORWARD_BASE_PASS)
        indirectLight.diffuse += max(0, ShadeSH9(float4(i.normal, 1)));
    #endif

    return indirectLight;
}

float4 fragForwardBase (v2f i) : SV_TARGET {
    UNITY_SETUP_INSTANCE_ID(i);

    float3 main = tex2D(_MainTex, i.uv.xy).rgb;
    float3 detail = tex2D(_DetailTex, i.uv.zw).rgb;
    float3 albedo = main * detail * _Color.rgb;

    float3 specColor;
    float oneMinusReflectivity;
    albedo = DiffuseAndSpecularFromMetallic(albedo, _Metallic, /*out*/specColor, /*out*/oneMinusReflectivity);

    float3 mainNormal = UnpackScaleNormal(tex2D(_NormalMap, i.uv.xy), _NormalScale);
    float3 detailNormal = UnpackScaleNormal(tex2D(_DetailNormalMap, i.uv.zw), _DetailNormalScale);
    float3 normal = BlendNormals(mainNormal, detailNormal);
    #if defined(BINORMAL_PER_FRAGMENT)
        float3 binormal = cross(i.normal, i.tangent.xyz) * i.tangent.w * unity_WorldTransformParams.w;
        normal = normalize(normal.x * i.tangent.xyz + normal.y * binormal + normal.z * i.normal);
    #else
        normal = normalize(normal.x * i.tangent + normal.y * i.binormal + normal.z * i.normal);
    #endif
    
    float3 viewDir = normalize(_WorldSpaceCameraPos - i.worldPos);

    UnityLight light = CreateLight(i);
    UnityIndirect indirectLight = CreateIndirectLight(i);

    return UNITY_BRDF_PBS(albedo, specColor, oneMinusReflectivity, _Smoothness, normal, viewDir, light, indirectLight);
}

#endif // CUSTOM_PBS_INCLUDED