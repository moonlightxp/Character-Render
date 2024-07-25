#ifndef URP_SHADER_INCLUDE_DENIER
#define URP_SHADER_INCLUDE_DENIER

#include "COLOR_SPACE.hlsl"

//采样LUT贴图。转换色彩空间并融合到颜色输出
//diff: 混合目标颜色
//skinColor: 皮肤颜色
//srockColor: 丝袜颜色（会收到颜色贴图影响）
//denierValue: denier值
//denierPower: denier范围---菲尼尔
//denierMask: mask贴图
float3 DENIER_GammaToLinear(float3 diff, float4 skinColor, float4 srockColor, float NdotV, float denierValue, float denierPower, float denierMask, float oneMinesRef)
{
    float rim = pow(saturate(1 - NdotV), denierPower / 10);
    float denier = (denierValue - 5) /115;
    
    //因为丹尼尔贴图不能画黑色，所以这里乘以自己用来增加对比度
    float density = max(rim, denier * (1 - denierMask * denierMask));
    float3 stockings = lerp(skinColor.rgb, srockColor.rgb * diff, density);
    stockings = GammaToLinearSpace(stockings) * oneMinesRef;
    
    //为了节省一张贴图，所以使用丹尼尔贴图来取值做mask--所以丹尼尔贴图不能有近乎于黑色的地方。取值范围是 0.1-1
    diff = lerp(diff, stockings, step(0.01, denierMask));
    return diff;
}

#endif

