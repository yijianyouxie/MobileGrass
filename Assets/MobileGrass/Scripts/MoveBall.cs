using UnityEngine;
using System.Collections;

public class MoveBall : MonoBehaviour
{

    public Transform ball;
    private float x = 0;
    private float z = 0;
    private Vector3 ballPosition = new Vector3(0.21f, 0.2f, 1.94f);


    private void OnGUI()
    {
        x = GUI.HorizontalSlider(new Rect(Screen.width - 200, 10, 200, 50), x, -2, 2);
        z = GUI.HorizontalSlider(new Rect(Screen.width - 200, 60, 200, 50), z, -2, 2);

        ballPosition.x = x;
        ballPosition.z = z;
        ball.position = ballPosition;
    }
}
