﻿#ifndef URP_SHADER_INCLUDE_LYX_PBR_RENDER
#define URP_SHADER_INCLUDE_LYX_PBR_RENDER

#include "../GlobalHlsl/LYX_MATH.hlsl"
#include "../GlobalHlsl/LYX_INPUT.hlsl"
#include "../GlobalHlsl/LYX_BRDF.hlsl"

#include "LYX_PBR_INPUT.hlsl"

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < 光照 light >
void ApplyLight(SkinObjData objData, SkinLitData mainLitData, inout float4 output)
{
    // 初始化光照结果结构体
    LitResultData lit = (LitResultData)0;

    // 主光源直接光
    CookTorranceBRDF(
        objData.roughness, objData.roughness2, objData.metallic, objData.albedo, objData.nv, objData.f0,
        mainLitData.nl, mainLitData.remapNl, mainLitData.nh, mainLitData.vh,
        lit);

    lit.DirectDiffuse *= mainLitData.diffuseColor * objData.AO;
    lit.DirectSpecular *= mainLitData.specularColor;
    
    output.rgb = (lit.DirectDiffuse + lit.DirectSpecular) * mainLitData.shadowAtten;

    // 间接光
    IndirectLightBRDF(objData.roughness, objData.realRoughness, objData.metallic, objData.albedo, objData.normalWS, objData.nv, objData.reflectDir, objData.f0, lit);

    output.rgb += lit.InDirectDiffuse + lit.InDirectSpecular;

    // 额外光
    SkinLitData addiLitData;
    for (int i = 0; i < GetAdditionalLightsCount(); ++i)
    {
        SetSkinLitData(objData, GetAdditionalLight(i, objData.positionWS, 1), addiLitData);
        CookTorranceBRDF(
            objData.roughness, objData.roughness2, objData.metallic, objData.albedo, objData.nv, objData.f0,
            addiLitData.nl, addiLitData.remapNl, addiLitData.nh, addiLitData.vh,
            lit);
    
        // 额外光源直接光
        lit.DirectDiffuse *= addiLitData.diffuseColor * objData.AO;
        lit.DirectSpecular *= addiLitData.specularColor;
    
        output.rgb += (lit.DirectDiffuse + lit.DirectSpecular) * addiLitData.shadowAtten;
    }
}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < MatCap >
void ApplyMatCap(SkinObjData objData, inout float4 output)
{
    float3 normalVS = mul((float3x3)UNITY_MATRIX_V, objData.normalWS);
    float4 matCap = _MatCapTex.Sample(sampler_Linear_Clamp, normalVS.xy * 0.5 + 0.5);
    matCap.rgb *= _MatCapColor.rgb;

    #if _MATCAP_BLEND_MULTIPLY
        output.rgb *= 1 - _MatCapColor.a * (1 - matCap.rgb);
    #elif _MATCAP_BLEND_ADD
        output.rgb += matCap.rgb * _MatCapColor.a;
    #endif
}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < 边缘光 >
void ApplyRim(SkinObjData objData, inout float4 output)
{
    half3 rim = 1 - objData.nv;
    rim = P(rim, 1 / _RimWidth);
    rim *= _RimColor.rgb * _RimColor.a;
    
    output.rgb += rim;
}

#endif