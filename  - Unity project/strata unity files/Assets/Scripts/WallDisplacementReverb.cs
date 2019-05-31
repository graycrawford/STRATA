using System.Collections.Generic;
using UnityEngine;

public class WallDisplacementReverb : MonoBehaviour {

	public List<UnityEngine.Audio.AudioMixerGroup> MixerList; 
	//public float scaleFactor = 0.5f;
	//public float volumeReduction = 0.5f;
	public int mixerNum;
	public float inputScaling = 15f;
	public float highCap = 0f;
	public float lowCap = -10000f;
	public float offset = 0f;

	// Use this for initialization
	void Start () {
		
	}
	void Update () {


		//foreach (var mixer in MixerList) {
			// print (device.velocity);
	

		float input = gameObject.GetComponent<SkinnedMeshRenderer> ().bounds.extents.x; // velocity.magnitude;

			// float x = velocity.magnitude * scaleFactor - volumeReduction;   // OLD TYPE SHIT
		float output = (float) ((lowCap * ((System.Math.Tanh ((input - offset) * inputScaling) - 1))) + highCap);
	
			
		switch (mixerNum) {
		case 0:
			MixerList[0].audioMixer.SetFloat ("MasterReverb", output);
			break;

		}
			//mixer.SetFloat ("Volume", output);
		// MixerList[0].audioMixer.SetFloat ("Volume", output);
			// Sub1Volume = output;
		//}
	}

}
