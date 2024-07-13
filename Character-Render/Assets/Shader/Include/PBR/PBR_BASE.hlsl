#ifndef STARUNION_HLSL
#define STARUNION_HLSL

//------------⬇⬇⬇⬇⬇⬇灯光相关的计算⬇⬇⬇⬇⬇⬇-------------
//Common
real LerpWhiteTo(real b, real t)
{
    real oneMinusT = 1.0 - t;
    return oneMinusT + b * t;
}

real3 LerpWhiteTo(real3 b, real t)
{
    real oneMinusT = 1.0 - t;
    return real3(oneMinusT, oneMinusT, oneMinusT) + b * t;
}


//Shadow
#if !defined(_RECEIVE_SHADOWS_OFF)
    #if defined(_MAIN_LIGHT_SHADOWS)
        #define MAIN_LIGHT_CALCULATE_SHADOWS
    #endif
#endif

// float4 _ShadowBias;
#define BEYOND_SHADOW_FAR(shadowCoord) shadowCoord.z <= 0.0 || shadowCoord.z >= 1.0
#define MAX_SHADOW_CASCADES 4

TEXTURE2D_SHADOW(_MainLightShadowmapTexture);
SAMPLER_CMP(sampler_MainLightShadowmapTexture);

#ifndef SHADER_API_GLES3
    CBUFFER_START(MainLightShadows)
#endif
    float4x4    _MainLightWorldToShadow[MAX_SHADOW_CASCADES + 1];
    half4       _MainLightShadowOffset0;
    half4       _MainLightShadowOffset1;
    half4       _MainLightShadowOffset2;
    half4       _MainLightShadowOffset3;
    half4       _MainLightShadowParams;  // (x: shadowStrength, y: 1.0 if soft shadows, 0.0 otherwise)
    float4      _MainLightShadowmapSize; // (xy: 1/width and 1/height, zw: width and height)
#ifndef SHADER_API_GLES3
    CBUFFER_END
#endif

struct ShadowSamplingData
{
    half4 shadowOffset0;
    half4 shadowOffset1;
    half4 shadowOffset2;
    half4 shadowOffset3;
    float4 shadowmapSize;
};

ShadowSamplingData GetMainLightShadowSamplingData()
{
    ShadowSamplingData shadowSamplingData;
    shadowSamplingData.shadowOffset0 = _MainLightShadowOffset0;
    shadowSamplingData.shadowOffset1 = _MainLightShadowOffset1;
    shadowSamplingData.shadowOffset2 = _MainLightShadowOffset2;
    shadowSamplingData.shadowOffset3 = _MainLightShadowOffset3;
    shadowSamplingData.shadowmapSize = _MainLightShadowmapSize;
    return shadowSamplingData;
}

real SampleShadow_GetTriangleTexelArea(real triangleHeight)
{
    return triangleHeight - 0.5;
}

void SampleShadow_GetTexelAreas_Tent_3x3(real offset, out real4 computedArea, out real4 computedAreaUncut)
{
    // Compute the exterior areas
    real offset01SquaredHalved = (offset + 0.5) * (offset + 0.5) * 0.5;
    computedAreaUncut.x = computedArea.x = offset01SquaredHalved - offset;
    computedAreaUncut.w = computedArea.w = offset01SquaredHalved;

    // Compute the middle areas
    // For Y : We find the area in Y of as if the left section of the isoceles triangle would
    // intersect the axis between Y and Z (ie where offset = 0).
    computedAreaUncut.y = SampleShadow_GetTriangleTexelArea(1.5 - offset);
    // This area is superior to the one we are looking for if (offset < 0) thus we need to
    // subtract the area of the triangle defined by (0,1.5-offset), (0,1.5+offset), (-offset,1.5).
    real clampedOffsetLeft = min(offset,0);
    real areaOfSmallLeftTriangle = clampedOffsetLeft * clampedOffsetLeft;
    computedArea.y = computedAreaUncut.y - areaOfSmallLeftTriangle;

    // We do the same for the Z but with the right part of the isoceles triangle
    computedAreaUncut.z = SampleShadow_GetTriangleTexelArea(1.5 + offset);
    real clampedOffsetRight = max(offset,0);
    real areaOfSmallRightTriangle = clampedOffsetRight * clampedOffsetRight;
    computedArea.z = computedAreaUncut.z - areaOfSmallRightTriangle;
}

