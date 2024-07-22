#ifndef URP_SHADER_INCLUDE_LYX_LIGHT
#define URP_SHADER_INCLUDE_LYX_LIGHT

#include "LYX_MATH.hlsl"
#include "LYX_INPUT.hlsl"
#include "LYX_DFG.hlsl"

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < 直接光 direct light >
void GetDirectLightBRDF(ObjData objData, LitData litData, inout LitResultData lit)
{
    // 镜面反射
    float3 F = GetDirectF(objData, litData); // 菲涅尔函数
    float D = GetDirectD(objData, litData); // 法线分布函数
    float G = GetDirectG(objData, litData); // 几何函数

    // 配平系数
    float3 kd = (1 - F) * (1 - objData.metallic) * 0.96; // 0.96 = 1 - 0.04

    // 输出
    lit.DirectDiffuse = kd * objData.albedo.rgb; // 漫反射
    lit.DirectSpecular = D * F * G * 0.25 / (litData.nl * objData.nv) * PI; // 镜面反射 (Torrance–Sparrow BRDF)
}

// < 间接光 Indirect light >
void GetIndirectLightBRDF(ObjData objData, inout LitResultData litResultData)
{
    // 菲涅尔函数
    float3 F = GetIndirectF(objData); // 此处考虑了粗糙度对 F 的影响,unity 自身的没有考虑,所以会发现 unity lit在完全粗糙的时候 F 会比我们的亮很多

    // 漫反射
    float3 diffuse = SampleSH(objData.normalWS) * objData.albedo.rgb;

    // 镜面反射
    float mip = objData.realRoughness * (1.7 - 0.7 * objData.realRoughness) * 6;
    float4 cube = unity_SpecCube0.SampleLevel(samplerunity_SpecCube0, objData.reflectDir, mip);
    float3 IBL = DecodeHDREnvironment(cube, unity_SpecCube0_HDR);

    float2 BRDF = _EnvBRDF.Sample(sampler_Linear_Clamp, float2(objData.nv * 0.99, objData.roughness * 0.99)).rg;

    float3 specular = IBL * (F * BRDF.r + BRDF.g);
    
    // 配平系数
    float3 kd = (1 - F) * (1 - objData.metallic) * 0.96;

    // 输出
    litResultData.InDirectDiffuse = kd * diffuse;
    litResultData.InDirectSpecular = specular;
}

// < 普通光照 light >
void ApplyLight(ObjData objData, LitData mainLitData, inout float4 output)
{
    // 初始化光照结果结构体
    LitResultData lit = (LitResultData)0;

    // AO
    output.rgb *= objData.AO;

    // 主光源直接光
    GetDirectLightBRDF(objData, mainLitData, lit);
    output.rgb = (lit.DirectDiffuse + lit.DirectSpecular) * mainLitData.color * mainLitData.remapNl;

    // 间接光
    GetIndirectLightBRDF(objData, lit);
    output.rgb += lit.InDirectDiffuse + lit.InDirectSpecular;

    // 额外光
    LitData additionalLitData;
    for (int i = 0; i < GetAdditionalLightsCount(); ++i)
    {
        SetLitData(objData, GetAdditionalLight(i, objData.positionWS, 1), additionalLitData);
        GetDirectLightBRDF(objData, additionalLitData, lit);

        // 额外光源直接光
        output.rgb += (lit.DirectDiffuse + lit.DirectSpecular) * additionalLitData.color * additionalLitData.remapNl;
    }
}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < 次表面散射 SSS >
void ApplySSS(LitData mainLitData, Varyings input, inout float4 output)
{
    float thickness = _ThicknessTex.Sample(sampler_Linear_Clamp, input.uv.xy).r * _Thickness;
    float4 _SSS = _SSSTex.Sample(sampler_Linear_Clamp, float2(mainLitData.remapNl, 1 / thickness));
    _SSS.rgb *= _SSSColor.rgb;
    _SSS.rgb = 1 - _SSSColor.a * (1 - _SSS.rgb);
    
    output.rgb *= _SSS.rgb;
}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < MatCap >
void ApplyMatCap(ObjData objData, inout float4 output)
{
    float3 normalVS = mul((float3x3)UNITY_MATRIX_V, objData.normalWS);
    float4 matCap = _MatCapTex.Sample(sampler_Linear_Clamp, normalVS * 0.5 + 0.5);
    matCap.rgb *= _MatCapColor.rgb;

    #if _MATCAP_BLEND_MULTIPLY
        output.rgb *= 1 - _MatCapColor.a * (1 - matCap.rgb);
    #elif _MATCAP_BLEND_ADD
        output.rgb += matCap.rgb * _MatCapColor.a;
    #endif
}

// < 边缘光 >
void ApplyRim(ObjData objData, inout float4 output)
{
    half3 rim = 1 - objData.nv;
    rim = P(rim, 1 / _RimWidth);
    rim *= _RimColor.rgb * _RimColor.a;
    
    output.rgb += rim;
}

#endif