using UnityEngine;
using UnityEditor;
using System;

public class PBR_Base_Urp_Inspector : ShaderGUI
{
    public enum BlendMode { Opaque, Cutout, Fade }
    public enum CullMode { Off, Front, Back }
    public enum SpecialMode{ Off, AnisotropicMode, UVAnisotropicMode}

    private static class Styles
    {
        //参数
        public static GUIContent mainTexText = EditorGUIUtility.TrTextContent("主贴图");
        public static GUIContent bumpMapText = EditorGUIUtility.TrTextContent("法线贴图");
        public static GUIContent detailBumpMapText = EditorGUIUtility.TrTextContent("细节法线贴图");
        public static GUIContent emissionMapText = EditorGUIUtility.TrTextContent("自发光贴图");
        public static GUIContent sssMapText = EditorGUIUtility.TrTextContent("SSS贴图");
        public static GUIContent laserMapText = EditorGUIUtility.TrTextContent("镭射贴图");
        public static GUIContent gmaMapText = EditorGUIUtility.TrTextContent("功能贴图(光滑度 / 金属度 / AO)");
        public static GUIContent sldMapText = EditorGUIUtility.TrTextContent("功能贴图(SSSMask / 辅光Mask / Denier)");
        public static GUIContent matcapText = EditorGUIUtility.TrTextContent("MatCap贴图");
        public static GUIContent hairDataMapText = EditorGUIUtility.TrTextContent("各向异性Mask贴图");
        public static GUIContent tangentNormalMapText = EditorGUIUtility.TrTextContent("自定义各向异性法线贴图");
        
        public static string lightPart = "------Light Part------";
        public static string pbrPart = "------PBR Part------";
        
        public static string specColorText = "SpecColor";
        public static string renderingMode = "Rendering Mode";
        public static string cullMode = "Cull Mode";
        public static string specialMode = "Special Mode";

        public static readonly string[] blendNames = Enum.GetNames(typeof(BlendMode));
        public static readonly string[] cullBlendNames = Enum.GetNames(typeof(CullMode));
        public static readonly string[] specialNames = Enum.GetNames(typeof(SpecialMode));
    }

    #region MaterialProperty
    //模式切换
    private MaterialProperty blendMode;
    private MaterialProperty cullMode;
    private MaterialProperty specialMode;
    //固有色和透明
    private MaterialProperty _MainTex;
    private MaterialProperty _Color;
    private MaterialProperty _Cutoff;
    //法线
    private MaterialProperty _BumpMap;
    private MaterialProperty _DetailNormalMap;
    private MaterialProperty _BumpScale;
    private MaterialProperty _DetailBumpScale;
    //PBR
    private MaterialProperty _GMAMap;
    private MaterialProperty _Metallic;
    private MaterialProperty _Smoothness;
    //AO和自定义阴影
    private MaterialProperty _SLDMap;
    private MaterialProperty _AOStrength;
    //自发光
    private MaterialProperty _EmissionMap;
    private MaterialProperty _EmissionColor;
    //灯光设置
    private MaterialProperty _CustomLightDir1;
    private MaterialProperty _CustomLightDir2;
    private MaterialProperty _CustomLightDir2Color;
    private MaterialProperty _CustomLightDir2Softness;
    private MaterialProperty _BrightnessInShadow;
    private MaterialProperty _BrightnessInOcclusion;
    //环境光和SSS
    private MaterialProperty _AmbientColor;
    private MaterialProperty _SSS_Toggle;
    private MaterialProperty _SSSMap;
    private MaterialProperty _SubSurface;
    //反射
    private MaterialProperty _MatCapTex;
    private MaterialProperty _MatCapColor;
    //LOL各向异性
    private MaterialProperty _HairDataMap;
    private MaterialProperty _TangentNormalMap;
    private MaterialProperty _PrimarySpecularColor;
    private MaterialProperty _SecondarySpecularColor;
    private MaterialProperty _PrimarySpecularExponent;
    private MaterialProperty _PrimarySpecularShift;
    private MaterialProperty _SecondarySpecularExponent;
    private MaterialProperty _SecondarySpecularShift;
    //后处理
    private MaterialProperty _Brightness;
    private MaterialProperty _Saturation;
    private MaterialProperty _Hardness;
    //丝袜
    private MaterialProperty _Denier_Toggle;
    private MaterialProperty _RimPower;
    private MaterialProperty _Denier;
    private MaterialProperty _SkinColor;
    private MaterialProperty _StockingColor;
    //镭射
    private MaterialProperty _Laser_Toggle;
    private MaterialProperty _LaserMap;
    private MaterialProperty _LaserIntensity;
    
