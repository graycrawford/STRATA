using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlaySound1 : MonoBehaviour {
	public AudioClip Bird1;

	AudioSource audio;

	// Use this for initialization
	void Start () {
		audio = GetComponent <AudioSource> ();
	}
	
	void OnCollisionEnter (Collision other) {
		if (other.gameObject.tag == "Hand") {
			audio.PlayOneShot (Bird1, Random.Range (1, 2));
		}
	}


	// Update is called once per frame
	void Update () {
		
	}
}




