# 拆解 Standard Surface Shader 為 Unlit Shader
首先轉成 Unlit Shader，內容為：[Standard.shader](Assets/Shaders/Standard.shader)。

中間的許多 Keywords 是由 CustomEditor "StandardShaderGUI" 進行變動的，切換模式或開啟貼圖等都相當於套用不同的 Shader。

> KeyWords 中的 `_` 似乎不論數量都是相同的意思。

# Standard Deferred Shader 的內容

## Keywords
* _NORMALMAP
* _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON (決定光照的 alpha blend 方式)
* _EMISSION
* _METALLICGLOSSMAP
* _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
* _ _SPECULARHIGHLIGHTS_OFF
* ___ _DETAIL_MULX2
* _PARALLAXMAP

## 一些 build-in define
定義在 "UnityStandardInput.cginc" 中，決定了透過 Keywords 開啟的功能是否要對應開啟某段 shader 功能
* `_TANGENT_TO_WORLD` 代表有使用 tangent space 的需求。相當於 `_NORMALMAP || DIRLIGHTMAP_COMBINED || _PARALLAXMAP`
* `_DETAIL` 代表有使用次級貼圖。相當於 `_DETAIL_MULX2 || _DETAIL_MUL || _DETAIL_ADD || _DETAIL_LERP`

## 相關的資料結構

### VertexInput
* 定義於 "UnityStandardInput.cginc"，其中 `UNITY_VERTEX_INPUT_INSTANCE_ID` 定義於 "UnityInstancing.cginc"
```c
struct VertexInput {
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
```

### VertexOutputDeferred
* `tex.xy` 儲存 main texture 的 uv；`tex.zw` 儲存 parallax map 的 uv。
* `eyeVec = posWorld.xyz - _WorldSpaceCameraPos`。
* `tangentToWorldAndPackedData：`
    * xyz 儲存 world space 下的 `(tangent, binormal, normal)`。
    * w 儲存了 height map 所需 object space 下的視線向量，或者 world space 的頂點座標。
* `ambientOrLightmapUV` 的 xy 是 light map 的 uv，zw 是動態 light map 的 uv。若使用 Light Probes 則存入 rgb 中。
```c
struct VertexOutputDeferred {
    float4 pos                            : SV_POSITION;
    float4 tex                            : TEXCOORD0;
    float3 eyeVec                         : TEXCOORD1;
    float4 tangentToWorldAndPackedData[3] : TEXCOORD2;    // [3x3:tangentToWorld | 1x3:viewDirForParallax or worldPos]
    half4 ambientOrLightmapUV             : TEXCOORD5;    // SH or Lightmap UVs
#if UNITY_REQUIRE_FRAG_WORLDPOS && !UNITY_PACK_WORLDPOS_WITH_TANGENT
    float3 posWorld                       : TEXCOORD6;
#endif
};
```

### FragmentCommonData
定義了 fragment shader 中需要的一些資料，會在 shader 中呼叫 `FRAGMENT_SETUP ()` 來計算準備。
```c
struct FragmentCommonData {
    half3 diffColor, specColor;
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
```

### UnityLight & UnityIndirect & UnityGI
定義於 "UnityLightingCommon.cginc"。
```c
struct UnityLight {
    half3 color;
    half3 dir;
    half ndotl; // Deprecated: Do not used it.
};

struct UnityIndirect {
    half3 diffuse;
    half3 specular;
};

struct UnityGI {
    UnityLight light;
    UnityIndirect indirect;
};
```

### UnityGIInput
定義於 "UnityLightingCommon.cginc"。
```c
struct UnityGIInput {
    UnityLight light;
    float3 worldPos;
    half3 worldViewDir;
    half atten;
    half3 ambient;

    float4 lightmapUV; // .xy = static lightmap UV, .zw = dynamic lightmap UV

#if defined(UNITY_SPECCUBE_BLENDING) || defined(UNITY_SPECCUBE_BOX_PROJECTION) || defined(UNITY_ENABLE_REFLECTION_BUFFERS)
    float4 boxMin[2];
#endif
#ifdef UNITY_SPECCUBE_BOX_PROJECTION
    float4 boxMax[2];
    float4 probePosition[2];
#endif
    // HDR cubemap properties, use to decompress HDR texture
    float4 probeHDR[2];
};
```

### Unity_GlossyEnvironmentData
定義於 "UnityLightingCommon.cginc"。
```c
struct Unity_GlossyEnvironmentData {
    half    roughness;
    half3   reflUVW;
};
```

### UnityStandardData
定義於 "UnityGBuffer.cginc"，是用於傳入 `UnityStandardDataToGbuffer()` 的結構。
```
struct UnityStandardData {
    half3   diffuseColor;
    half    occlusion;
    half3   specularColor;
    half    smoothness;
    float3  normalWorld; // normal in world space
};
```