    #endregion

    private MaterialEditor m_MaterialEditor;
    private Material material;
    bool m_FirstTimeApply = true;

    private void FindProperties(MaterialProperty[] properties)
    {
        //模式切换
        blendMode = FindProperty("_Mode", properties);
        cullMode = FindProperty("_Cull", properties);
        specialMode = FindProperty("_SpecialMode", properties);
        //固有色
        _MainTex = FindProperty("_MainTex", properties);
        _Color = FindProperty("_Color", properties);
        _Cutoff = FindProperty("_Cutoff", properties);
        //法线
        _BumpMap = FindProperty("_BumpMap", properties);
        _DetailNormalMap = FindProperty("_DetailNormalMap", properties);
        _BumpScale = FindProperty("_BumpScale", properties);
        _DetailBumpScale = FindProperty("_DetailBumpScale", properties);
        //PBR
        _GMAMap = FindProperty("_GMAMap", properties);
        _Metallic = FindProperty("_Metallic", properties);
        _Smoothness = FindProperty("_Smoothness", properties);
        //AO和自定义阴影
        _SLDMap = FindProperty("_SLDMap", properties);
        _AOStrength = FindProperty("_AOStrength", properties);
        //自发光
        _EmissionMap = FindProperty("_EmissionMap", properties);
        _EmissionColor = FindProperty("_EmissionColor", properties);
        //灯光设置
        _CustomLightDir1 = FindProperty("_CustomLightDir1", properties);
        _CustomLightDir2 = FindProperty("_CustomLightDir2", properties);
        _CustomLightDir2Color = FindProperty("_CustomLightDir2Color", properties);
        _CustomLightDir2Softness = FindProperty("_CustomLightDir2Softness", properties);
        _BrightnessInShadow = FindProperty("_BrightnessInShadow", properties);
        _BrightnessInOcclusion = FindProperty("_BrightnessInOcclusion", properties);
        //环境光和SSS
        _AmbientColor = FindProperty("_AmbientColor", properties);
        _SSS_Toggle = FindProperty("_SSS_Toggle", properties);
        _SSSMap = FindProperty("_SSSMap", properties);
        _SubSurface = FindProperty("_SubSurface", properties);
        //反射
        _MatCapTex = FindProperty("_MatCapTex", properties);
        _MatCapColor = FindProperty("_MatCapColor", properties);
        //LOL各向异性
        _HairDataMap = FindProperty("_HairDataMap", properties);
        _TangentNormalMap = FindProperty("_TangentNormalMap", properties);
        _PrimarySpecularColor = FindProperty("_PrimarySpecularColor", properties);
        _SecondarySpecularColor = FindProperty("_SecondarySpecularColor", properties);
        _PrimarySpecularExponent = FindProperty("_PrimarySpecularExponent", properties);
        _PrimarySpecularShift = FindProperty("_PrimarySpecularShift", properties);
        _SecondarySpecularExponent = FindProperty("_SecondarySpecularExponent", properties);
        _SecondarySpecularShift = FindProperty("_SecondarySpecularShift", properties);
        //后处理
        _Brightness = FindProperty("_Brightness", properties);
        _Saturation = FindProperty("_Saturation", properties);
        _Hardness = FindProperty("_Hardness", properties);
        //丝袜
        _Denier_Toggle = FindProperty("_Denier_Toggle", properties);
        _RimPower = FindProperty("_RimPower", properties);
        _Denier = FindProperty("_Denier", properties);
        _SkinColor = FindProperty("_SkinColor", properties);
        _StockingColor = FindProperty("_StockingColor", properties);
        //镭射
        _Laser_Toggle = FindProperty("_Laser_Toggle", properties);
        _LaserMap = FindProperty("_LaserMap", properties);
        _LaserIntensity = FindProperty("_LaserIntensity", properties);
    }
    
