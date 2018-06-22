## Deferred Path in Standard
VertexOutputDeferred 結構：
* tex.xy 儲存 main texture 的 uv。
* tex.zw 儲存 detail map 的 uv，其中透過內建的 `TexCoords()` 處理時，會確認要使用 uv0 或者 uv1。
* eyeVec = posWorld.xyz - _WorldSpaceCameraPos，會依設定決定是否要 PerPixelNormal。
* tangentToWorldAndPackedData 的 xyz 儲存了world space 下的 (tangent, binormal, normal)；w 儲存了 height map 所需 object space 下的視線向量，或者 world space 的頂點座標。
* ambientOrLightmapUV 的 xy 是 light map 的 uv，zw 是動態 light map 的 uv。若使用 Light Probes 則存入 rgb 中。

一些 build-in define：
* _TANGENT_TO_WORLD 代表有使用 tangent space 的需求。