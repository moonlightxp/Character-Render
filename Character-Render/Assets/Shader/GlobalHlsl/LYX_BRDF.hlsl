#ifndef URP_SHADER_INCLUDE_LYX_BRDF
#define URP_SHADER_INCLUDE_LYX_BRDF

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 法线分布函数 D (Normal Distribution Function)
 估算在受到表面粗糙度的影响下，取向方向与中间向量一致的微平面的数量
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

// < Trowbridge-Reitz GGX >
float GGX(float roughness2, float nh)
{
    float x = P2(nh) * (roughness2 - 1) + 1.00001; // 防止除 0
    return roughness2 / (PI * P2(x));
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 菲涅尔函数 F (Fresnel equation)
 描述在不同的表面角下表面反射的光线所占的比率
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

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

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 几何函数 G (Geometry function)
 描述了微平面自成阴影的属性,当一个平面相对比较粗糙的时候,平面表面上的微平面有可能挡住其他的微平面从而减少表面所反射的光线。
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

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

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
预积分次表面散射
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
float3 LutSSS(Texture2D SSSTex, float thickness, float nl)
{
    return SSSTex.Sample(sampler_Linear_Clamp, float2(nl, 1 / thickness)).rgb;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
直接光
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

// < CookTorrance BRDF,用于标准 BRDF) >
void CookTorranceBRDF(
    float roughness, float roughness2, float metallic, float4 albedo, float nv, float3 f0,
    float nl, float remapNl, float nh, float vh,
    inout LitResultData lit)
{
    // 镜面反射
    float3 F = FresnelSchlick(vh, f0); // 菲涅尔函数
    float D = GGX(roughness2, nh); // 法线分布函数
    float k = P2(roughness + 1) * 0.125;
    float G = SmithGGX(nv, nl, k); // 几何函数

    // 配平系数
    float3 kd = (1 - F) * (1 - metallic) * 0.96; // 0.96 = 1 - 0.04

    // 输出
    lit.DirectDiffuse = kd * albedo.rgb * remapNl; // 漫反射
    lit.DirectSpecular = D * F * G * 0.25 / (nl * nv) * PI * (nl - HALF_MIN_SQRT); // 镜面反射
}

// <  Kelemen/Szirmay-Kalos BRDF,用于皮肤 >
void KelemenSzirmayKalosBRDF(Texture2D SSSTex, Texture2D BRDFTex, float4 albedo, float roughness, float thickness, float3 halfDirNoNormalizeWS, float nl, float remapNl, float nh, float vh, inout LitResultData lit)
{
    float F = FresnelSchlick(vh, 0.028);
    
    float BRDF = BRDFTex.Sample(sampler_Linear_Clamp, float2(nh, roughness)).r;
    BRDF = P(2 * BRDF, 10);
    float specular = max(BRDF * F / dot(halfDirNoNormalizeWS, halfDirNoNormalizeWS), 0);

    lit.DirectDiffuse = LutSSS(SSSTex, thickness, remapNl) * albedo.rgb; // 漫反射
    lit.DirectSpecular = specular * (nl - HALF_MIN_SQRT); // 镜面反射
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
间接光
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/

// < PBR BRDF (球谐函数 + 采样Cube map,用于标准 PBR) >
void IndirectLightBRDF(
    float roughness, float realRoughness, float metallic, float4 albedo, float3 normalWS, float nv, float3 reflectDir, float3 f0,
    inout LitResultData lit)
{
    // 菲涅尔函数 (和 URP 实现不同,这里加入了 roughness 的影响,物理更正确,高粗糙度下菲涅尔更暗)
    float3 F = FresnelSchlickRoughness(nv, roughness, f0);

    // 漫反射 (球谐)
    float3 diffuse = SampleSH(normalWS) * albedo.rgb;

    // 镜面反射 (采样天空盒 cube)
    float mip = realRoughness * (1.7 - 0.7 * realRoughness) * 6;
    float4 environmentCube = unity_SpecCube0.SampleLevel(samplerunity_SpecCube0, reflectDir, mip);
    float3 IBL = DecodeHDREnvironment(environmentCube, unity_SpecCube0_HDR);

    float2 BRDF = _EnvBRDF.Sample(sampler_Linear_Clamp, float2(nv * 0.99, roughness * 0.99)).rg;

    float3 specular = IBL * (F * BRDF.r + BRDF.g);

    // 配平系数
    float3 kd = (1 - F) * (1 - metallic) * 0.96;

    // 输出
    lit.InDirectDiffuse = kd * diffuse;
    lit.InDirectSpecular = specular;
}

// < Skin BRDF (球谐函数,用于皮肤) >
void IndirectLightSkin(float4 albedo, float3 normalWS, inout LitResultData lit)
{
    // 输出
    lit.InDirectDiffuse = SampleSH(normalWS) * albedo.rgb;
    lit.InDirectSpecular = 0;
}

#endif