    public override void AssignNewShaderToMaterial(Material material, Shader oldShader, Shader newShader)
    {
        base.AssignNewShaderToMaterial(material, oldShader, newShader);
        if (oldShader == null || !oldShader.name.Contains("Legacy Shader/"))
        {
            SetupMaterialWithBlendMode(material, (BlendMode)material.GetFloat("_Mode"));
            SetupMaterialWithCullMode(material, (CullMode)material.GetFloat("_Cull"));
            return;
        }
        
        BlendMode blendMode = BlendMode.Opaque;
        CullMode cullMode = CullMode.Back;
        SpecialMode specialMode = SpecialMode.Off;
        // if (oldShader.name.Contains("/Transparent/Cutout/"))
        // {
        //     blendMode = BlendMode.Cutout;
        //     cullMode = CullMode.Off;
        // }
        // else if (oldShader.name.Contains("/Transparent/"))
        // {
        //     blendMode = BlendMode.Fade;
        //     cullMode = CullMode.Off;
        // }
        material.SetFloat("_Mode", (float)blendMode);
        material.SetFloat("_Cull", (float)cullMode);
        material.SetFloat("_Special", (float)specialMode);
    }

    public override void OnGUI(MaterialEditor materialEditor, MaterialProperty[] properties)
    {
        FindProperties(properties);
        m_MaterialEditor = materialEditor;
        material = materialEditor.target as Material;
        
        if (m_FirstTimeApply)
        {
            int renderQueue = material.renderQueue;
            MaterialChanged(material);
            material.renderQueue = renderQueue;
            m_FirstTimeApply = false;
        }
        
        ShaderPropertiesGUI(material);
        //渲染队列
        GUILayout.Space(5);
        GUILayout.BeginVertical("DD HeaderStyle");
        DoRenderQueueArea(materialEditor);
        GUILayout.EndVertical();
    }

    private void ShaderPropertiesGUI(Material material)
    {
        EditorGUI.BeginChangeCheck();
        {
            //材质球渲染设置
            GUILayout.BeginVertical("DD HeaderStyle");
            BlendModePopup();
            CullModePopup();
            SpecialModePopup();
            GUILayout.EndVertical();
            //PBR基础信息
            GUILayout.Space(5);
            GUILayout.BeginVertical("DD HeaderStyle");
            DoAlbedoArea(material);
            GUILayout.EndVertical();
            //SSS
            GUILayout.Space(5);
            GUILayout.BeginVertical("DD HeaderStyle");
            DoSSSArea(); 
            GUILayout.EndVertical();
            //丝袜效果
            GUILayout.Space(5);
            GUILayout.BeginVertical("DD HeaderStyle");
            DoDenierArea(); 
            GUILayout.EndVertical();
            //镭射效果
            GUILayout.Space(5);
            GUILayout.BeginVertical("DD HeaderStyle");
            DoLaserArea(); 
            GUILayout.EndVertical();
            //高光类型
            if ((SpecialMode)material.GetFloat("_SpecialMode") == SpecialMode.AnisotropicMode || (SpecialMode)material.GetFloat("_SpecialMode") == SpecialMode.UVAnisotropicMode)
            {
                GUILayout.Space(5);
                GUILayout.BeginVertical("DD HeaderStyle");
                DoSpecialArea(material);
                GUILayout.EndVertical();
            }
            //自定义光源
            GUILayout.Space(5);
            GUILayout.BeginVertical("DD HeaderStyle");
            DoAssistLightArea();
            GUILayout.EndVertical();
        }
        if (EditorGUI.EndChangeCheck())
        {
            foreach (UnityEngine.Object obj in blendMode.targets)
            {
                MaterialChanged((Material)obj);
            }
        }
    }