## Vertex Shader
```c
VertexOutputDeferred vertDeferred (VertexInput v)
```
### VR Support and GPU Instancing
* `UNITY_SETUP_INSTANCE_ID(v)` 處理計算 unity_InstanceID，以及 MVP 相關矩陣。
* `UNITY_TRANSFER_INSTANCE_ID(v, o)` 將 instance ID 從 input 填入 output。
* `UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o)` 設定 VR 的左右眼資料到 output。

### 座標與UV資訊
將 `VertexOutputDeferred` 內的資料準備好，若有 `_TANGENT_TO_WORLD` 或 `LIGHTMAP_ON` 等會產生一些變化或簡化。

* `UNITY_INITIALIZE_OUTPUT(VertexOutputDeferred, o)` 會依照平台差異進行 struct 的歸零。
* `UnityObjectToClipPos(v.vertex)` 計算 clip space 座標。
* 用內建於  "UnityStandardInput.cginc" 的 `TexCoords()` 來執行 `TRANSFORM_TEX()`，同時填上兩組 uv。
* `NormalizePerVertexNormal()` 會依據平台來決定是否立即計算 normalize，或者留到 fragment shader 中計算。
* `UnityObjectToWorldNormal(v.normal)` 計算 normal，再依照 `_TANGENT_TO_WORLD` 來決定後續處理。
* 用內建於 "UnityStandardUtils.cginc" 的 `CreateTangentToWorldPerVertex()` 可用於建立 tangent to wprld matrix。

### 光照所需資訊
處理 Light Map 或動態光照的片段：
```c
#ifdef LIGHTMAP_ON
    o.ambientOrLightmapUV.xy = v.uv1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
#elif UNITY_SHOULD_SAMPLE_SH
    o.ambientOrLightmapUV.rgb = ShadeSHPerVertex (normalWorld, o.ambientOrLightmapUV.rgb);
#endif
#ifdef DYNAMICLIGHTMAP_ON
    o.ambientOrLightmapUV.zw = v.uv2.xy * unity_DynamicLightmapST.xy + unity_DynamicLightmapST.zw;
#endif
```
* `ShadeSHPerVertex()` 會計算逐頂點光照，儲存到 `ambientOrLightmapUV.rgb` 中備用。

### ViewDir in Tangent space
當有次級貼圖要使用時，會事先計算在 tangent space 下的視線方向：
```c
#ifdef _PARALLAXMAP
    TANGENT_SPACE_ROTATION;
    half3 viewDirForParallax = mul (rotation, ObjSpaceViewDir(v.vertex));
    o.tangentToWorldAndPackedData[0].w = viewDirForParallax.x;
    o.tangentToWorldAndPackedData[1].w = viewDirForParallax.y;
    o.tangentToWorldAndPackedData[2].w = viewDirForParallax.z;
#endif
```
* `TANGENT_SPACE_ROTATION` 是被定義在 "UnityCG.cginc" 的一段程式碼，會計算出 world to tangent matrix，以 rotation 為 matrix 變數名。


## Fragment Shader
在 deferred path rendering 中共需要 3 張 GBuffer、1 張 Emission 輸出，另有額外的 ShadowMask 輸出，最多共 5 個 output。
```c
void fragDeferred ( VertexOutputDeferred i,
    out half4 outGBuffer0 : SV_Target0, out half4 outGBuffer1 : SV_Target1, out half4 outGBuffer2 : SV_Target2,
    out half4 outEmission : SV_Target3      // RT3: emission (rgb), --unused-- (a)
#if defined(SHADOWS_SHADOWMASK) && (UNITY_ALLOWED_MRT_COUNT > 4)
    , out half4 outShadowMask : SV_Target4  // RT4: shadowmask (rgba)
#endif
)
```
### Dither Clip
呼叫 `UNITY_APPLY_DITHER_CROSSFADE()` 檢查 Dither Clip。

### FragmentCommonData 的計算
接著呼叫 `FRAGMENT_SETUP()` 來計算準備 `FragmentCommonData`，實際對應的方法與內容為：
```c
inline FragmentCommonData FragmentSetup (inout float4 i_tex, float3 i_eyeVec, half3 i_viewDirForParallax, float4 tangentToWorld[3], float3 i_posWorld)
```
* `Parallax()` 計算 height map 下 uv 的變化平移。
* 若有 `_ALPHATEST_ON`，執行 `clip (alpha - _Cutoff)`。
* `MetallicSetup()` 計算 `diffColor`, `specColor`, `smooth` 與 `oneMinusReflectivity`，其中：
  * `MetallicGloss()` 對 metallic 與 smoothness 進行採樣，定義於 "UnityStandardInput.cginc"。
  * `Albedo()` 對兩張貼圖顏色進行採樣，定義於 "UnityStandardInput.cginc"。
  * `DiffuseAndSpecularFromMetallic()` 計算了  `diffColor`, `specColor` 與 `oneMinusReflectivity`，定義於 "UnityStandardUtils.cginc"。