void SampleShadow_GetTexelWeights_Tent_3x3(real offset, out real4 computedWeight)
{
    real4 dummy;
    SampleShadow_GetTexelAreas_Tent_3x3(offset, computedWeight, dummy);
    computedWeight *= 0.44444;//0.44 == 1/(the triangle area)
}

void SampleShadow_GetTexelWeights_Tent_5x5(real offset, out real3 texelsWeightsA, out real3 texelsWeightsB)
{
    // See _UnityInternalGetAreaPerTexel_3TexelTriangleFilter for details.
    real4 computedArea_From3texelTriangle;
    real4 computedAreaUncut_From3texelTriangle;
    SampleShadow_GetTexelAreas_Tent_3x3(offset, computedArea_From3texelTriangle, computedAreaUncut_From3texelTriangle);

    // Triangle slope is 45 degree thus we can almost reuse the result of the 3 texel wide computation.
    // the 5 texel wide triangle can be seen as the 3 texel wide one but shifted up by one unit/texel.
    // 0.16 is 1/(the triangle area)
    texelsWeightsA.x = 0.16 * (computedArea_From3texelTriangle.x);
    texelsWeightsA.y = 0.16 * (computedAreaUncut_From3texelTriangle.y);
    texelsWeightsA.z = 0.16 * (computedArea_From3texelTriangle.y + 1);
    texelsWeightsB.x = 0.16 * (computedArea_From3texelTriangle.z + 1);
    texelsWeightsB.y = 0.16 * (computedAreaUncut_From3texelTriangle.z);
    texelsWeightsB.z = 0.16 * (computedArea_From3texelTriangle.w);
}

