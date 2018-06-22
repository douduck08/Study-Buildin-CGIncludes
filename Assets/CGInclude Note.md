## UnityCG.cginc 以及其關聯檔
### UnityCG.cginc
> *include "UnityShaderVariables.cginc", "UnityShaderUtilities.cginc", "UnityInstancing.cginc"*

函數方法：
* **UnityObjectToWorldDir(float3)** 計算世界座標的向量
* **UnityObjectToWorldNormal(float3)** 計算世界座標的 normal
* **ObjSpaceViewDir(float3)** 計算物件座標下的視線方向

define變數：
* **TANGENT_SPACE_ROTATION** 一段計算tangent space的旋轉矩陣的程式碼，相當於
```c
float3 binormal = cross(normalize(v.normal), normalize(v.tangent.xyz)) * v.tangent.w;
float3x3 rotation = float3x3(v.tangent.xyz, binormal, v.normal);
```

相關片段：
```c
float3 normalWorld = UnityObjectToWorldNormal(v.normal);
float4 tangentWorld = float4(UnityObjectToWorldDir(v.tangent.xyz), v.tangent.w);
```

### UnityShaderVariables.cginc

define變數：
* **_WorldSpaceCameraPos** 攝影機位置之變數

### UnityShaderUtilities.cginc
> *include "UnityShaderVariables.cginc"*

### UnityInstancing.cginc
> *include "HLSLSupport.cginc"*

函數方法：
* **UnityObjectToClipPos(float3)** 與 MVP 矩陣做運算

define變數：
* **UNITY_SETUP_INSTANCE_ID(input)** 設定 `input.instanceID`，以及 `unity_MatrixMVP_Instanced` `unity_MatrixMV_Instanced` `unity_MatrixTMV_Instanced` `unity_MatrixITMV_Instanced`
* **UNITY_VERTEX_OUTPUT_STEREO** (For VR) 定義需要的 vertex ouput struct member
* **DEFAULT_UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO** (For VR) 初始化 output.stereoTargetEyeIndex

### HLSLSupport.cginc

efine變數：
* **UNITY_POSITION(pos)** 一般相當於 `float4 pos : SV_POSITION`
* **UNITY_INITIALIZE_OUTPUT(type, name)** 初始化參數，視平台差異補上 `name = (type)0;`

## 獨立 library
### UnityStandardInput.cginc

函數方法：
* **TexCoords(VertexInput)** 計算 _MainTex 與 _DetailAlbedoM 的 UV

define變數：
* **_TANGENT_TO_WORLD** 表示有使用 tangent 的需求

### UnityStandardUtils.cginc

函數方法：
* **CreateTangentToWorldPerVertex(half3 normal, half3 tangent, half tangentSign)** 建立一個 `half3x3(tangent, binormal, normal)` 
* **ShadeSHPerVertex (half3 normal, half3 ambient)** 計算 Light Probes 的頂點光照 ambient，為 half3