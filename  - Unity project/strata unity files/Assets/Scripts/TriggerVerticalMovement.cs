using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class TriggerVerticalMovement : MonoBehaviour {

	public Animator anim;

	// Use this for initialization
	void Start () {
		anim = GetComponent<Animator> ();
	}

	void OnTriggerEnter(Collider other) {
		anim.Play ("VerticalMovement");
		anim.Play ("Entry");
	
	}
	
	// Update is called once per frame
	void Update () {
		
	}
}
