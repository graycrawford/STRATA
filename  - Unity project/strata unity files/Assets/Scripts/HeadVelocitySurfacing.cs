using System.Collections.Generic;
using UnityEngine;

public class HeadVelocitySurfacing : MonoBehaviour {
	public SteamVR_TrackedObject controller;
	public List<UnityEngine.Audio.AudioMixerGroup> MixerList; 
	public float minimumVolume = 30f;
	//public float volumeReduction = 0.5f;

	// Use this for initialization
	void Start () {
		
	}
	void Update () {
		SteamVR_Controller.Device device = SteamVR_Controller.Input ((int)controller.index);
		Vector3 velocity = device.velocity;


		//foreach (var mixer in MixerList) {
			// print (device.velocity);
			//Debug.Log (device.velocity.magnitude);

			float input = velocity.magnitude;

			// float x = velocity.magnitude * scaleFactor - volumeReduction;   // OLD TYPE SHIT
			float output = (float) (minimumVolume * (System.Math.Tanh (input) - 1));
	
			//mixer.SetFloat ("Volume", output);
		MixerList[0].audioMixer.SetFloat ("Sub1Volume", output);
			// Sub1Volume = output;
		//}
	}

}
