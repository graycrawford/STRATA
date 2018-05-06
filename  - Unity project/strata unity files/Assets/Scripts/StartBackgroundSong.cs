using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class StartHandSong : MonoBehaviour {
	public AudioClip sample;

	AudioSource audio;

	// Use this for initialization
	void Start () {
		audio = GetComponent <AudioSource> ();
	}
	
	void OnTriggerEnter (Collider other) {
		if (other.gameObject.tag == "Hand") {
			audio.PlayOneShot (sample, Random.Range (1, 2));
			// gameObject.SetActive (false);
		}
	}


	// Update is called once per frame
	void Update () {
		
	}
}




