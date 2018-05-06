using System.Collections;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class ResetTimer : MonoBehaviour {

	// Use this for initialization
	void Start () {
		ModeSelect ();
	}
	
	// Update is called once per frame
	void Update () {
		
	}

	public void  ModeSelect(){
		StartCoroutine(LoadAfterDelay("9.5-intro"));
	}

	IEnumerator LoadAfterDelay(string levelName){
		yield return new WaitForSeconds(235);
		SceneManager.LoadScene(levelName);

	}

}
