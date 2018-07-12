# 拆解 Standard Surface Shader 為 Unlit Shader
首先轉成 Unlit Shader，內容為：[Standard.shader](Assets/Shaders/Standard.shader)。

中間的許多 Keywords 是由 CustomEditor "StandardShaderGUI" 進行變動的，切換模式或開啟貼圖等都相當於套用不同的 Shader。

> KeyWords 中的 `_` 似乎不論數量都是相同的意思。

## Keywords
* _NORMALMAP
* _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON (決定光照的 alpha blend 方式)
* _EMISSION
* _METALLICGLOSSMAP
* _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
* _ _SPECULARHIGHLIGHTS_OFF
* ___ _DETAIL_MULX2
* _PARALLAXMAP

# Standard Deferred Shader 的內容

## 一些 build-in define
定義在 "UnityStandardInput.cginc" 中，決定了透過 Keywords 開啟的功能是否要對應開啟某段 shader 功能
* `_TANGENT_TO_WORLD` 代表有使用 tangent space 的需求。相當於 `_NORMALMAP || DIRLIGHTMAP_COMBINED || _PARALLAXMAP`
* `_DETAIL` 代表有使用次級貼圖。相當於 `_DETAIL_MULX2 || _DETAIL_MUL || _DETAIL_ADD || _DETAIL_LERP`

## VertexOutputDeferred 結構
* tex.xy 儲存 main texture 的 uv。
* tex.zw 儲存 detail map 的 uv，其中透過內建的 `TexCoords()` 處理時，會確認要使用 uv0 或者 uv*
* eyeVec = posWorld.xyz - _WorldSpaceCameraPos，會依設定決定是否要 PerPixelNormal。
* tangentToWorldAndPackedData 的 xyz 儲存了world space 下的 (tangent, binormal, normal)；w 儲存了 height map 所需 object space 下的視線向量，或者 world space 的頂點座標。
* ambientOrLightmapUV 的 xy 是 light map 的 uv，zw 是動態 light map 的 uv。若使用 Light Probes 則存入 rgb 中。

## vertDeferred function
基本上就是將 `VertexOutputDeferred` 內的資料準備好，若有 `_TANGENT_TO_WORLD` 或 `LIGHTMAP_ON` 會產生一些變化或簡化。

## FragmentCommonData 結構
定義了 fragment shader 中需要的一些資料，會在 shader 中呼叫 `FragmentSetup (inout float4 i_tex, float3 i_eyeVec, half3 i_viewDirForParallax, float4 tangentToWorld[3], float3 i_posWorld)` 來計算準備。

在 `FragmentSetup` 中，依序進行了：
* `Parallax()` 計算 height map
* 若有 alpha test 在此時檢查是否要 clip
* `SpecularSetup()` 計算 `diffColor`, `specColor`, `smooth` 與 `oneMinusReflectivity`
* `PerPixelWorldNormal()` 計算 normal map 之下的 world space normal
* `o.eyeVec` 設值，由 `NormalizePerPixelNormal()` 與 `NormalizePerVertexNormal()` 配合計算
* `o.posWorld` 設值
* `PreMultiplyAlpha()` 計算 blended alpha

## fragDeferred function
檢查 Dither Clip 後進行 FRAGMENT_SETUP，接著計算光照 (GI)。

GI 的計算依序進行了：
* 先對 `_OcclusionMap` 採樣
* 對 Light map 採樣或者從 `i_ambientOrLightmapUV` 中取出顏色
* 設定好 cubemap ，以及用 `UnityGlossyEnvironmentSetup()` 準備反射所需資料
* 用 `UnityGlobalIllumination()` 計算直接光造與間接光照的所有內容
    * 定義於 "UnityGlobalIllumination.cginc"
    * 先執行 `UnityGI_Base()` 計算 UnityGI 結構
        * 取得 Baked ShadowMask，計算更新 Attenuation
        * 呼叫 `ShadeSHPerPixel()` 計算 Diffuse，其中包含 Light Probe，定義於 "UnityStandardUtils.cginc"
        * 計算 LightMap
        * 計算 Dynamic Light Map
    * 再用 `UnityGI_IndirectSpecular()` 加上間接反射
        * `BoxProjectedCubemapDirection()`
        * `Unity_GlossyEnvironment()`
* 用 `BRDF1_Unity_PBS()` 或其他數學模型進一步計算反射部分，定義於  "UnityStandardBRDF.cginc"
* 如果有，再加上 Emission Color
* 依據開啟 HDR 與否調整顏色

最後用 `UnityStandardDataToGbuffer()` 將 UnityGI 資料轉為 GBuffer 所要的格式，以及填入 Emission Color。

若有開啟 ShadowMask，用 `UnityGetRawBakedOcclusions()` 計算。
