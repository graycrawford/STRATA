using System.Collections.Generic;
using UnityEngine;

public class StrataDisplacement3 : MonoBehaviour {

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
	

		float input = gameObject.GetComponent<SkinnedMeshRenderer> ().bounds.extents.x; // velocity.magnitude;

		float output = (float) (80 * ((System.Math.Tanh (input * inputScaling) - 1)));
	
			
		switch (mixerNum) {
		case 0:
			MixerList[0].audioMixer.SetFloat ("Strata3Volume", output);
			break;
		}

	}

}
