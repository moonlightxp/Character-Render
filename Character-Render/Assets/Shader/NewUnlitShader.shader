Shader "Unlit/NewUnlitShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Hardness ("暗部透光度", Range(0,1)) = 1
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            Tags
            {
                "LightMode" = "UniversalForward"
            }
                
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            //接收阴影的关键字
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS
            #pragma multi_compile _ _MAIN_LIGHT_SHADOWS_CASCADE
            #pragma multi_compile_fragment _ _SHADOWS_SOFT

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct appdata
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 positionCS : SV_POSITION;
                float3 normalWS : TEXCOORD1;
                float3 positionWS : TEXCOORD4;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Hardness;

            v2f vert (appdata v)
            {
                v2f o;
                o.positionCS = TransformObjectToHClip(v.positionOS.xyz);
                o.normalWS = TransformObjectToWorldNormal(v.normalOS);
                o.positionWS = TransformObjectToWorld(v.positionOS.xyz);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                return o;
            }

            float4 frag (v2f input) : SV_Target
            {
                input.normalWS = normalize(input.normalWS);
                #ifdef MAIN_LIGHT_CALCULATE_SHADOWS
                    float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);  //获取阴影坐标
                #else
                    float4 shadowCoord = float4(0, 0, 0, 0);
                #endif
                Light myLight = GetMainLight(shadowCoord);
                float shadowAtten = myLight.shadowAttenuation;//光影相关

                half NdotL = dot(input.normalWS, myLight.direction);
                half halfLambert = NdotL * _Hardness + (1.0 - _Hardness);
                NdotL = saturate(NdotL);
                // shadowAtten *= step(0.001, NdotL);
                shadowAtten *= NdotL;
                shadowAtten = shadowAtten * _Hardness + (1 - _Hardness);
                
                half4 col = tex2D(_MainTex, input.uv);
                col *= shadowAtten;
                return col;
            }
            ENDHLSL
        }
    }
Fallback "Standard"
}