    public static void SetupMaterialWithCullMode(Material material, CullMode cullMode)
    {
        switch (cullMode)
        {
            case CullMode.Back:
                material.SetInt("_Cull", (int)UnityEngine.Rendering.CullMode.Back);
                material.DisableKeyword("_CULLOFF_ON");
                break;
            case CullMode.Front:
                material.SetInt("_Cull", (int)UnityEngine.Rendering.CullMode.Front);
                material.DisableKeyword("_CULLOFF_ON");
                break;
            case CullMode.Off:
                material.SetInt("_Cull", (int)UnityEngine.Rendering.CullMode.Off);
                material.EnableKeyword("_CULLOFF_ON");
                break;
            default:
                break;
        }
    }

    public static void SetupMaterialWithSpecialMode(Material material, SpecialMode specialMode)
    {
        switch (specialMode)
        {
            case SpecialMode.Off:
                material.DisableKeyword("_ANISOTROPIC_ON");
                material.DisableKeyword("_UVANISOTROPIC_ON");
                break;
            case SpecialMode.AnisotropicMode:
                material.EnableKeyword("_ANISOTROPIC_ON");
                material.DisableKeyword("_UVANISOTROPIC_ON");
                break;
            case SpecialMode.UVAnisotropicMode:
                material.EnableKeyword("_UVANISOTROPIC_ON");
                material.DisableKeyword("_ANISOTROPIC_ON");
                break;
            default:
                break;
        }
    }

    private void DoAlbedoArea(Material material)
    {
        //颜色
        m_MaterialEditor.TexturePropertySingleLine(Styles.mainTexText, _MainTex);
        m_MaterialEditor.ShaderProperty(_Color, "     主颜色");
        m_MaterialEditor.ShaderProperty(_Brightness, "     亮度");
        m_MaterialEditor.ShaderProperty(_Saturation, "     饱和度");
        m_MaterialEditor.ShaderProperty(_Hardness, "     暗部透光度");
        //透明模式
        if ((BlendMode)material.GetFloat("_Mode") == BlendMode.Cutout)
        {
            m_MaterialEditor.ShaderProperty(_Cutoff,"     透明度裁切");
        }
        //法线
        Line();
        m_MaterialEditor.TexturePropertySingleLine(Styles.bumpMapText, _BumpMap);
        m_MaterialEditor.ShaderProperty(_BumpScale, "     法线强度");
        m_MaterialEditor.TexturePropertySingleLine(Styles.detailBumpMapText, _DetailNormalMap);
        m_MaterialEditor.ShaderProperty(_DetailBumpScale, "     细节法线强度");
        //自发光
        Line();
        m_MaterialEditor.TexturePropertySingleLine(Styles.emissionMapText, _EmissionMap);
        m_MaterialEditor.ShaderProperty(_EmissionColor, "     自发光颜色");
        //PBR功能贴图喝参数
        Line();
        m_MaterialEditor.TexturePropertySingleLine(Styles.gmaMapText, _GMAMap);
        m_MaterialEditor.ShaderProperty(_Smoothness, "     光滑度");
        m_MaterialEditor.ShaderProperty(_Metallic, "     金属度");
        m_MaterialEditor.ShaderProperty(_AOStrength, "     AO强度");
        //阴影功能贴图喝MatCap贴图
        Line();
        m_MaterialEditor.TexturePropertySingleLine(Styles.sldMapText, _SLDMap);
        m_MaterialEditor.TexturePropertySingleLine(Styles.matcapText, _MatCapTex);
        m_MaterialEditor.ShaderProperty(_MatCapColor, "     MatCap颜色");
        m_MaterialEditor.ShaderProperty(_AmbientColor, "     环境光颜色");
    }

