## UnityCG.cginc 以及其關聯檔
### UnityCG.cginc
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

### UnityShaderVariables.cginc
* [define] **_WorldSpaceCameraPos** 攝影機位置之變數

### UnityShaderUtilities.cginc
> *include "UnityShaderVariables.cginc"*

### UnityInstancing.cginc
> *include "HLSLSupport.cginc"*
* [method] **float4 UnityObjectToClipPos(float3)** 與 MVP 矩陣做運算
* [define] **UNITY_SETUP_INSTANCE_ID(input)** 設定 `input.instanceID`，以及 `unity_MatrixMVP_Instanced`, `unity_MatrixMV_Instanced`, `unity_MatrixTMV_Instanced`, `unity_MatrixITMV_Instanced`
* [define] **UNITY_VERTEX_OUTPUT_STEREO** (For VR) 定義需要的 vertex ouput struct member
* [define] **DEFAULT_UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO** (For VR) 初始化 output.stereoTargetEyeIndex

### HLSLSupport.cginc
* [define] **UNITY_POSITION(pos)** 一般相當於 `float4 pos : SV_POSITION`
* [define] **UNITY_INITIALIZE_OUTPUT(type, name)** 初始化參數，視平台差異補上 `name = (type)0;`

## 獨立 library
### UnityStandardInput.cginc
* [method] **float4 TexCoords(VertexInput)** 計算 _MainTex 與 _DetailAlbedoM 的 UV
* [method] **float4 Parallax (float4 texcoords, half3 viewDir)** 若有 heightmap 則依照 viewDir 做 uv 的平移
* [define] **_TANGENT_TO_WORLD** 表示有使用 tangent 的需求

### UnityStandardConfig.cginc
* [define] **UNITY_REQUIRE_FRAG_WORLDPOS** 與 UNITY_STANDARD_SIMPLE 有關，決定是否簡化一些光照
* [define] **UNITY_PACK_WORLDPOS_WITH_TANGENT** 與 UNITY_STANDARD_SIMPLE 有關，決定是否簡化一些光照

### UnityStandardUtils.cginc
* [method] **half3x3 CreateTangentToWorldPerVertex(half3 normal, half3 tangent, half tangentSign)** 建立一個 `half3x3(tangent, binormal, normal)` 
* [method] **half3 ShadeSHPerVertex (half3 normal, half3 ambient)** 計算 Light Probes 的頂點光照 ambient