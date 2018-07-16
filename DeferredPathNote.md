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
單純計算 `GL.Draw` 的呼叫次數，每個 Deferred 物件分別需要 3 次，每增加一個 Light 會再需要 2 次呼叫。而每個 Forward 物件分別需要 4 次，每增加一個 Light 會再需要 3 次呼叫。

因為 Light 增加部分是 Cast Shadow 全開下的結果，關閉部分物件的 Cast Shadow 增加就不會那麼劇烈。

若開啟了 DepthNormals，則 `GL.Draw` 所有 Deferred 只需要 1 次(從GBuffer抓取資料)，但 Forward 需要每個物件再分別 1 次。