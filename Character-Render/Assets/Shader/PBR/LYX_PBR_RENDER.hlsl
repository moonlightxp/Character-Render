#ifndef URP_SHADER_INCLUDE_LYX_PBR_RENDER
#define URP_SHADER_INCLUDE_LYX_PBR_RENDER

#include "../GlobalHlsl/LYX_GLOBAL.hlsl"
#include "LYX_PBR_INPUT.hlsl"

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < 光照 light >
float3 DirectLight(ObjData objData, LitData litData, LitResultData lit)
{
    CookTorranceBRDF(
        objData.roughness, objData.roughness2, objData.metallic, objData.albedo, objData.nv, objData.f0,
        litData.nl, litData.remapNl, litData.nh, litData.vh,
        lit);
    
    lit.DirectDiffuse *= litData.diffuseColor * objData.AO;
    lit.DirectSpecular *= litData.specularColor;
    
    return (lit.DirectDiffuse + lit.DirectSpecular) * litData.shadowAtten;
}

float3 InDirectLight(ObjData objData, LitResultData lit)
{
    IndirectLightBRDF(objData.BRDF, objData.roughness, objData.realRoughness, objData.metallic, objData.albedo, objData.normalWS, objData.nv, objData.reflectDir, objData.f0, lit);
    
    return lit.InDirectDiffuse + lit.InDirectSpecular;
}

void ApplyLight(ObjData objData, LitData mainLitData, inout float4 output)
{
    LitResultData lit = (LitResultData)0; // 初始化光照结果结构体
    output.rgb = DirectLight(objData, mainLitData, lit); // 添加主光源直接光
    output.rgb += InDirectLight(objData, lit); // 添加间接光
    
    LitData addiLitData;
    for (int i = 0; i < GetAdditionalLightsCount(); ++i)
    {
        SetLitData(objData, GetAdditionalLight(i, objData.positionWS, 1), addiLitData); // 初始化额外光源数据
        output.rgb += DirectLight(objData, addiLitData, lit); // 添加额外光源直接光
    }
}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// < 次表面散射 SSS >
void ApplySSS(ObjData objData, LitData mainLitData, inout float4 output)
{
    float3 sss = 1;

    output.rgb *= sss;
}

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

float3 MatCap(float3 normalWS)
{
    float3 normalVS = mul((float3x3)UNITY_MATRIX_V, normalWS);
    float4 matCap = _MatCapTex.Sample(sampler_Linear_Clamp, normalVS.xy * 0.5 + 0.5);

    return matCap.rgb *= _MatCapColor.rgb;
}

// < MatCap >
void ApplyMatCap(ObjData objData, inout float4 output)
{
    float3 matCap = MatCap(objData.normalWS);

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