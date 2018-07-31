﻿Shader "Custom/Full Rewrite" {
    Properties {
        _Color ("Color", Color) = (1, 1, 1, 1)
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
            #pragma fragment fragForward
            #include "Full_Rewrite.cginc"
            ENDCG
        }

        Pass {
            Name "DEFERRED"
            Tags { "LightMode" = "Deferred" }

            CGPROGRAM
            #pragma target 3.0
            #pragma vertex vert
            #pragma fragment fragDeferred
            #include "Full_Rewrite.cginc"
            ENDCG
        }
    }

    FallBack "VertexLit"
}
