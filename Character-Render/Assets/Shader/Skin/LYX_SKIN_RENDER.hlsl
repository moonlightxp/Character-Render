#ifndef URP_SHADER_INCLUDE_LYX_SKIN_RENDER
#define URP_SHADER_INCLUDE_LYX_SKIN_RENDER

#include "../GlobalHlsl/LYX_MATH.hlsl"
#include "../GlobalHlsl/LYX_INPUT.hlsl"
#include "../GlobalHlsl/LYX_BRDF.hlsl"

#include "LYX_SKIN_INPUT.hlsl"

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < 光照 light >
void ApplyLight(SkinObjData objData, SkinLitData mainLitData, inout float4 output)
{
    // 初始化光照结果结构体
    LitResultData lit = (LitResultData)0;

    // 主光源直接光
    KelemenSzirmayKalosBRDF(
        _SSSTex, _SpecularBRDF, objData.albedo,
        objData.roughness, objData.thickness,
        mainLitData.halfDirNoNormalizeWS, mainLitData.nl, mainLitData.remapNl, mainLitData.nh, mainLitData.vh,
        lit);
    
    lit.DirectDiffuse += (1 - lit.DirectDiffuse) * _SSSColor.rgb * _SSSColor.a;
    lit.DirectDiffuse *= mainLitData.diffuseColor * objData.AO;
    lit.DirectSpecular *= mainLitData.specularColor * _Specular;
    
    output.rgb = (lit.DirectDiffuse + lit.DirectSpecular) * mainLitData.shadowAtten;

    // 间接光
    IndirectLightSkin( objData.albedo, objData.normalWS, lit);
    output.rgb += lit.InDirectDiffuse + lit.InDirectSpecular;

    // 额外光
    SkinLitData addiLitData;
    for (int i = 0; i < GetAdditionalLightsCount(); ++i)
    {
        SetSkinLitData(objData, GetAdditionalLight(i, objData.positionWS, 1), addiLitData);
    
        KelemenSzirmayKalosBRDF(
            _SSSTex, _SpecularBRDF, objData.albedo,
            objData.roughness, objData.thickness,
            addiLitData.halfDirNoNormalizeWS, addiLitData.nl, addiLitData.remapNl, addiLitData.nh, addiLitData.vh,
            lit);
    
        // 额外光源直接光
        lit.DirectDiffuse *= (1 - lit.DirectDiffuse) * _SSSColor.rgb * _SSSColor.a;
        lit.DirectDiffuse *= addiLitData.diffuseColor * objData.AO;
        lit.DirectSpecular *= addiLitData.specularColor * _Specular;
    
        output.rgb += (lit.DirectDiffuse + lit.DirectSpecular) * addiLitData.shadowAtten;
    }
}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < 次表面散射 SSS >
void ApplySSS(SkinObjData objData, SkinLitData mainLitData, inout float4 output)
{
    float3 sss = LutSSS(_SSSTex, objData.thickness, mainLitData.remapNl);
    sss += (1 - sss) * _SSSColor.rgb;
    sss = 1 - _SSSColor.a * (1 - sss);
    
    output.rgb *= sss;
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