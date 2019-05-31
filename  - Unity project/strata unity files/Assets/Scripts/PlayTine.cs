using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class PlayTine : MonoBehaviour {
	public List<AudioClip> audioClips;
	public UnityEngine.Audio.AudioMixerGroup tineMixer;
	public float prob = 0.6f;
	bool willPlay;
	AudioSource audio;

	private AudioClip tineSample;

	// Use this for initialization
	void Start () {
		gameObject.AddComponent<AudioSource> ();
		audio = GetComponent<AudioSource>(); // GetComponent <AudioSource> ();
		audio.outputAudioMixerGroup = tineMixer;
		tineSample = audioClips[Random.Range(0, audioClips.Count)];
		willPlay = (UnityEngine.Random.Range (0, 1) > prob) ? false : true;
	}
	
	void OnCollisionEnter (Collision other) {
		if (other.gameObject.tag == "Hand" && willPlay) {
			audio.PlayOneShot (tineSample, Random.Range (1, 2));
		}
	}


	// Update is called once per frame
	void Update () {
		
	}
}




