# Pbr Note
## Material
* Albedo - Base color of material, main texture.
* Metallic
* Smoothness (Invert of Roughness)

## Direct light
### Specular
* Specular Power - depence on gloss, `exp2(10 * gloss + 1)`
* Phong model vs Blinn-Phong model
```c
// Phong model
float3 reflDir = reflect(-lightDir, i.normal);
float3 spec = albedo * pow(saturate(dot(viewDir, reflDir)), _Smoothness * 128);
// Blinn-Phong model
float3 halfDir = normalize(lightDir + viewDir);
float3 spec = albedo * pow(saturate(dot(halfDir, i.normal)), _Smoothness * 128);
```
### Diffuse

## Indirect light (Image Based Lighting)
### Reflection (Specular cubemap)
### Radiance environment cubemap 

## Ref
* Catlike Coding Tutorials, Rendering: https://catlikecoding.com/unity/tutorials/rendering/part-1/
* Adopting a physically based shading model: https://seblagarde.wordpress.com/2011/08/17/hello-world/

# Forward Rendering Path in Unity
```
WIP
```
* 每一個 Light 會需要在每個物件上執行一次渲染。
* 每個物件會以最主要的 Light 會執行一次 ForwardBse，接著每個 Light 再另外執行一次 ForwardAdd。

# Deferred Rendering Path in Unity
```
[Drawing]
    [Render Opaque Geometry]
        [Render GBuffer]
            * Render 'Deferred Pass' per Object.
        [Render Forward Object into Depth]
            * If Forward Object exist.
            * Render 'ShadowCaster Pass' per Object.
        [Render CopyDepth]
        [Render Reflections]
            * Render 'Internal-DeferredReflections, Pass #0'
        [Render ReflectionsToEmissive]
            * Render 'Internal-DeferredReflections, Pass #1'
        [Render Lighting]
            [Render ShadowMap] Render 'ShadowCaster Pass' per Object 2 times.
            [Collect Shadows] Render 'Internal-SreenSpaceShadows, Pass #0'
        [Render Combin DepthNormals]
            * If camera is DepthNormals mode.
            * Render 'Internal-DepthNormalsTexture, Pass #0' once.
        [Render Forward Opaque]
            * If Forward Object exist.
            * Render 'ForwardBase Pass' per Object.
        [Render Forward Object into DepthNormals]
            * If camera is DepthNormals mode.
            * If Forward Object exist.
            * Or render 'Internal-DepthNormalsTexture, Pass #0' per Object.
    [Render SkyBox]
    [Camera ImageEffects (Opaque)]
    [Render Transparent Geometry]
[Camera ImageEffects]
```
* Unity 可以將只支援 Forward Shader 的物件混入 Deferred Rendering 中。
* 單純計算 `GL.Draw` 的呼叫次數，每個 Deferred 物件分別需要 3 次，每增加一個 Light 會再需要 2 次呼叫。而每個 Forward 物件分別需要 4 次，每增加一個 Light 會再需要 3 次呼叫。
* 因為 Light 增加部分是 Cast Shadow 造成的結果，關閉部分物件的 Cast Shadow 增加就不會那麼劇烈。
* Deferred 的 GBuffer 不適用 Alpha Blend，所以 Transparent 物件是在最後另外用 Forward Shader 繪製。
* 若開啟了 Camera Depth/Normal Mode，則 `GL.Draw` 所有 Deferred 只需要 1 次(從GBuffer抓取資料)，但 Forward 需要每個物件再分別重繪 1 次。