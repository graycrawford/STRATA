using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class waitToShrink : MonoBehaviour {

	Animator animator;

	// Use this for initialization
	void Start () {
		animator = GetComponent<Animator> ();
		StartCoroutine (DelayedAnimation());
	}
	
	// Update is called once per frame
	void Update () {

	}

	IEnumerator DelayedAnimation () {
		yield return new WaitForSeconds (5f);
		Debug.Log ("waited");
		animator.Play ("GlobalShrink");
		Debug.Log ("should be animating");
	}


}
