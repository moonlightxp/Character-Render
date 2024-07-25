#ifndef URP_SHADER_INCLUDE_LYX_GLOBAL_LIGHT
#define URP_SHADER_INCLUDE_LYX_GLOBAL_LIGHT

// < 直接光 > ==================================================================================================================================================================================================================================
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 CookTorrance BRDF

 用于标准 BRDF
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
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

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 Kelemen/Szirmay-Kalos BRDF

 用于皮肤
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
void KelemenSzirmayKalosBRDF(Texture2D SSSTex, Texture2D BRDFTex, float4 albedo, float roughness, float thickness, float3 halfDirNoNormalizeWS, float nl, float remapNl, float nh, float vh, inout LitResultData lit)
{
    float F = FresnelSchlick(vh, 0.028);

    float BRDF = BRDFTex.Sample(sampler_Linear_Clamp, float2(nh, roughness)).r;
    BRDF = P(2 * BRDF, 10);
    float specular = max(BRDF * F / dot(halfDirNoNormalizeWS, halfDirNoNormalizeWS), 0);

    lit.DirectDiffuse = LutSSS(SSSTex, thickness, remapNl) * albedo.rgb; // 漫反射
    lit.DirectSpecular = specular * (nl - HALF_MIN_SQRT); // 镜面反射
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 GGX 各向异性高光

 用于头发
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
void GGXAnisoHair(float4 albedo, float remapNl, float th, float bh, float nh, float roughT, float roughB, inout LitResultData lit)
{
    lit.DirectDiffuse = remapNl * albedo.rgb; // 漫反射
    lit.DirectSpecular = GGXAniso(th, bh, nh, roughT, roughB); // 镜面反射
}

// < 间接光 > ==================================================================================================================================================================================================================================
/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
PBR BRDF

球谐函数 + 采样 Cube map,用于标准 PBR
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
void IndirectLightBRDF(
    float2 BRDF, float roughness, float realRoughness, float metallic, float4 albedo, float3 normalWS, float nv, float3 reflectDir, float3 f0,
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

    float3 specular = IBL * (F * BRDF.r + BRDF.g);

    // 配平系数
    float3 kd = (1 - F) * (1 - metallic) * 0.96;

    // 输出
    lit.InDirectDiffuse = kd * diffuse;
    lit.InDirectSpecular = specular;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 Skin

 球谐函数,用于皮肤
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
void IndirectLightSkin(float4 albedo, float3 normalWS, inout LitResultData lit)
{
    // 输出
    lit.InDirectDiffuse = SampleSH(normalWS) * albedo.rgb;
    lit.InDirectSpecular = 0;
}

/*>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>
 Hair

 球谐函数,用于皮肤
<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<*/
void IndirectLightHair(float4 albedo, float3 normalWS, inout LitResultData lit)
{
    // 输出
    lit.InDirectDiffuse = SampleSH(normalWS) * albedo.rgb;
    lit.InDirectSpecular = 0;
}

#endif