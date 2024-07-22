Shader "LYX/SkinRender"
{
    Properties
    {
        _MainTex ("主帖图", 2D) = "white" {}
        _BumpMap ("法线贴图", 2D) = "bump" {}
        _Color ("主颜色", Color) = (1, 1, 1, 1)
        _BumpScale ("法线强度", Range(0, 1)) = 1
        
        [Space(50)]
        [NoScaleOffset] _MetallicTex ("金属度贴图", 2D) = "white" {}
        [NoScaleOffset] _SmoothnessTex ("光滑度贴图", 2D) = "white" {}
        [NoScaleOffset] _AOTex ("AO 贴图", 2D) = "white" {}
        [NoScaleOffset] _EnvBRDF ("环境 LUT", 2D) = "white" {}
        _HalfLambert("半兰伯特系数", Range(0, 1)) = 0.5
        _Metallic ("金属度", Range(0, 1)) = 0
        _Smoothness ("光滑度", Range(0, 1)) = 0
        _AO ("AO 强度", Range(0, 1)) = 0
        
        [Space(50)]
        [NoScaleOffset] _SSSTex ("次表面散射预积分贴图", 2D) = "black" {}
        [NoScaleOffset] _ThicknessTex ("厚度图", 2D) = "white" {}
        _SSSColor ("次表面散射颜色", Color) = (1, 1, 1, 1)
        _Thickness ("厚度", Range(0, 3)) = 1
        
        [Space(50)]
        [NoScaleOffset] _MatCapTex ("MatCap 贴图", 2D) = "black" {}
        _MatCapColor ("MatCap 颜色", Color) = (1, 1, 1, 1)
        [KeywordEnum(MULTIPLY, ADD)] _MATCAP_BLEND ("MatCap 混合模式", Float) = 0
        
        [Space(50)]
        [hdr] _RimColor ("边缘光颜色", Color) = (1, 1, 1, 1)
        _RimWidth ("边缘光宽度", Range(0.001, 1)) = 1

        [Space(50)]
        [Enum(UnityEngine.Rendering.CompareFunction)] _ZTest ("ZTest", Int) = 4
        [Enum(Off, 0, On, 1)] _ZWrite ("ZWrite", Float) = 1

        [Enum(UnityEngine.Rendering.BlendMode)] _SrcBlend ("SrcBlend Mode", Int) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _DstBlend ("DstBlend Mode", Int) = 10

        [Enum(UnityEngine.Rendering.CullMode)] _Cull ("Cull Mode", Int) = 2
    }

    SubShader
    {
        Tags
        {
            "Queue" = "Geometry"
            "RenderPipeline" = "UniversalPipeline"
            "RenderType" = "Opaque"
            "ShaderModel" = "4.5"
        }

        Pass
        {
            Name "MAIN"

            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            Blend [_SrcBlend] [_DstBlend]
            ZTest [_ZTest]
            ZWrite [_ZWrite]
            Cull [_Cull]

            HLSLPROGRAM
            #pragma target 4.5
            
            #define _MAIN_LIGHT_SHADOWS
            #define _SHADOWS_SOFT_HIGH
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile _ _SHADOW_SOFT

            #pragma shader_feature_local _MATCAP_BLEND_MULTIPLY _MATCAP_BLEND_ADD
            
            #define ADDITIONAL_LIGHT_CALCULATE_SHADOWS
            
            #pragma vertex Vertex
            #pragma fragment Fragment

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 基础光照核心库

            Texture2D _MainTex;
            Texture2D _MetallicTex; 
            Texture2D _SmoothnessTex;
            Texture2D _AOTex;
            Texture2D _BumpMap;
            Texture2D _EnvBRDF;
            
            Texture2D _SSSTex;
            Texture2D _ThicknessTex;
            
            Texture2D _MatCapTex;
            
            SamplerState sampler_Linear_Clamp;
            SamplerState sampler_Linear_Repeat;
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _BumpMap_ST;
                float4 _Color;
            
                float _HalfLambert;
                float _Metallic;
                float _Smoothness;
                float _AO;
                float _BumpScale;
            
                float4 _SSSColor;
                float _Thickness;

                float4 _RimColor;
                float _RimWidth;
            
                float4 _MatCapColor;
            CBUFFER_END
            
            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
                float4 tangentOS : TANGENT;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float3 positionWS : TEXCOORD1;

                float3 normalWS : TEXCOORD2;
                float4 tangentWS : TEXCOORD3;
                float3 bitangentWS : TEXCOORD4;

                float4 uv : TEXCOORD0;
                float fogCoord : TEXCOORD6;
            };
            #include "LYX_LIGHT.hlsl"

            //-------------------------------------------------------------------------------------------------------------------------------------
            Varyings Vertex(Attributes input)
            {
                Varyings output;
                
                output.normalWS = TransformObjectToWorldNormal(input.normalOS);
                output.tangentWS.xyz = TransformObjectToWorldDir(input.tangentOS.xyz);
                output.tangentWS.w = input.tangentOS.w;
                output.bitangentWS = cross(output.normalWS, output.tangentWS.xyz) * output.tangentWS.w;

                output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
                output.positionCS = TransformWorldToHClip(output.positionWS);

                output.uv.xy = TRANSFORM_TEX(input.uv, _MainTex);
                output.uv.zw = TRANSFORM_TEX(input.uv, _BumpMap);
                output.fogCoord = ComputeFogFactor(output.positionCS.z);
                
                return output;
            }

            float4 Fragment(Varyings input) : SV_Target
            {
                float4 baseMap = SAMPLE_TEXTURE2D(_MainTex, sampler_Linear_Clamp, input.uv);
                float4 output = baseMap * _Color;
                
                ObjData objData;
                SetObjData(input, output, objData);

                LitData mainLitData;
                SetLitData(objData, GetMainLight(objData.shadowCoord), mainLitData);
                
                ApplyLight(objData, mainLitData, output);
                ApplySSS(mainLitData, input, output);
                ApplyMatCap(objData, output);
                ApplyRim(objData, output);

                return output;
            }
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}