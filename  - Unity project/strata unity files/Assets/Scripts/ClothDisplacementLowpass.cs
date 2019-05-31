using System.Collections.Generic;
using UnityEngine;

public class ClothDisplacementLowpass : MonoBehaviour {

	public List<UnityEngine.Audio.AudioMixerGroup> MixerList; 
	//public float scaleFactor = 0.5f;
	//public float volumeReduction = 0.5f;
	public int mixerNum;
	public float inputScaling = 15f;
	public float lowCap = 60f;
	public float highCap = 10000f;

	// Use this for initialization
	void Start () {
		
	}
	void Update () {


		//foreach (var mixer in MixerList) {
			// print (device.velocity);
	

		float input = gameObject.GetComponent<SkinnedMeshRenderer> ().bounds.extents.y; // velocity.magnitude;

			// float x = velocity.magnitude * scaleFactor - volumeReduction;   // OLD TYPE SHIT
		float output = (float) ((-highCap * ((System.Math.Tanh (input * inputScaling) - 1))) + lowCap);
	
			
		switch (mixerNum) {
		case 0:
			MixerList[0].audioMixer.SetFloat ("GlobalLowpass", output);
			break;

		}
			//mixer.SetFloat ("Volume", output);
		// MixerList[0].audioMixer.SetFloat ("Volume", output);
			// Sub1Volume = output;
		//}
	}

}