    private void DoSpecialArea(Material material)
    {
        if ((SpecialMode)material.GetFloat("_SpecialMode") == SpecialMode.AnisotropicMode)
        {
            m_MaterialEditor.TexturePropertySingleLine(Styles.hairDataMapText, _HairDataMap);
            m_MaterialEditor.TexturePropertySingleLine(Styles.tangentNormalMapText, _TangentNormalMap);
            m_MaterialEditor.ShaderProperty(_PrimarySpecularColor, "     第一层高光颜色");
            m_MaterialEditor.ShaderProperty(_SecondarySpecularColor, "     第二层高光颜色");
            m_MaterialEditor.ShaderProperty(_PrimarySpecularExponent, "     第一层高光范围");
            m_MaterialEditor.ShaderProperty(_PrimarySpecularShift, "     第一层高光偏移值");
            m_MaterialEditor.ShaderProperty(_SecondarySpecularExponent, "     第二层高光范围");
            m_MaterialEditor.ShaderProperty(_SecondarySpecularShift, "     第二层高光偏移值");
        }
        else if ((SpecialMode)material.GetFloat("_SpecialMode") == SpecialMode.UVAnisotropicMode)
        {
            m_MaterialEditor.TexturePropertySingleLine(Styles.hairDataMapText, _HairDataMap);
            m_MaterialEditor.ShaderProperty(_PrimarySpecularColor, "     第一层高光颜色");
            m_MaterialEditor.ShaderProperty(_SecondarySpecularColor, "     第二层高光颜色");
            m_MaterialEditor.ShaderProperty(_PrimarySpecularExponent, "     第一层高光范围");
            m_MaterialEditor.ShaderProperty(_PrimarySpecularShift, "     第一层高光偏移值");
            m_MaterialEditor.ShaderProperty(_SecondarySpecularExponent, "     第二层高光范围");
            m_MaterialEditor.ShaderProperty(_SecondarySpecularShift, "     第二层高光偏移值");
        }
        else
        {
            return;
        }
    }

    private void DoSSSArea()
    {
        //SSS
        m_MaterialEditor.ShaderProperty(_SSS_Toggle, "SSS效果开关");
        if (_SSS_Toggle.floatValue == 1)
        {
            m_MaterialEditor.TexturePropertySingleLine(Styles.sssMapText, _SSSMap);
            m_MaterialEditor.ShaderProperty(_SubSurface, "     厚度值");
        }
    }

    private void DoDenierArea()
    {
        //丝袜
        m_MaterialEditor.ShaderProperty(_Denier_Toggle, "丝袜效果开关");
        if (_Denier_Toggle.floatValue == 1)
        {
            m_MaterialEditor.ShaderProperty(_RimPower, "透光范围");
            m_MaterialEditor.ShaderProperty(_Denier, "拉伸值");
            m_MaterialEditor.ShaderProperty(_SkinColor, "皮肤颜色");
            m_MaterialEditor.ShaderProperty(_StockingColor, "丝袜颜色");
        }
    }

    private void DoLaserArea()
    {
        //镭射
        m_MaterialEditor.ShaderProperty(_Laser_Toggle, "镭射效果开关");
        if (_Laser_Toggle.floatValue == 1)
        {
            m_MaterialEditor.TexturePropertySingleLine(Styles.laserMapText, _LaserMap);
            m_MaterialEditor.ShaderProperty(_LaserIntensity, "     镭射效果强度");
        }
    }

    private void DoAssistLightArea()
    {
        m_MaterialEditor.ShaderProperty(_CustomLightDir1, "自定义主光源方向");
        m_MaterialEditor.ShaderProperty(_CustomLightDir2, "自定义副光源方向");
        m_MaterialEditor.ShaderProperty(_CustomLightDir2Color, "自定义副光源颜色");
        m_MaterialEditor.ShaderProperty(_CustomLightDir2Softness, "自定义副光源范围");
        m_MaterialEditor.ShaderProperty(_BrightnessInShadow, "自定义副光源在阴影中的强度");
        m_MaterialEditor.ShaderProperty(_BrightnessInOcclusion, "自定义副光源在自定义阴影中的强度");
    }
    private void DoRenderQueueArea(MaterialEditor materialEditor)
    {
        materialEditor.RenderQueueField();
    }

