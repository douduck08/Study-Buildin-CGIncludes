using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class ChangeCameraMode : MonoBehaviour {

    public DepthTextureMode mode;

    void Start () {
        GetComponent<Camera> ().depthTextureMode |= mode;
    }
}