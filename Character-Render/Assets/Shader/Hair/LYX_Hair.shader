Shader "LYX/Hair"
{
    Properties
    {
        [Header(_ Main _)] [Space(3)]
        _MainTex ("主帖图", 2D) = "white" {}
        [NoScaleOffset] _BumpMap ("法线贴图", 2D) = "bump" {}
        [HDR] _Color ("主颜色", Color) = (1, 1, 1, 1)
        _BumpScale ("法线强度", Range(0, 1)) = 0.03
        
        [Header(_ Diffuse _)] [Space(3)]
        _HalfLambert("半兰伯特系数", Range(0, 1)) = 0.5

        [Header(_ Specular _)] [Space(3)]
        _AnisoShiftMask ("各项异性偏移贴图", 2D) = "white" {}
        [KeywordEnum(LIGHT, CUSTOM, MIX)] _SPECULAR_COLOR_TYPE ("高光模式", Float) = 0
        [Space(10)]
        [Hdr] _SpecularColor1 ("高光颜色 1", Color) = (1, 1, 1, 1)
        _Offset1 ("高光偏移 1", Range(-1, 1)) = 0
        _AnisoT1 ("切线方向拉伸 1", Range(0.001, 0.999)) = 0.5
        _AnisoB1 ("副切线方向拉伸 1", Range(0.001, 0.999)) = 0.5
        [Space(10)]
        [Hdr] _SpecularColor2 ("高光颜色2", Color) = (1, 1, 1, 1)
        _Offset2 ("高光偏移2", Range(-1, 1)) = 0
        _AnisoT2 ("切线方向拉伸 2", Range(0.001, 0.999)) = 0.5
        _AnisoB2 ("副切线方向拉伸 2", Range(0.001, 0.999)) = 0.5
        
        [Space(40)]
        [Header(_ AO _)] [Space(3)]
        _AOColor ("AO 颜色", Color) = (0, 0, 0, 1)
        
        [Space(40)]
        [Header(_ MatCap _)] [Space(3)]
        [NoScaleOffset] _MatCapTex ("MatCap 贴图", 2D) = "white" {}
        [HDR] _MatCapColor ("MatCap 颜色", Color) = (1, 1, 1, 1)
        [KeywordEnum(MULTIPLY, ADD)] _MATCAP_BLEND ("MatCap 混合模式", Float) = 0
        
        [Space(40)]
        [Header(_ Rim _)] [Space(3)]
        [HDR] _RimColor ("边缘光颜色", Color) = (1, 1, 1, 1)
        _RimWidth ("边缘光宽度", Range(0.001, 1)) = 1
        
        [Space(40)]
        _Clip ("透明度裁剪", Range(0, 1)) = 1

        [Space(40)]
        [Header(_ Render Setting _)] [Space(3)]
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
            Name "Depth"

            //LightweightForward
            //SRPDefaultUnlit
            Tags
            {
                "LightMode" = "SRPDefaultUnlit"
            }
            
            ZTest Less
            ZWrite On
            Cull [_Cull]
            ColorMask 0
            
            HLSLPROGRAM
            #pragma target 2.0
            
            #pragma vertex Vertex
            #pragma fragment Fragment

            /*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl" // 基础光照核心库

            Texture2D _MainTex;
            SamplerState sampler_Linear_Clamp;
            SamplerState sampler_Linear_Repeat;

            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float _Clip;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct Varyings
            {
                float4 positionCS : SV_POSITION;
                float2 uv : TEXCOORD0;
            };

            /*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

            Varyings Vertex(Attributes input)
            {
                Varyings output;

                output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
                output.uv = TRANSFORM_TEX(input.uv, _MainTex);
                
                return output;
            }

            float4 Fragment(Varyings input) : SV_Target
            {
                float4 baseMap = _MainTex.Sample(sampler_Linear_Clamp, input.uv);
                clip(baseMap.a - _Clip);
                
                return 0;
            }
            ENDHLSL
        }

        Pass
        {
            Name "ForwardLit"

            Tags
            {
                "LightMode" = "UniversalForward"
            }
            
            ZTest Equal
            ZWrite Off
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

            Texture2D _AnisoShiftMask;
            
            Texture2D _SSSTex;
            Texture2D _ThicknessTex;
            
            Texture2D _MatCapTex;
            
            SamplerState sampler_Linear_Clamp;
            SamplerState sampler_Linear_Repeat;
            
            CBUFFER_START(UnityPerMaterial)
                float4 _MainTex_ST;
                float4 _Color;
            
                float _HalfLambert;
                float _BumpScale;
            
                float4 _SpecularColor1;
                float _Offset1;
                float _AnisoT1;
                float _AnisoB1;
            
                float4 _SpecularColor2;
                float _Offset2;
                float _AnisoT2;
                float _AnisoB2;

                float4 _AOColor;

                float4 _RimColor;
                float _RimWidth;
            
                float4 _MatCapColor;
            
                float _Clip;
            CBUFFER_END

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float2 uv2 : TEXCOORD1;
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

            #include "LYX_HAIR_RENDER.hlsl"

            /*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

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
                output.uv.zw = input.uv2;
                output.fogCoord = ComputeFogFactor(output.positionCS.z);
                
                return output;
            }

            float4 Fragment(Varyings input, float face : VFACE) : SV_Target
            {
                float4 baseMap = _MainTex.Sample(sampler_Linear_Clamp, input.uv.xy);
                float4 output = baseMap;
                
                ObjData objData = (ObjData)0;
                SetObjData(input, output, face, objData);
                
                LitData mainLitData = (LitData)0;
                SetLitData(objData, GetMainLight(objData.shadowCoord), mainLitData);
                
                ApplyLight(objData, mainLitData, output);
                ApplyMatCap(objData, output);
                ApplyRim(objData, output);
                
                clip(baseMap.a - _Clip);
                
                return output;
            }
            ENDHLSL
        }

        UsePass "Universal Render Pipeline/Lit/ShadowCaster"
    }
}