// 5x5 Tent filter (45 degree sloped triangles in U and V)
void SampleShadow_ComputeSamples_Tent_5x5(real4 shadowMapTexture_TexelSize, real2 coord, out real fetchesWeights[9], out real2 fetchesUV[9])
{
    // tent base is 5x5 base thus covering from 25 to 36 texels, thus we need 9 bilinear PCF fetches
    real2 tentCenterInTexelSpace = coord.xy * shadowMapTexture_TexelSize.zw;
    real2 centerOfFetchesInTexelSpace = floor(tentCenterInTexelSpace + 0.5);
    real2 offsetFromTentCenterToCenterOfFetches = tentCenterInTexelSpace - centerOfFetchesInTexelSpace;

    // find the weight of each texel based on the area of a 45 degree slop tent above each of them.
    real3 texelsWeightsU_A, texelsWeightsU_B;
    real3 texelsWeightsV_A, texelsWeightsV_B;
    SampleShadow_GetTexelWeights_Tent_5x5(offsetFromTentCenterToCenterOfFetches.x, texelsWeightsU_A, texelsWeightsU_B);
    SampleShadow_GetTexelWeights_Tent_5x5(offsetFromTentCenterToCenterOfFetches.y, texelsWeightsV_A, texelsWeightsV_B);

    // each fetch will cover a group of 2x2 texels, the weight of each group is the sum of the weights of the texels
    real3 fetchesWeightsU = real3(texelsWeightsU_A.xz, texelsWeightsU_B.y) + real3(texelsWeightsU_A.y, texelsWeightsU_B.xz);
    real3 fetchesWeightsV = real3(texelsWeightsV_A.xz, texelsWeightsV_B.y) + real3(texelsWeightsV_A.y, texelsWeightsV_B.xz);

    // move the PCF bilinear fetches to respect texels weights
    real3 fetchesOffsetsU = real3(texelsWeightsU_A.y, texelsWeightsU_B.xz) / fetchesWeightsU.xyz + real3(-2.5,-0.5,1.5);
    real3 fetchesOffsetsV = real3(texelsWeightsV_A.y, texelsWeightsV_B.xz) / fetchesWeightsV.xyz + real3(-2.5,-0.5,1.5);
    fetchesOffsetsU *= shadowMapTexture_TexelSize.xxx;
    fetchesOffsetsV *= shadowMapTexture_TexelSize.yyy;

    real2 bilinearFetchOrigin = centerOfFetchesInTexelSpace * shadowMapTexture_TexelSize.xy;
    fetchesUV[0] = bilinearFetchOrigin + real2(fetchesOffsetsU.x, fetchesOffsetsV.x);
    fetchesUV[1] = bilinearFetchOrigin + real2(fetchesOffsetsU.y, fetchesOffsetsV.x);
    fetchesUV[2] = bilinearFetchOrigin + real2(fetchesOffsetsU.z, fetchesOffsetsV.x);
    fetchesUV[3] = bilinearFetchOrigin + real2(fetchesOffsetsU.x, fetchesOffsetsV.y);
    fetchesUV[4] = bilinearFetchOrigin + real2(fetchesOffsetsU.y, fetchesOffsetsV.y);
    fetchesUV[5] = bilinearFetchOrigin + real2(fetchesOffsetsU.z, fetchesOffsetsV.y);
    fetchesUV[6] = bilinearFetchOrigin + real2(fetchesOffsetsU.x, fetchesOffsetsV.z);
    fetchesUV[7] = bilinearFetchOrigin + real2(fetchesOffsetsU.y, fetchesOffsetsV.z);
    fetchesUV[8] = bilinearFetchOrigin + real2(fetchesOffsetsU.z, fetchesOffsetsV.z);

    fetchesWeights[0] = fetchesWeightsU.x * fetchesWeightsV.x;
    fetchesWeights[1] = fetchesWeightsU.y * fetchesWeightsV.x;
    fetchesWeights[2] = fetchesWeightsU.z * fetchesWeightsV.x;
    fetchesWeights[3] = fetchesWeightsU.x * fetchesWeightsV.y;
    fetchesWeights[4] = fetchesWeightsU.y * fetchesWeightsV.y;
    fetchesWeights[5] = fetchesWeightsU.z * fetchesWeightsV.y;
    fetchesWeights[6] = fetchesWeightsU.x * fetchesWeightsV.z;
    fetchesWeights[7] = fetchesWeightsU.y * fetchesWeightsV.z;
    fetchesWeights[8] = fetchesWeightsU.z * fetchesWeightsV.z;
}


real SampleShadowmapFiltered(TEXTURE2D_SHADOW_PARAM(ShadowMap, sampler_ShadowMap), float4 shadowCoord, ShadowSamplingData samplingData)
{
    real attenuation;

#if defined(SHADER_API_MOBILE) || defined(SHADER_API_SWITCH)
    // 4-tap hardware comparison
    real4 attenuation4;
    attenuation4.x = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset0.xyz);
    attenuation4.y = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset1.xyz);
    attenuation4.z = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset2.xyz);
    attenuation4.w = SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, shadowCoord.xyz + samplingData.shadowOffset3.xyz);
    attenuation = dot(attenuation4, 0.25);
