# Deferred Rendering Path in Unity
```
[Drawing]
    [Render Opaque Geometry]
        [Render GBuffer]
        [Render CopyDepth]
        [Render Reflections] Render 'Internal-DeferredReflections, Pass #0'
        [Render ReflectionsToEmissive] Render 'Internal-DeferredReflections, Pass #1'
        [Render Lighting]
            [Render ShadowMap] Render 'ShadowCaster Pass'
            [Collect Shadows] Render 'Internal-SreenSpaceShadows, Pass #0'
        [Render Combin DepthNormals] Render 'Internal-DepthNormalsTexture, Pass #0' once
        [Render Forward Opaque]
        [Render Forward into DepthNormals] Render 'Internal-DepthNormalsTexture, Pass #0' per Object
    [Render SkyBox]
    [Camera ImageEffects (Opaque)]
    [Render Transparent Geometry]
[Camera ImageEffects]
```