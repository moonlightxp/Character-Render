Shader "LYX/Hair"
{
    Properties
    {
        [Header(_ Main _)] [Space(3)]
        _MainTex ("主帖图", 2D) = "white" {}
        [NoScaleOffset] _BumpMap ("法线贴图", 2D) = "bump" {}
        [HDR] _Color ("主颜色", Color) = (1, 1, 1, 1)
        _BumpScale ("法线强度", Range(0, 1)) = 0.03
        
        [Space(40)]
        [Header(_ Lighting _)] [Space(3)]
        [NoScaleOffset] _SmoothnessTex ("光滑度贴图", 2D) = "white" {}
        [NoScaleOffset] _AOTex ("AO 贴图", 2D) = "white" {}

        [Header(_ Diffuse _)] [Space(3)]
        _HalfLambert("半兰伯特系数", Range(0, 1)) = 0.5

        [Header(_ Specular _)] [Space(3)]
        [KeywordEnum(LIGHT, CUSTOM, MIX)] _SPECULAR_COLOR_TYPE ("高光模式", Float) = 0
        _SpecularColor ("高光颜色", Color) = (1, 1, 1, 1)
        _Smoothness ("光滑度", Range(0, 1)) = 0
        _Specular ("高光强度", Range(0, 10000)) = 1
        _AnisoT ("切线方向拉伸", Range(0.001, 0.999)) = 0.5
        _AnisoB ("副切线方向拉伸", Range(0.001, 0.999)) = 0.5
        _OffsetT ("高光偏移", Range(0.001, 0.999)) = 0.5

        [Header(_ AO _)] [Space(3)]
        _AOColor ("AO 颜色", Color) = (0, 0, 0, 1)

        [Space(40)]
        [Header(_ SSS _)] [Space(3)]
        [NoScaleOffset] _ThicknessTex ("厚度图", 2D) = "white" {}
        _SSSColor ("次表面散射颜色", Color) = (1, 1, 1, 1)
        _Thickness ("厚度", Range(0, 5)) = 1
        
        [Space(40)]
        [Header(_ MatCap _)] [Space(3)]
        [NoScaleOffset] _MatCapTex ("MatCap 贴图", 2D) = "black" {}
        [HDR] _MatCapColor ("MatCap 颜色", Color) = (1, 1, 1, 1)
        [KeywordEnum(MULTIPLY, ADD)] _MATCAP_BLEND ("MatCap 混合模式", Float) = 0
        
        [Space(40)]
        [Header(_ Rim _)] [Space(3)]
        [HDR] _RimColor ("边缘光颜色", Color) = (1, 1, 1, 1)
        _RimWidth ("边缘光宽度", Range(0.001, 1)) = 1

        [Space(40)]
        [Header(_ Render Setting _)] [Space(3)]
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Int) = 4
        [Enum(Off, 0, On, 1)] _ZWrite ("ZWrite", Float) = 1

        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("SrcBlend Mode", Int) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("DstBlend Mode", Int) = 10

        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Int) = 2
    }

    /*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

    SubShader
    {
        Tags
        {
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "IgnoreProjector" = "True"
        }

        Pass
        {
            Name "ForwardLit"

            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            Blend [_SrcBlend] [_DstBlend]
            ZTest [_ZTest]
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 2.0

            #define _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOW_SOFT
            #define _SHADOWS_SOFT_HIGH
            #define ADDITIONAL_LIGHT_CALCULATE_SHADOWS

            #pragma shader_feature_local _MATCAP_BLEND_MULTIPLY _MATCAP_BLEND_ADD
            #pragma shader_feature_local _SPECULAR_COLOR_TYPE_LIGHT _SPECULAR_COLOR_TYPE_CUSTOM _SPECULAR_COLOR_TYPE_MIX
            
            #pragma vertex Vertex
            #pragma fragment Fragment

            /*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 基础光照核心库

            Texture2D _MainTex;
            Texture2D _BumpMap;
            
            Texture2D _SmoothnessTex;
            Texture2D _AOTex;
            
            Texture2D _SSSTex;
            Texture2D _ThicknessTex;
            
            Texture2D _MatCapTex;
            
            SamplerState sampler_Linear_Clamp;
            SamplerState sampler_Linear_Repeat;
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Color;
            
                float _HalfLambert;
                float _Smoothness;
                float _BumpScale;
                float4 _SpecularColor;
                float _Specular;
                float4 _AOColor;
                float _AnisoT;
                float _AnisoB;
                float _OffsetT;


                float4 _SSSColor;
                float _Thickness;

                float4 _RimColor;
                float _RimWidth;
            
                float4 _MatCapColor;
            CBUFFER_END

            #include "LYX_HAIR_RENDER.hlsl"

            /*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

            Varyings Vertex(Attributes input)
            {
                Varyings output;
                
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS.xyz = TransformObjectToWorldDir(input.tangentOS.xyz + _OffsetT * input.normalOS);
                output.tangentWS.w = input.tangentOS.w;
                output.bitangentWS = cross(output.normalWS, output.tangentWS.xyz) * output.tangentWS.w;
                output.bitangentWS2 = TransformObjectToWorldDir(cross(input.normalOS, input.tangentOS.xyz));

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);

                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                output.fogCoord = ComputeFogFactor(output.positionCS.z);
                
                return output;
            }

            float4 Fragment(Varyings input) : SV_Target
            {
                float4 baseMap = _MainTex.Sample(sampler_Linear_Clamp, input.uv.xy);
                float4 output = baseMap * _Color;
                
                ObjData objData;
                SetObjData(input, output, objData);

                LitData mainLitData;
                SetLitData(objData, GetMainLight(objData.shadowCoord), mainLitData);
                
                ApplyLight(objData, mainLitData, output);
                ApplyMatCap(objData, output);
                ApplyRim(objData, output);

                return output;
            }
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}