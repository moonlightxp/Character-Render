Shader "SURender/URP/PBR_Base" 
{
    Properties
    {
        //主帖图
        _MainTex ("主贴图", 2D) = "white" {}
        _Color("主颜色", Color) = (1, 1, 1, 1)
        _BumpMap ("法线贴图", 2D) = "bump" {}
        _DetailNormalMap ("细节法线贴图", 2D) = "bump" {}
        _BumpScale("法线强度", Float) = 1.0
        //功能贴图(金属度，光滑度。AO)
        _GMAMap ("功能贴图 (光滑度 / 金属度 / AO)", 2D) = "white" {}
        _Smoothness("光滑度", Range(0.0, 0.99)) = 0.99
        [Gamma] _Metallic("金属度", Range(0.0, 1.0)) = 1.0
        //功能贴图(SSSMask / 辅光Mask / Denier)
        _SLDMap ("功能贴图(SSSMask / 辅光Mask / Denier)", 2D) = "black" {}
        _AOStrength ("AO强度", Range(0.0, 1.0)) = 1.0
        //自发光
        _EmissionMap ("自发光贴图", 2D) = "black" {}
        [HDR]_EmissionColor ("自发光颜色", Color) = (0, 0, 0, 0)
        //MatCap
        _MatCapTex ("MatCap贴图", 2D) = "black" {}
        _MatCapColor ("MatCap颜色", Color) = (0, 0, 0, 0)
        //环境色
        [HDR]_AmbientColor("环境光颜色", Color) = (0,0,0,0)
        //透明裁切
        _Cutoff("透明度裁切", Range(0.0, 1.0)) = 0.5
        //主光方向
        [Vector3]_CustomLightDir1 ("自定义主光源方向", Vector) = (0, 0, 0, 0)
        //辅光参数
        [Vector3]_CustomLightDir2 ("自定义副光源方向",Vector) = (1, 1, 1, 1)
        [HDR]_CustomLightDir2Color ("自定义副光源颜色", Color) = (0, 0, 0, 0)
        _CustomLightDir2Softness ("自定义副光源范围", float) = 1
        _BrightnessInOcclusion ("自定义副光源在AO中的强度", Range(0.0, 1.0)) = 1
        _BrightnessInShadow ("自定义副光源在自定义阴影中的强度", Range(0.0, 1.0)) = 0.5
        //LOL各向异性计算
        _HairDataMap ("各向异性Mask贴图", 2D) = "white" {}
        _TangentNormalMap ("自定义各向异性法线贴图", 2D) = "bump" {}
        [HDR]_PrimarySpecularColor ("第一层高光颜色", Color) = (1,1,1,1)
        _PrimarySpecularExponent ("第一层高光范围", float) = 0
        _PrimarySpecularShift ("第一层高光偏移值", float) = 0
        [HDR]_SecondarySpecularColor ("第二层高光颜色", Color) = (1,1,1,1)
        _SecondarySpecularExponent ("第二层高光范围", float) = 0
        _SecondarySpecularShift ("第二层高光偏移值", float) = 0
        //效果调整
        _Brightness ("亮度", Range(0,3)) = 1
	    _Saturation ("饱和度", Range(0,3)) = 1
        _Hardness ("暗部透光度", Range(0,1)) = 1
        //SSS效果
        [Toggle(_SSS_ON)] _SSS_Toggle ("SSS效果开关", int) = 0
        _SSSMap ("SSS贴图", 2D) = "vwhite" {}
        _SubSurface ("厚度值", Range(0.0, 1.0)) = 1
        //丝袜效果
        [Toggle(_DENIER_ON)] _Denier_Toggle ("丝袜效果开关", int) = 0
        _RimPower ("透光范围", float) = 10
        _Denier ("拉伸值", Range(5 ,120)) = 25
        _SkinColor ("皮肤颜色", Color) = (0,0,0,0)
        _StockingColor ("丝袜颜色", Color) = (0,0,0,0)
        //镭射效果
        [Toggle(_LASER_ON)] _Laser_Toggle ("镭射效果开关", int) = 0
        _LaserMap ("镭射贴图", 2D) = "white" {}
        _LaserIntensity ("镭射强度", Range(0, 1)) = 0.5
        //EditorArea
        _Mode("__mode", Float) = 0.0
        _SrcBlend("__src", Float) = 1.0
        _DstBlend("__dst", Float) = 0.0
        _ZWrite("__zw", Float) = 1.0
        _ZTest("__zt", Float) = 4.0
        _Cull("__cull", Float) = 2.0
        _SpecialMode("__special", Int) = 0.0
        _LightMode("__light", Float) = 0.0
    }
    
    Category
    {
        HLSLINCLUDE
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
        
            #pragma prefer_hlslcc gles//支持OPENGL ES2平台的宏
            #pragma exclude_renderers d3d11_9x//排除d3d11_9x
        
            #pragma shader_feature _ _ALPHATEST_ON _ALPHABLEND_ON//透明相关
            #pragma shader_feature _CULLOFF_ON//透明裁切
            #pragma shader_feature _ANISOTROPIC_ON//使用烘焙出来的切线贴图来计算各向异性高光
            #pragma shader_feature _UVANISOTROPIC_ON //UV控制切线信息计算各向异性高光
            #pragma shader_feature _GGXANI_ON //GGX各向异性
            #pragma shader_feature _LIGHTMODE_ON
            #pragma shader_feature _SSS_ON //SSS计算
            #pragma shader_feature _DENIER_ON //丝袜计算
            #pragma shader_feature _LASER_ON //SSS计算
            
            //禁用 光照贴图，方向光照贴图，动态光照贴图，不应用任何光照探针或每顶点光照
            #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
            #pragma skip_variants LIGHTPROBE_SH UNITY_SINGLE_PASS_STEREO
        
            //接收阴影的关键字
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT
        
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Assets/Shader/Include/PBR/PBR_CORE.hlsl"
            #include "PBR_BASE_PROPERTIES.hlsl"
        ENDHLSL
        
        SubShader
        {
            Tags { "Queue"="Geometry" "RenderType"="Opaque" "RenderPipeline" = "UniversalPipeline"}
            Pass
            {
                Name "FORWARD_BASE"
                Tags{"LightMode" = "UniversalForward"}
    
                Blend [_SrcBlend] [_DstBlend]
                ColorMask RGBA
                Cull [_Cull]
                ZWrite [_ZWrite]
                ZTest [_ZTest]
    
                HLSLPROGRAM
                #include "PBR_BASE_FUNCTION.hlsl"
                ENDHLSL
            }
            
            Pass
            {
                Name "ShadowCaster"
                Tags{"LightMode" = "ShadowCaster"}
                
                HLSLPROGRAM
                #include "PBR_SHADOW_FUNCTION.hlsl"
                ENDHLSL
            }
    
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
    CustomEditor "PBR_Base_Urp_Inspector"
}
