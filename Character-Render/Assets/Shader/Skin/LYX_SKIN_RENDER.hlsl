#ifndef URP_SHADER_INCLUDE_LYX_SKIN_RENDER
#define URP_SHADER_INCLUDE_LYX_SKIN_RENDER

#include "../GlobalHlsl/LYX_GLOBAL.hlsl"
#include "LYX_SKIN_INPUT.hlsl"

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < 光照 light >
float3 DirectLight(ObjData objData, LitData litData, inout LitResultData lit)
{
    KelemenSzirmayKalosBRDF(
        _SSSTex, _SpecularBRDF, objData.albedo,
        objData.roughness, objData.thickness,
        litData.halfDirNoNormalizeWS, litData.nl, litData.remapNl, litData.nh, litData.vh,
        lit);
    
    lit.DirectDiffuse += (1 - lit.DirectDiffuse) * _SSSColor.rgb * _SSSColor.a;
    lit.DirectDiffuse *= litData.diffuseColor;
    lit.DirectSpecular *= litData.specularColor * _Specular;

    return (lit.DirectDiffuse + lit.DirectSpecular) * litData.shadowAtten;
}

float3 InDirectLight(ObjData objData, LitData litData, inout LitResultData lit)
{
    IndirectLightSkin( objData.albedo, objData.normalWS, lit);

    return (lit.InDirectDiffuse + lit.InDirectSpecular) * litData.shadowAtten;
}

void ApplyLight(ObjData objData, LitData mainLitData, inout float4 output)
{
    LitResultData lit = (LitResultData)0; // 初始化光照结果结构体
    output.rgb = DirectLight(objData, mainLitData, lit); // 添加主光源直接光
    output.rgb += InDirectLight(objData, mainLitData, lit); // 添加间接光

    // 额外光
    LitData addiLitData;
    for (int i = 0; i < GetAdditionalLightsCount(); ++i)
    {
        SetLitData(objData, GetAdditionalLight(i, objData.positionWS, 1), addiLitData); // 初始化额外光源数据
        output.rgb += DirectLight(objData, addiLitData, lit); // 添加额外光源直接光
    }

    output.rgb *= objData.AO;
}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < 次表面散射 SSS >
void ApplySSS(ObjData objData, LitData mainLitData, inout float4 output)
{
    float3 sss = 1;

    output.rgb *= sss;
}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < MatCap >
void ApplyMatCap(ObjData objData, inout float4 output)
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
void ApplyRim(ObjData objData, inout float4 output)
{
    half3 rim = 1 - objData.nv;
    rim = P(rim, 1 / _RimWidth);
    rim *= _RimColor.rgb * _RimColor.a;
    
    output.rgb += rim;
}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < 后处理 >
void ApplyPostPorcess(inout float4 output)
{
    output.rgb *= _Brightness;
    output.rgb = Saturation(output.rgb, _Saturation);
    output.rgb = Contrast(output.rgb, _Contrast);
}

#endif