using System.Collections;
using System.Collections.Generic;
using UnityEngine;


public class groundSphere : MonoBehaviour {

	public GameObject target;
	public GameObject sphere;
	public float height;

	// Use this for initialization
	void Start () {
	}
	
	// Update is called once per frame
	void Update () {
		Vector3 pose = target.transform.position;
		sphere.transform.position = new Vector3 (pose.x, (height), pose.z);
	}
}
