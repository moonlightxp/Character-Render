#ifndef URP_SHADER_INCLUDE_PBR_SHADOW_FUNCTION
#define URP_SHADER_INCLUDE_PBR_SHADOW_FUNCTION

float4 ApplyShadowBias(Attributes IN, float3 lightDirection)
{
    float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
    float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
    
    //Shadows.hlsl-ApplyShadowBias
    float invNdotL = 1.0 - saturate(dot(lightDirection, normalWS));
    float scale = invNdotL * _ShadowBias.y;
    // normal bias is negative since we want to apply an inset normal offset
    positionWS = lightDirection * _ShadowBias.xxx + positionWS;
    positionWS = normalWS * scale.xxx + positionWS;
    
    float4 positionCS = TransformWorldToHClip(positionWS);
    #if UNITY_REVERSED_Z
    positionCS.z = min(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #else
    positionCS.z = max(positionCS.z, positionCS.w * UNITY_NEAR_CLIP_VALUE);
    #endif
    return positionCS;
}

Varings vert(Attributes input)
{
    Varings output;
                    
    output.positionCS = ApplyShadowBias(input, _LightDirection);
    output.uv1 = input.uv;
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.tangentWS.xyz = normalize(TransformObjectToWorldDir(input.tangentOS.xyz));
    output.tangentWS.w = input.tangentOS.w * GetOddNegativeScale();
    // output.bitangentWS = GetBitangentWS(output.normalWS, output.tangentWS);
    output.bitangentWS = cross(output.normalWS, output.tangentWS.xyz) * output.tangentWS.w;
    return output;
}
                
real4 frag(Varings input) : SV_Target
{
    #if _ALPHATEST_ON
    half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv1);
    clip(col.a - _Cutoff);
    #endif
    return 0;
}

#endif

