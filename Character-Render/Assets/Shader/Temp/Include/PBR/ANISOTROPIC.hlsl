#ifndef URP_SHADER_INCLUDE_ANISOTROPIC
#define URP_SHADER_INCLUDE_ANISOTROPIC

float3 AnisotropyByTex(Texture2D normalMap, Texture2D dateMap, SAMPLER(sampleName), float3 worldNormal, float3 worldHalfDir, float3 diff, float4 PrimarySpecularColor, float4 SecondarySpecularColor, float2 uv, float PrimaryShift, float SecondaryShift, float PrimaryExponent, float SecondaryExponent, float NdotL, float shadow)
{
    //贴图采样
    // float3 CustomTangent = TEX_2D(_TangentNormalMap,IN.texcoords.xy).rgb * 2 - 1;
    float3 CustomTangent = SAMPLE_TEXTURE2D(normalMap,sampleName, uv).rgb * 2 - 1;
    // float3 _HairDataMap_Var = TEX_2D(_HairDataMap, IN.texcoords.xy).xyz;
    float3 _HairDataMap_Var = SAMPLE_TEXTURE2D(dateMap, sampleName, uv).xyz;
    
    //Shift偏移值
    float2 T_Shift = float2(PrimaryShift, SecondaryShift) + _HairDataMap_Var.x;
    float3 Primary = normalize(worldNormal * T_Shift.x + CustomTangent);
    float3 Secondary = normalize(worldNormal * T_Shift.y + CustomTangent);
    
    //LOL的方式
    //第一层
    float PdotH = dot(Primary, worldHalfDir);
    float pow_PdotH = exp2(log2(sqrt(1.0 - PdotH * PdotH)) * PrimaryExponent);
    PdotH = clamp(PdotH + 1.0, 0.0, 1.0);
    PdotH = (PdotH * -2.0 + 3.0) * (PdotH * PdotH);
    float3 PrimaryColor = PdotH * pow_PdotH * PrimarySpecularColor.rgb;
    //第二层
    float SdotH = dot(Secondary, worldHalfDir);
    float pow_SdotH = exp2(log2(sqrt(1.0 - SdotH * SdotH)) * SecondaryExponent);
    SdotH = clamp(SdotH + 1.0, 0.0, 1.0);
    SdotH = (SdotH * -2.0 + 3.0) * (SdotH * SdotH);
    float3 SecondaryColor = SdotH * pow_SdotH * SecondarySpecularColor.rgb;
    //高光合并
    float3 all_Specular = (PrimaryColor + SecondaryColor) * _HairDataMap_Var.y * _HairDataMap_Var.z;
    all_Specular = clamp(all_Specular, float3(0.0, 0.0, 0.0), float3(100.0, 100.0, 100.0));
    diff += all_Specular * NdotL * shadow;
    return diff;
}

float3 AnisotropyByUV(Texture2D dateMap, SAMPLER(sampleName), float3 bitangentWS, float3 worldNormal, float3 worldHalfDir, float3 diff, float4 PrimarySpecularColor, float4 SecondarySpecularColor, float2 uv, float PrimaryShift, float SecondaryShift, float PrimaryExponent, float SecondaryExponent, float NdotL, float shadow)
{
    // float3 _HairDataMap_Var = TEX_2D(_HairDataMap, IN.texcoords.xy).xyz;
    float3 _HairDataMap_Var = SAMPLE_TEXTURE2D(dateMap, sampleName, uv).xyz;
    float2 T_Shift = float2(PrimaryShift, SecondaryShift) + _HairDataMap_Var.x;
    float3 Primary = normalize(worldNormal * T_Shift.x + bitangentWS);
    float3 Secondary = normalize(worldNormal * T_Shift.y + bitangentWS);
    //第一层高光
    float PdotH = dot(Primary, worldHalfDir);
    float pow_PdotH = exp2(log2(sqrt(1.0 - PdotH * PdotH)) * PrimaryExponent);
    PdotH = clamp(PdotH + 1.0, 0.0, 1.0);
    PdotH = (PdotH * -2.0 + 3.0) * (PdotH * PdotH);
    float3 PrimaryColor = PdotH * pow_PdotH * PrimarySpecularColor.rgb;
    //第二层高光
    float SdotH = dot(Secondary, worldHalfDir);
    float pow_SdotH = exp2(log2(sqrt(1.0 - SdotH * SdotH)) * SecondaryExponent);
    SdotH = clamp(SdotH + 1.0, 0.0, 1.0);
    SdotH = (SdotH * -2.0 + 3.0) * (SdotH * SdotH);
    float3 SecondaryColor = SdotH * pow_SdotH * SecondarySpecularColor.rgb;
    //高光合并
    float3 all_Specular = (PrimaryColor + SecondaryColor) * _HairDataMap_Var.y * _HairDataMap_Var.z;
    all_Specular = clamp(all_Specular, float3(0.0, 0.0, 0.0), float3(100.0, 100.0, 100.0));
    diff += all_Specular * NdotL * shadow;
    return diff;
}

#endif