* `PerPixelWorldNormal()` 採樣 normal map 後計算 world space normal。
* `o.eyeVec` 的設值，於 `NormalizePerPixelNormal()` 內決定定是否 normalize。
* `o.posWorld` 的設值。
* 進行 `PreMultiplyAlpha()` 計算。

最後的 `PreMultiplyAlpha()` 可以避免從 ColorBuffer 讀取顏色，事先調整 alpha 與 diffColor。對應的 Blend 設定為 `_SrcBlend = One, _DstBlend = OneMinusSrcAlpha`，這同時也跟 Deferred Path 無法正常渲染沒有 ZWrite 的透明物件有關。

完成 `FragmentCommonData` 後，建立一個 `UnityLight` 結構，並進行了歸零的初始化動作。在 Deferred Path 並不需要在這部分寫入資料，但是需要為後續的 GI 建立這個結構。

另外處理 GPU Instancing 資料，必須加上 `UNITY_SETUP_INSTANCE_ID(i)`。

### 分階段進行光照 (GI) 計算
呼叫 `Occlusion()` 來採樣 occlusion。

依照 `UNITY_ENABLE_REFLECTION_BUFFERS` 與否來初始化 `bool sampleReflectionsInDeferred` 的值。

呼叫 `FragmentGI()` 進行詳細計算，回傳一個 `UnityGI` 結構作為結果：
```c
inline UnityGI FragmentGI (FragmentCommonData s, half occlusion, half4 i_ambientOrLightmapUV, half atten, UnityLight light, bool reflections)
```
* 建立一個 UnityGIInput 結構並設值。
* 若有 Light map，設定 `lightmapUV = i_ambientOrLightmapUV`，反之 `ambient = i_ambientOrLightmapUV.rgb` 取出顏色。
* 設定好 Reflection Probe 相關資料到結構中。
* 用 `UnityGlossyEnvironmentSetup()` 計算 `Unity_GlossyEnvironmentData`：
    * `g.roughness = 1 - smoothness`
    * `g.reflUVW = reflect(-worldViewDir, Normal);`
* 用 `UnityGlobalIllumination()` 計算直接光造與間接光照的內容：
    * 定義於 "UnityGlobalIllumination.cginc"。
    * 先執行 `UnityGI_Base()` 計算 UnityGI 結構更新。
        * 取得 Baked ShadowMask，計算更新 Attenuation。
        * 呼叫 `ShadeSHPerPixel()` 計算間接 Diffuse，包含 Light Probe。
        * 計算 LightMap。
        * 計算 Dynamic Light Map。
    * 再用 `UnityGI_IndirectSpecular()` 加上 Reflection Probe 的反射資訊。
        * `BoxProjectedCubemapDirection()`。
        * `Unity_GlossyEnvironment()`。
* `ShadeSHPerPixel()` 定義於 "UnityStandardUtils.cginc"

呼叫 `BRDF1_Unity_PBS()` 或其他定義於 "UnityStandardBRDF.cginc" 的數學模型，計算最終光照結果。
```c
half4 BRDF1_Unity_PBS (half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness, float3 normal, float3 viewDir, UnityLight light, UnityIndirect gi)
```

如果有 `_EMISSION`，計算 `emissiveColor += Emission (i.tex.xy)`。

如果有 `UNITY_HDR_ON`，計算 `emissiveColor.rgb = exp2(-emissiveColor.rgb)` 調整顏色。

最後用 `UnityStandardDataToGbuffer()` 將 UnityGI 資料寫入 GBuffer 以及 Emission。
```c
// RT0: diffuse color (rgb), occlusion (a) - sRGB rendertarget
outGBuffer0 = half4(data.diffuseColor, data.occlusion);
// RT1: spec color (rgb), smoothness (a) - sRGB rendertarget
outGBuffer1 = half4(data.specularColor, data.smoothness);
// RT2: normal (rgb), --unused, very low precision-- (a)
outGBuffer2 = half4(data.normalWorld * 0.5f + 0.5f, 1.0f);
```

### ShadowMask
若有開啟 ShadowMask，用 `UnityGetRawBakedOcclusions()` 計算。

```c
outShadowMask = UnityGetRawBakedOcclusions(i.ambientOrLightmapUV.xy, IN_WORLDPOS(i));
```

`UnityGetRawBakedOcclusions()` 定義於 "UnityShadowLibrary.cginc"，其中包含 Light Map 的採樣，以及 Light Probe Volume 的相關處理等。
