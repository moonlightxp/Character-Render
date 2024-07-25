#ifndef URP_SHADER_INCLUDE_LYX_LIBRARY_LIGHT
#define URP_SHADER_INCLUDE_LYX_LIBRARY_LIGHT

// < 高光 > --------------------------------------------------------------------------------------------------------------------------------
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 法线分布函数 D (Normal Distribution Function)
 
 估算在受到表面粗糙度的影响下，
 取向方向与中间向量一致的微平面的数量
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
// < Trowbridge-Reitz GGX >
float GGX(float roughness2, float nh)
{
    float x = P2(nh) * (roughness2 - 1) + 1.00001; // 防止除 0
    return roughness2 / (PI * P2(x));
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 菲涅尔函数 F (Fresnel equation)
 
 描述在不同的表面角下表面反射的光线所占的比率
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
// < 直接光 F >
float3 FresnelSchlick(float vh, float3 f0)
{
    return f0 + (1 - f0) * OneMinusP5(vh);
}

// < 直接光 F (皮肤) >
float FresnelSchlick(float vh, float f0)
{
    return f0 + (1 - f0) * OneMinusP5(vh);
}

// < 间接光 F,计算了粗糙度的影响 >
float3 FresnelSchlickRoughness(float nv, float roughness, float3 f0)
{
    return f0 + (max(f0, 1 - roughness) - f0) * OneMinusP5(nv);
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 几何函数 G (Geometry function)
 
 描述了微平面自成阴影的属性,
 当一个平面相对比较粗糙的时候,
 平面表面上的微平面有可能挡住其他的微平面从而减少表面所反射的光线
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
float SchlickGGX(float dot, float k)
{
    return dot / (dot * (1 - k) + k);
}
  
float SmithGGX(float nv, float nl, float k)
{
    float ggx1 = SchlickGGX(nl, k); // 视线方向的几何遮挡
    float ggx2 = SchlickGGX(nv, k); // 光线方向的几何阴影
	
    return ggx1 * ggx2;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
GGX 各向异性高光
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
float GGXAniso(float th, float bh, float nh, float roughT, float roughB)
{
    float f = P2(th) / P2(roughT) + P2(bh) / P2(roughB) + P2(nh);
    return 1 / (P2(f) * roughT * roughB);
}

// < 漫反射 > --------------------------------------------------------------------------------------------------------------------------------
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
预积分次表面散射

返回添加了次表面散射的漫反射结果,直接作为漫反射使用
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
float3 LutSSS(Texture2D SSSTex, float thickness, float nl)
{
    return SSSTex.Sample(sampler_Linear_Clamp, float2(nl, 1 / thickness)).rgb;
}

#endif