#else
    float fetchesWeights[9];
    float2 fetchesUV[9];
    SampleShadow_ComputeSamples_Tent_5x5(samplingData.shadowmapSize, shadowCoord.xy, fetchesWeights, fetchesUV);

    attenuation = fetchesWeights[0] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[0].xy, shadowCoord.z));
    attenuation += fetchesWeights[1] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[1].xy, shadowCoord.z));
    attenuation += fetchesWeights[2] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[2].xy, shadowCoord.z));
    attenuation += fetchesWeights[3] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[3].xy, shadowCoord.z));
    attenuation += fetchesWeights[4] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[4].xy, shadowCoord.z));
    attenuation += fetchesWeights[5] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[5].xy, shadowCoord.z));
    attenuation += fetchesWeights[6] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[6].xy, shadowCoord.z));
    attenuation += fetchesWeights[7] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[7].xy, shadowCoord.z));
    attenuation += fetchesWeights[8] * SAMPLE_TEXTURE2D_SHADOW(ShadowMap, sampler_ShadowMap, float3(fetchesUV[8].xy, shadowCoord.z));
#endif

    return attenuation;
}

real SampleShadowmap(TEXTURE2D_SHADOW_PARAM(ShadowMap, sampler_ShadowMap), float4 shadowCoord, ShadowSamplingData samplingData, half4 shadowParams, bool isPerspectiveProjection = true)
{
    // Compiler will optimize this branch away as long as isPerspectiveProjection is known at compile time
    if (isPerspectiveProjection)
        shadowCoord.xyz /= shadowCoord.w;

    real attenuation;
    real shadowStrength = shadowParams.x;

    attenuation = SampleShadowmapFiltered(TEXTURE2D_SHADOW_ARGS(ShadowMap, sampler_ShadowMap), shadowCoord, samplingData);
    attenuation = LerpWhiteTo(attenuation, shadowStrength);

    return BEYOND_SHADOW_FAR(shadowCoord) ? 1.0 : attenuation;
}

half MainLightRealtimeShadow(float4 shadowCoord)
{
    ShadowSamplingData shadowSamplingData = GetMainLightShadowSamplingData();
    half4 shadowParams = _MainLightShadowParams;
    return SampleShadowmap(TEXTURE2D_ARGS(_MainLightShadowmapTexture, sampler_MainLightShadowmapTexture), shadowCoord, shadowSamplingData, shadowParams, false);
}

float4 TransformWorldToShadowCoord(float3 positionWS)
{
    return mul(_MainLightWorldToShadow[0], float4(positionWS, 1.0));
}

struct Light
{
    half3   direction;
    half3   color;
    half    distanceAttenuation;
    half    shadowAttenuation;
};

Light GetMainLight(float4 shadowCoord)
{
    Light light;
    light.direction = _MainLightPosition.xyz;
    // unity_LightData.z is 1 when not culled by the culling mask, otherwise 0.
    light.distanceAttenuation = unity_LightData.z;
    light.shadowAttenuation = MainLightRealtimeShadow(shadowCoord);
    light.color = _MainLightColor.rgb;
    return light;
}

//------------⬆⬆⬆⬆⬆⬆灯光相关的计算⬆⬆⬆⬆⬆⬆-------------

//F(菲涅尔方程Fresnel Rquation): 被反射的光线对比光线被折射的部分所占的比例, 这个比例会随着我们观察角度的不同而不同.在理想的90度视角(和法线的夹角)观察时, 所有的平面理论上都能完全反射光线.
//严格的菲涅尔方程非常复杂, 所以实时渲染时通常使用Fresnel-Schlick近似法求解.
//Fschilick(VdH,F0) = (1-VdH)^5*(1-F0)+F0;其中H仍旧为"中间向量", F0则表示平面的基础反射率, F0是利用所谓的折射指数(Indices of Refraction(IOR))计算得出的.
//注意, 该近似算法仅仅对电介质或者说非金属表面有意义, 对于导体, 无法通过折射指数计算出正确的基础反射率(注:这里中文网站翻译错误, 请前往英文网站).
//此时第一反应就是用另一套公式来计算导体表面的基础反射率. 但这样就无法用同一套公式来描述菲涅尔方程.
//所以最终的方案是所有的F0都不采用IOR计算得出, 而采用实际测量的值视角为0时(和法线的夹角)的值, 然后基于视角的度数来进行插值.
//F0, 视角为0时的基础反射率可以在大型数据库中找到.例如https://refractiveindex.info/
//电介质表面的基础反射率不会超过0.17. 而导体表面的基础反射率则普遍在0.5-1.0之间变化. 而金属的基础反射率会带有色彩. 即金属的基础反射率是Vector3, 该现象只能在金属表面观测到.
//通过预先计算电介质与导体的基础反射率(F0), 我们可以使用Fresnel-Schlick近似来同时描述两者. 但如果是金属表面的话, 则需要对其基础反射添加色彩.
//要实现"添加色彩"的操作, 一般实现为: vec3 F0 = vec3(0.04); F0 = lerp(F0,surfaceColor.rgb,metalness);
//这里的0.04是为了性能考量而将所有的电介质材料的基础反射率统一.
// #define LinearDielectricSpec half3(0.04,0.04,0.04)

