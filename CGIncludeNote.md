# UnityCG.cginc 以及其關聯檔
## UnityCG.cginc
> *include "UnityShaderVariables.cginc", "UnityShaderUtilities.cginc", "UnityInstancing.cginc"*
* [method] **float3 UnityObjectToWorldDir(float3)** 計算世界座標的向量
* [method] **float3 UnityObjectToWorldNormal(float3)** 計算世界座標的 normal
* [method] **float3 ObjSpaceViewDir(float3)** 計算物件座標下的視線方向
* [define] **TANGENT_SPACE_ROTATION** 一段計算tangent space的旋轉矩陣的程式碼，相當於：
```c
float3 binormal = cross(normalize(v.normal), normalize(v.tangent.xyz)) * v.tangent.w;
float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
```
* [define] **UNITY_APPLY_DITHER_CROSSFADE(float2)** 若有 Dither Crossfade，以 `sampler2D _DitherMaskLOD2D` 的採樣結果執行 `clip`

相關片段：
```c
float3 normalWorld = UnityObjectToWorldNormal(v.normal);
float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
```

## UnityShaderVariables.cginc
* [define] **_WorldSpaceCameraPos** 攝影機位置之變數

## UnityShaderUtilities.cginc
> *include "UnityShaderVariables.cginc"*
* [method] **half3 PreMultiplyAlpha (half3 diffColor, half alpha, half oneMinusReflectivity, out half outModifiedAlpha)** 依照 `_ALPHAPREMULTIPLY_ON` 的開關去混和 alpha
* [method] **half3 EnergyConservationBetweenDiffuseAndSpecular (half3 albedo, half3 specColor, out half oneMinusReflectivity)** 根據採用的光照能量模型去計算 diffColor 與 oneMinusReflectivity 參數

## UnityInstancing.cginc
> *include "HLSLSupport.cginc"*
* [method] **float4 UnityObjectToClipPos(float3)** 與 MVP 矩陣做運算
* [define] **UNITY_SETUP_INSTANCE_ID(input)** 設定 `input.instanceID`，以及 `unity_MatrixMVP_Instanced`, `unity_MatrixMV_Instanced`, `unity_MatrixTMV_Instanced`, `unity_MatrixITMV_Instanced`
* [define] **UNITY_VERTEX_OUTPUT_STEREO** (For VR) 定義需要的 vertex ouput struct member
* [define] **DEFAULT_UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO** (For VR) 初始化 output.stereoTargetEyeIndex

## HLSLSupport.cginc
* [define] **UNITY_POSITION(pos)** 一般相當於 `float4 pos : SV_POSITION`
* [define] **UNITY_INITIALIZE_OUTPUT(type, name)** 初始化參數，視平台差異補上 `name = (type)0;`

# 獨立 library
## UnityStandardInput.cginc
* [method] **float4 TexCoords(VertexInput)** 計算 `_MainTex` 與 `_DetailAlbedoM` 的 UV
* [method] **half3 Albedo(float4 texcoords)** 針對 `_MainTex` 與 `_DetailAlbedoMap` 進行採樣與混和
* [method] **float4 Parallax (float4 texcoords, half3 viewDir)** 若有 heightmap 則依照 viewDir 做 uv 的平移
* [method] **half4 SpecularGloss(float2 uv)** 根據材質設定或 `_SpecGlossMap` 採樣，回傳 specColor 存在 rgb，並視需要在 `_MainTex` 採樣 smooth 存在 a channel
* [method] **half2 MetallicGloss(float2 uv)** 根據材質設定或 `_MetallicGlossMap` 採樣，現在 Standard 用此方法取代 `SpecularGloss()` 
* [method] **half Occlusion(float2 uv)** 對 `_OcclusionMap` 採樣
* [define] **_TANGENT_TO_WORLD** 表示有使用 tangent 的需求

## UnityStandardConfig.cginc
* [define] **UNITY_REQUIRE_FRAG_WORLDPOS** 與 UNITY_STANDARD_SIMPLE 有關，決定是否簡化一些光照
* [define] **UNITY_PACK_WORLDPOS_WITH_TANGENT** 與 UNITY_STANDARD_SIMPLE 有關，決定是否簡化一些光照

## UnityStandardUtils.cginc
* [method] **half3x3 CreateTangentToWorldPerVertex(half3 normal, half3 tangent, half tangentSign)** 建立一個 `half3x3(tangent, binormal, normal)` 
* [method] **half3 ShadeSHPerVertex (half3 normal, half3 ambient)** 計算頂點光照的 ambient

# 光照相關
## UnityLightingCommon.cginc
內含 `UnityLight`, `UnityIndirect`, `UnityGI`, `UnityGIInput` 的結構定義。

## UnityStandardBRDF.cginc
> *include "UnityCG.cginc", "UnityStandardConfig.cginc", "UnityLightingCommon.cginc"*
* [method] **float SmoothnessToPerceptualRoughness(float smoothness)** 轉換回傳 `roughness = 1 - smoothness`
* [method] **half4 BRDF1_Unity_PBS (half3 diffColor, half3 specColor, half oneMinusReflectivity, half smoothness, float3 normal, float3 viewDir, UnityLight light, UnityIndirect gi)** 數個 `UNITY_BRDF_PBS` 實作方法之一，是 Unity 中最精細的 PBR 雙向反射函數

## UnityImageBasedLighting.cginc
> *include "UnityCG.cginc", "UnityStandardConfig.cginc", "UnityStandardBRDF.cginc"*
* [method] **Unity_GlossyEnvironmentData UnityGlossyEnvironmentSetup(half Smoothness, half3 worldViewDir, half3 Normal, half3 fresnel0)** 計算 roughness 以及 `reflect(-worldViewDir, Normal)`, 資料用於環境貼圖的間接光照

## UnityGlobalIllumination.cginc
> *include "UnityImageBasedLighting.cginc", "UnityStandardUtils.cginc", "UnityShadowLibrary.cginc"*
* [method] **inline UnityGI UnityGlobalIllumination (UnityGIInput data, half occlusion, half3 normalWorld, Unity_GlossyEnvironmentData glossIn)** 
* [method] **UnityGI UnityGI_Base(UnityGIInput data, half occlusion, half3 normalWorld)** 計算直接光照、light map混和
* [method] **half3 UnityGI_IndirectSpecular(UnityGIInput data, half occlusion, Unity_GlossyEnvironmentData glossIn)** 計算環境貼圖的間接反射

## UnityGBuffer.cginc
內含 `UnityStandardData` 的結構定義
* [method] **void UnityStandardDataToGbuffer(UnityStandardData data, out half4 outGBuffer0, out half4 outGBuffer1, out half4 outGBuffer2)** 將光照的計算結果寫入 GBuffer

## UnityPBSLighting.cginc
> *include "UnityShaderVariables.cginc", "UnityStandardConfig.cginc", "UnityLightingCommon.cginc", "UnityGBuffer.cginc", "UnityGlobalIllumination.cginc"*

