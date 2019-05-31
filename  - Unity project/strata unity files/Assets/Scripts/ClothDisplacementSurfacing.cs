using System.Collections.Generic;
using UnityEngine;

public class ClothDisplacementSurfacing : MonoBehaviour {

	public List<UnityEngine.Audio.AudioMixerGroup> MixerList; 
	//public float scaleFactor = 0.5f;
	//public float volumeReduction = 0.5f;
	public int mixerNum;
	public float inputScaling = 15f;

	// Use this for initialization
	void Start () {
		
	}
	void Update () {


		//foreach (var mixer in MixerList) {
			// print (device.velocity);
	

		float input = gameObject.GetComponent<SkinnedMeshRenderer> ().bounds.extents.y; // velocity.magnitude;

			// float x = velocity.magnitude * scaleFactor - volumeReduction;   // OLD TYPE SHIT
		float output = (float) (80 * ((System.Math.Tanh (input * inputScaling) - 1)));
	
			
		switch (mixerNum) {
		case 0:
			MixerList[0].audioMixer.SetFloat ("Cloth1Volume", output);
			break;
		case 1:
			MixerList[1].audioMixer.SetFloat ("Cloth2Volume", output);
			break;
		case 2:
			MixerList[2].audioMixer.SetFloat ("Cloth3Volume", output);
			break;
		case 3:
			MixerList[3].audioMixer.SetFloat ("Cloth4Volume", output);
			break;
		case 4:
			MixerList[4].audioMixer.SetFloat ("Cloth5Volume", output);
			break;
		}
			//mixer.SetFloat ("Volume", output);
		// MixerList[0].audioMixer.SetFloat ("Volume", output);
			// Sub1Volume = output;
		//}
	}

}