#define LinearDielectricSpec half4(0.04, 0.04, 0.04, 1.0 - 0.04)

//根据金属度和固有色计算F0
float3 F0(float4 albedo, float metallic)
{
    return lerp(LinearDielectricSpec.rgb, albedo.rgb, metallic);
}

float3 FresnelSchlick(float VdH, float3 F0)
{
    // return (1.0 - F0) * pow(1.0 - VdH, 5.0) + 0;
    return (1.0 - F0) * pow(1.0 - VdH, 5.0) + F0;
}
//这里可以调用SimplePow来近似或者使用如下模拟函数. (Unity进行了优化, 将v换成了l).
float3 FresnelSchlickSimple(float VdH, float3 F0)
{
    float fre = exp2((-5.55473 * VdH - 6.98316) * VdH);
    return (1.0 - F0) * fre + F0;
}

//得到世界法线方向.
float3 PerPixelWorldNormal(half3 normalTangent,float4 tangentToWorld[3])
{
    half3 tangent = tangentToWorld[0].xyz;
    half3 binormal = tangentToWorld[1].xyz;
    half3 normal = tangentToWorld[2].xyz;

    #if UNITY_TANGENT_ORTHONORMALIZE
    normal = normalize(normal);
    tangent = normalize(tangent-normal*dot(tangent,normal));
    half3 newBN = cross(normal,tangent);
    binormal = newBN*sign(dot(newBN,binormal));
    #endif
    half3 tangentNormal = normalTangent;
    half3x3 TBN = half3x3(tangent, binormal,normal);
    //float3 worldNormal = normalize(mul(TBN, tangentNormal));
    float3 worldNormal = normalize(tangent*tangentNormal.x+binormal*tangentNormal.y+normal*tangentNormal.z);

    return worldNormal;
}

//各项异性GGX
float GGXAnisotropic(float anisotropic, float roughnessSqr, float NdotH, float HdotX, float HdotY)
{
    float aspect = sqrt(1.0h - anisotropic);
    // float roughnessSqr = roughness * roughness;
    float NdotHSqr = NdotH * NdotH;
    float ax = roughnessSqr / aspect;
    float ay = roughnessSqr * aspect;
    float d = HdotX * HdotX / (ax * ax) + HdotY * HdotY / (ay * ay) + NdotHSqr;
    return 1.0h / (PI * ax * ay * d * d);
}

// 光照赋值函数
 Light LightApplied(half3 color, half3 dir)
{
    Light l;
    l.color = color;
    l.direction = dir;
    return l;
}

//切线矩阵组.
half3x3 CreateTangentToWorldPerVertex(half3 normal, half3 tangent, half tangentSign)
{
    half3 binormal = cross(normal,tangent) * tangentSign;
    return half3x3(tangent,binormal,normal);
}

//Safe Dot
inline half DotSafe(half3 a, half3 b)
{
    return max(saturate(dot(a, b)), 0.000001h);
}

inline half DotSafeCullOff(half3 a, half3 b)
{
    return max(abs(dot(a, b)), 0.000001h);
}


