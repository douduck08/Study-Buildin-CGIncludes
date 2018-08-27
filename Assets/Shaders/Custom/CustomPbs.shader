Shader "Custom/Custom Pbr" {
    Properties {
        _Color ("Color", Color) = (1, 1, 1, 1)
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _MainTex ("Main Texture", 2D) = "white" {}
        _DetailTex ("Detail Texture", 2D) = "white" {}
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 300

        Pass {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment fragForwardPbs
            #include "CustomPbs.cginc"
            ENDCG
        }

        // Pass {
        //     Name "DEFERRED"
        //     Tags { "LightMode" = "Deferred" }

        //     CGPROGRAM
        //     #pragma target 3.0
        //     #pragma vertex vert
        //     #pragma fragment fragDeferred
        //     #include "CustomPbs.cginc"
        //     ENDCG
        // }
    }

    // FallBack "VertexLit"
}
