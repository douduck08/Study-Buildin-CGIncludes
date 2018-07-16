using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TestLightProbe : MonoBehaviour {

    public Vector3 pointA;
    public Vector3 pointB;
    public float speed = 1f;

    Renderer rendererCache;

    float t = 0f;

    void Start () {
        rendererCache = GetComponent<Renderer> ();
    }

    void Update () {
        t += Time.deltaTime * speed;
        t %= 2f;
        transform.localPosition = Vector3.Lerp (pointA, pointB, 0.5f + 0.5f * Mathf.Sin (Mathf.PI * t));
    }
}