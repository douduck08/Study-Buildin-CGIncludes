#ifndef FULL_REWRITE_INCLUDED
#define FULL_REWRITE_INCLUDED

#include "UnityCG.cginc"
#include "Includes/CommonUtils.cginc"

struct v2f {
    float4 pos : SV_POSITION;
    float4 tex : TEXCOORD0;
    UNITY_VERTEX_INPUT_INSTANCE_ID
    UNITY_VERTEX_OUTPUT_STEREO
};

void vert (appdata_full v, out v2f o) {
    UNITY_INITIALIZE_OUTPUT (v2f, o);
    UNITY_SETUP_INSTANCE_ID(v);
    UNITY_TRANSFER_INSTANCE_ID(v, o);
    UNITY_INITIALIZE_VERTEX_OUTPUT_STEREO(o);

    o.pos = UnityObjectToClipPos(v.vertex);
}

float4 _Color;

// forward path
float4 fragForward (v2f i) : SV_TARGET {
    UNITY_SETUP_INSTANCE_ID(i);

    return _Color;
}

// deferred path
void fragDeferred (v2f i, out FragOutputDeferred o) {
    UNITY_SETUP_INSTANCE_ID(i);

    UNITY_INITIALIZE_OUTPUT (FragOutputDeferred, o);
    o.outGBuffer0 = half4(_Color.rgb, 0);
    o.outGBuffer1 = half4(0, 0, 0, 0.5);
    o.outGBuffer2 = half4(0, 0, 0, 1.0);
}

#endif // FULL_REWRITE_INCLUDED