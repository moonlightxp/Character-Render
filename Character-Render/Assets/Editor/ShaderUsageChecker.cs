using UnityEngine;
using UnityEditor;
using System.Collections.Generic;
using System.IO;

public class ShaderUsageChecker : EditorWindow
{
    private Shader shaderToCheck;
    private string outputFilePath = "Assets/ShaderUsageResults.txt";  // 输出文件路径

    [MenuItem("Tools/Check Shader Usage")]
    public static void ShowWindow()
    {
        GetWindow<ShaderUsageChecker>("Check Shader Usage");
    }

    private void OnGUI()
    {
        GUILayout.Label("Check Shader Usage", EditorStyles.boldLabel);

        shaderToCheck = (Shader)EditorGUILayout.ObjectField("Shader to Check", shaderToCheck, typeof(Shader), false);
        outputFilePath = EditorGUILayout.TextField("Output File Path", outputFilePath);

        if (GUILayout.Button("Check Shader Usage"))
        {
            if (shaderToCheck != null)
            {
                CheckShaderUsage();
            }
            else
            {
                Debug.LogError("Please specify a shader to check.");
            }
        }
    }

    private void CheckShaderUsage()
    {
        List<string> usedInAssets = new List<string>();

        // 查找项目中所有资源
        string[] allAssetGuids = AssetDatabase.FindAssets("t:Prefab t:Material t:Scene t:Model t:ScriptableObject");

        foreach (string guid in allAssetGuids)
        {
            string assetPath = AssetDatabase.GUIDToAssetPath(guid);
            var dependencies = AssetDatabase.GetDependencies(assetPath, true);

            foreach (string dependency in dependencies)
            {
                Shader shader = AssetDatabase.LoadAssetAtPath<Shader>(dependency);
                if (shader == shaderToCheck)
                {
                    usedInAssets.Add(assetPath);
                    break;
                }
            }
        }

        // 将使用了指定Shader的资源名字保存到TXT文件中
        File.WriteAllLines(outputFilePath, usedInAssets.ToArray());
        AssetDatabase.Refresh();

        Debug.Log("Shader usage check completed. Results saved to " + outputFilePath);
    }
}
