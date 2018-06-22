## 拆解 Standard Shader 的內容
* 首先轉成 Unlit 版 Standard.shader。
* 中間的許多 Keywords 是由 CustomEditor "StandardShaderGUI" 進行變動的，切換模式或開啟貼圖等。

## Deferred Path in Standard
### Keywords
* _NORMALMAP
* _ _ALPHATEST_ON _ALPHABLEND_ON _ALPHAPREMULTIPLY_ON
* _EMISSION
* _METALLICGLOSSMAP
* _ _SMOOTHNESS_TEXTURE_ALBEDO_CHANNEL_A
* _ _SPECULARHIGHLIGHTS_OFF
* ___ _DETAIL_MULX2
* _PARALLAXMAP

### 一些 build-in define
定義在 "UnityStandardInput.cginc" 中，
* `_TANGENT_TO_WORLD` 代表有使用 tangent space 的需求。相當於 `_NORMALMAP || DIRLIGHTMAP_COMBINED || _PARALLAXMAP`
* `_DETAIL` 相當於 `_DETAIL_MULX2 || _DETAIL_MUL || _DETAIL_ADD || _DETAIL_LERP`

### VertexOutputDeferred 結構
* tex.xy 儲存 main texture 的 uv。
* tex.zw 儲存 detail map 的 uv，其中透過內建的 `TexCoords()` 處理時，會確認要使用 uv0 或者 uv*
* eyeVec = posWorld.xyz - _WorldSpaceCameraPos，會依設定決定是否要 PerPixelNormal。
* tangentToWorldAndPackedData 的 xyz 儲存了world space 下的 (tangent, binormal, normal)；w 儲存了 height map 所需 object space 下的視線向量，或者 world space 的頂點座標。
* ambientOrLightmapUV 的 xy 是 light map 的 uv，zw 是動態 light map 的 uv。若使用 Light Probes 則存入 rgb 中。

### vertDeferred function
基本上就是將 `VertexOutputDeferred` 內的資料準備好，若有 `_TANGENT_TO_WORLD` 或 `LIGHTMAP_ON` 會產生一些變化或簡化。

### FragmentCommonData 結構
定義了 fragment shader 中需要的一些資料，會在 shader 中呼叫 `FragmentSetup (inout float4 i_tex, float3 i_eyeVec, half3 i_viewDirForParallax, float4 tangentToWorld[3], float3 i_posWorld)` 來計算準備。

在 `FragmentSetup` 中，依序進行了：
* `Parallax()` 計算 height map
* 若有 alpha test 在此時檢查
* `SpecularSetup()` 計算
* `PerPixelWorldNormal()`
* `NormalizePerPixelNormal()`
* `o.posWorl` 設值
* `PreMultiplyAlpha()`

### fragDeferred function
檢查 Dither Clip 後進行 FRAGMENT_SETUP，接著計算光照。

最後用 `UnityStandardDataToGbuffer()` 將資料轉為 GBuffer 所要的格式，以及填入 Emission Color。

若有開啟 ShadowMask，用 `UnityGetRawBakedOcclusions()` 計算。
