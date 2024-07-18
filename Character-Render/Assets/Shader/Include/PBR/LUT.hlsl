#ifndef URP_SHADER_INCLUDE_LUT
#define URP_SHADER_INCLUDE_LUT

#include "COLOR_SPACE.hlsl"

//LUT贴图模拟雷瑟效果
//laserMap: 镭射的LUT贴图
//sampleName: sampleName贴图的采样器名称
//diff: 混合目标颜色
//NdotV: 菲尼尔计算
//laserIntensity: Lut混合强度
float3 LUT_Laser_GammaToLinear(Texture2D laserMap, SAMPLER(sampleName), float3 diff, float NdotV, float laserIntensity)
{
    float2 LasertUV = float2(1 - NdotV, 0.5);
    float3 Lasert = SAMPLE_TEXTURE2D(laserMap, sampleName, LasertUV).xyz;
    Lasert = GammaToLinearSpace(Lasert);
    diff = lerp(diff, diff * Lasert + Lasert, laserIntensity);
    return diff;
}

//LUT贴图模拟雷瑟效果
//SSSMap: SSS的LUT贴图
//SampleName: SSS贴图的采样器名称
//SSS: 用于输出的计算完成的SSS效果
//NdotL: 光照
//mask: SSS效果的mask，控制哪里有和强弱
//subSurface: 控制厚度的参数
//shadow: 阴影
float3 LUT_SSS_GammaToLinear(Texture2D sssMap, SAMPLER(sampleName), float3 SSS, float NdotL, float mask, float subSurface, float shadow)
{
    //SSS的厚度计算
    float SSS_Thickness = mask * subSurface;
    
    if (0.02 < SSS_Thickness)
    {
        //SSS_UV计算
        half HalfLambert = NdotL * 0.5 + 0.5;
        half2 SSS_UV = half2(HalfLambert * (shadow * 0.5 + 0.5), SSS_Thickness);
        //SSS_LUT贴图采样
        SSS = SAMPLE_TEXTURE2D(sssMap, sampleName, SSS_UV).rgb;
        // SSS = GammaToLinearSpace(SSS);
    }
    else
    {
        SSS = NdotL * shadow;
    }
    return SSS;
}


//基础SSS效果
//Params : sssMap - SSSLut贴图
//         SAMPLER - 贴图采样器
//         NdotL - 兰伯特光照
//         mask - SSS厚度值(可使用贴图/滑杆)
//return : 返回计算后的效果
float3 LUT_SSS_GammaToLinear(Texture2D sssMap, SAMPLER(sampleName), float NdotL, float mask)
{
    //SSS的厚度计算
    half HalfLambert = NdotL * 0.5 + 0.5;
    half2 SSS_UV = half2(HalfLambert, mask);
    //SSS_LUT贴图采样
    float3 SSS = SAMPLE_TEXTURE2D(sssMap, sampleName, SSS_UV).rgb;
    // SSS = GammaToLinearSpace(SSS);
    return SSS;
}
#endif

