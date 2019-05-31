using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class SwitchScene1 : MonoBehaviour {

	// Use this for initialization
	void Start () {
	}
	
	void OnCollisionEnter (Collision other) {
		if (other.gameObject.tag == "Hand") {
			StartCoroutine(LoadYourAsyncScene());
			Debug.Log ("got collision");
		}
	}


	// Update is called once per frame
	void Update () {
		
	}

	IEnumerator LoadYourAsyncScene()
	{
		// The Application loads the Scene in the background as the current Scene runs.
		// This is particularly good for creating loading screens.
		// You could also load the Scene by using sceneBuildIndex. In this case Scene2 has
		// a sceneBuildIndex of 1 as shown in Build Settings.

		AsyncOperation asyncLoad = SceneManager.LoadSceneAsync("10-strata");
		Debug.Log ("waiting to load");

		// Wait until the asynchronous scene fully loads
		while (!asyncLoad.isDone)
		{
			yield return null;
		}
	}


}