    public static void SetupMaterialWithBlendMode(Material material, BlendMode blendMode)
    {
        switch (blendMode)
        {
            case BlendMode.Opaque:
                material.SetOverrideTag("RenderType", "Opaque");
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                material.SetInt("_ZWrite", 1);
                material.SetInt("_ZTest", (int)UnityEngine.Rendering.CompareFunction.LessEqual);
                material.DisableKeyword("_ALPHATEST_ON");
                material.DisableKeyword("_ALPHABLEND_ON");
                material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                break;
            case BlendMode.Cutout:
                material.SetOverrideTag("RnderType", "TransparentCutout");
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.Zero);
                material.SetInt("_ZWrite", 1);
                material.SetInt("_ZTest", (int)UnityEngine.Rendering.CompareFunction.LessEqual);
                material.EnableKeyword("_ALPHATEST_ON");
                material.DisableKeyword("_ALPHABLEND_ON");
                material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                break;
            case BlendMode.Fade:
                material.SetOverrideTag("RnderType", "Transparent");
                material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.SrcAlpha);
                material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
                material.SetInt("_ZWrite", 0);
                material.SetInt("_ZTest", (int)UnityEngine.Rendering.CompareFunction.Less);
                material.DisableKeyword("_ALPHATEST_ON");
                material.EnableKeyword("_ALPHABLEND_ON");
                material.DisableKeyword("_ALPHAPREMULTIPLY_ON");
                break;
            //case BlendMode.Transparent:
            //    material.SetOverrideTag("RnderType", "TransparentCutout");
            //    material.SetInt("_SrcBlend", (int)UnityEngine.Rendering.BlendMode.One);
            //    material.SetInt("_DstBlend", (int)UnityEngine.Rendering.BlendMode.OneMinusSrcAlpha);
            //    material.SetInt("_ZWrite", 0);
            //    material.SetInt("_ZTest", (int)UnityEngine.Rendering.CompareFunction.Less);
            //    material.DisableKeyword("_ALPHATEST_ON");
            //    material.DisableKeyword("_ALPHABLEND_ON");
            //    material.EnableKeyword("_ALPHAPREMULTIPLY_ON");
            //    break;
            default:
                break;
        }
    }
    private void BlendModePopup() 
    {
        EditorGUI.showMixedValue = blendMode.hasMixedValue;
        BlendMode mode = (BlendMode)blendMode.floatValue;
        EditorGUI.BeginChangeCheck();
        mode = (BlendMode)EditorGUILayout.Popup(Styles.renderingMode, (int)mode, Styles.blendNames);
        if (EditorGUI.EndChangeCheck())
        {
            m_MaterialEditor.RegisterPropertyChangeUndo("Rendering Mode");
            blendMode.floatValue = (float)mode;
        }
        EditorGUI.showMixedValue = false;
    }

    private void CullModePopup()
    {
        EditorGUI.showMixedValue = cullMode.hasMixedValue;
        CullMode mode = (CullMode)cullMode.floatValue;
        EditorGUI.BeginChangeCheck();
        mode = (CullMode)EditorGUILayout.Popup(Styles.cullMode, (int)mode, Styles.cullBlendNames);
        if (EditorGUI.EndChangeCheck())
        {
            m_MaterialEditor.RegisterPropertyChangeUndo("Rendering CullMode");
            cullMode.floatValue = (float)mode;
        }
        EditorGUI.showMixedValue = false;
    }

    private void SpecialModePopup()
    {
        EditorGUI.showMixedValue = specialMode.hasMixedValue;
        SpecialMode mode = (SpecialMode)specialMode.floatValue;
        EditorGUI.BeginChangeCheck();
        mode = (SpecialMode)EditorGUILayout.Popup(Styles.specialMode, (int)mode, Styles.specialNames);
        if (EditorGUI.EndChangeCheck())
        {
            m_MaterialEditor.RegisterPropertyChangeUndo("Special Mode");
            specialMode.floatValue = (float)mode;
        }
        EditorGUI.showMixedValue = false;
    }

    private static void MaterialChanged(Material material)
    {
        SetupMaterialWithBlendMode(material, (BlendMode)material.GetFloat("_Mode"));
        SetupMaterialWithCullMode(material, (CullMode)material.GetFloat("_Cull"));
        SetupMaterialWithSpecialMode(material, (SpecialMode)material.GetFloat("_SpecialMode"));
    }
    
    private static void Line()
    {
        GUI.color = new Color(.42f,.42f,.42f,1f);
        GUILayout.Label("--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------");
        GUI.color = Color.white;
    }
}