float D_GGX_TRSimple(float NdH, float a)
{
    float a2 = a * a;
    NdH = max(NdH,0.0);
    float NdH2 = NdH * NdH;

    float molecular = a2;
    float denominator = NdH2 * (a2-1.0f) + 1.00001f;
    denominator = denominator * denominator;//因为之后会乘以π, 所以这里分母的部分就提前约掉.
    return molecular / denominator;
}

inline float simplePow(float x, float n)
{
    n = n * 1.4427f + 1.4427f; // 1.4427f --> 1/ln(2)
    return exp2(x * n - n);
}

inline half3 FresnelLerpFast (half3 F0, half3 F90, half cosA)
{
    // half t = Pow4 (1 - cosA);
    half t = simplePow((1.0h - cosA),5.0h);
    return lerp (F0, F90, t);
}

//基础光照计算
float3 GetDiffuseTerm(float oneMinesReflectivity, float NdotL, float3 lightColor, float4 Color, float4 albedo)
{
    float3 diff = albedo.rgb * Color.rgb * oneMinesReflectivity;
    return diff * NdotL * lightColor;
}
//SSS相关的计算
float3 GetDiffuseTerm(float oneMinesReflectivity, float3 SSS, float3 lightColor, float4 Color, float4 albedo)
{
    float3 diff = albedo.rgb * Color.rgb * oneMinesReflectivity;
    return diff * SSS * lightColor;
}

float3 GetSpecularTerm(float Roughness, float NdotH, float LdotH, float3 specColor, float3 LightColor)
{
    half Roughness2 = Roughness * Roughness;
    float D = D_GGX_TRSimple(NdotH, Roughness2);
    float FV = 0.25f / (max(0.1f, LdotH * LdotH) * (Roughness + 0.5f));
    float specTerm = D * FV;
    
    return specTerm * LightColor * FresnelSchlick(LdotH, specColor);
}

//环境光部分
float3 GetIBLTerm(float Roughness, float oneMinesReflectivity, float NdotV, float3 specColor, float3 MatCap)
{
    //Gamma空间下的surfaceReduction
    float surfaceReduction = 1.0 - 0.28 * Roughness * Roughness * Roughness;
    half grazingTerm = saturate(2.0h - Roughness - oneMinesReflectivity);
    half3 FresnelLerp = FresnelLerpFast(specColor, grazingTerm, NdotV);
    
    return MatCap * surfaceReduction * FresnelLerp;
}
//普通光照融合
float3 GetPBR(float Roughness, float Metallic, float NdotL, float NdotH, float NdotV, float LdotH, float oneMinesReflectivity, float shadow, float3 MatCap, float3 lightColor, float4 Color, float4 albedo)
{
    float3 specColor = F0(albedo, Metallic);
    float3 diffTerm = GetDiffuseTerm(oneMinesReflectivity, NdotL, lightColor, Color, albedo);
    float3 speTerm = GetSpecularTerm(Roughness, NdotH, LdotH, specColor, lightColor) * specColor * NdotL;
    float3 IBL = GetIBLTerm(Roughness, oneMinesReflectivity, NdotV, specColor, MatCap);

    // return shadow;
    return (diffTerm + speTerm + IBL) * shadow;
}
//SSS光照融合
float3 GetPBR(float Roughness, float Metallic, float3 SSS, float NdotH, float NdotV, float LdotH, float oneMinesReflectivity, float shadow, float3 MatCap, float3 lightColor, float4 Color, float4 albedo)
{
    float3 specColor = F0(albedo, Metallic);
    float3 diffTerm = GetDiffuseTerm(oneMinesReflectivity, SSS, lightColor, Color, albedo);
    float3 speTerm = GetSpecularTerm(Roughness, NdotH, LdotH, specColor, lightColor) * specColor * SSS;
    float3 IBL = GetIBLTerm(Roughness, oneMinesReflectivity, NdotV, specColor, MatCap);

    // return shadow;
    return (diffTerm + speTerm + IBL) * shadow;
}

#endif