using System.Collections.Generic;
using UnityEngine;

public class RBVelocitySurfacing : MonoBehaviour {
	public Rigidbody SourceBody;
	public List<UnityEngine.Audio.AudioMixer> MixerList; 
	public float scaleFactor = 0.5f;
	public float volumeReduction = 0.5f;
	// Use this for initialization
	void Start () {
		
	}

	void Update () {
		SourceBody = GetComponent<Rigidbody>();
		Vector3 velocity = SourceBody.velocity;

		foreach (var mixer in MixerList) {
			print (SourceBody.velocity);
			print (SourceBody.velocity.magnitude);
			print (mixer.SetFloat ("Volume", velocity.magnitude * scaleFactor - volumeReduction ));
		}
	}

}



