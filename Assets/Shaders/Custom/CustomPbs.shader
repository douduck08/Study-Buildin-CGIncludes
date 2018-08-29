Shader "Custom/Custom Pbr" {
    Properties {
        _Color ("Color", Color) = (1, 1, 1, 1)
        [Gamma] _Metallic ("Metallic", Range(0, 1)) = 0
        _Smoothness ("Smoothness", Range(0, 1)) = 0.5
        _MainTex ("Main Texture", 2D) = "white" {}
        [NoScaleOffset] _NormalMap ("Normal Map", 2D) = "bump" {}
        _NormalScale ("Normal Scale", Float) = 1
        _DetailTex ("Detail Texture", 2D) = "white" {}
        [NoScaleOffset] _DetailNormalMap ("Detail Normal Map", 2D) = "bump" {}
        _DetailNormalScale ("Detail Normal Scale", Float) = 1
    }
    SubShader {
        Tags { "RenderType"="Opaque" }
        LOD 300

        Pass {
            Name "FORWARD"
            Tags { "LightMode" = "ForwardBase" }

            CGPROGRAM
            #pragma target 3.0
            #pragma multi_compile _ VERTEXLIGHT_ON
            
            #pragma vertex vert
            #pragma fragment fragForwardBase
            #define FORWARD_BASE_PASS
            #include "CustomPbs.cginc"
            ENDCG
        }

        Pass {
            Name "FORWARDAdd"
            Tags { "LightMode" = "ForwardAdd" }
            Blend One One
            ZWrite Off

            CGPROGRAM
            #pragma target 3.0
            #pragma multi_compile_fwdadd
            // #pragma multi_compile DIRECTIONAL DIRECTIONAL_COOKIE POINT POINT_COOKIE SPOT

            #pragma vertex vert
            #pragma fragment fragForwardBase
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
