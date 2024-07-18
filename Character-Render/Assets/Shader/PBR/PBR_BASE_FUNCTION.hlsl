#ifndef URP_SHADER_INCLUDE_PBR_BASE_FUNCTION
#define URP_SHADER_INCLUDE_PBR_BASE_FUNCTION

half3 UnpackNormalRG(half4 packedNormal, half scale = 1.0)
{
    half3 normal;
    normal.xy = packedNormal.rg * 2.0 - 1.0;
    normal.z = max(1.0e-16, sqrt(1.0 - saturate(dot(normal.xy, normal.xy))));
    normal.xy *= scale;
    return normal;
}

Varings vert (Attributes input)
{
    Varings output;
    output.uv = input.uv;
    output.positionCS = TransformObjectToHClip(input.positionOS.xyz);
    output.positionWS = TransformObjectToWorld(input.positionOS.xyz);
    output.normalWS = TransformObjectToWorldNormal(input.normalOS);
    output.tangentWS.xyz = normalize(TransformObjectToWorldDir(input.tangentOS.xyz));
    output.tangentWS.w = input.tangentOS.w * GetOddNegativeScale();
    // output.bitangentWS = GetBitangentWS(output.normalWS, output.tangentWS);
    output.bitangentWS = cross(output.normalWS, output.tangentWS.xyz) * output.tangentWS.w;
    
    return output;
}

half4 frag (Varings input) : SV_Target
{
    float3x3 TBN = float3x3(input.tangentWS.xyz, input.bitangentWS, input.normalWS);
    float3 viewDirWS = normalize(_WorldSpaceCameraPos - input.positionWS);
    
    //------------光照阴影------------
    #ifdef MAIN_LIGHT_CALCULATE_SHADOWS
        float4 shadowCoord = TransformWorldToShadowCoord(input.positionWS);  //获取阴影坐标
    #else
        float4 shadowCoord = float4(0, 0, 0, 0);
    #endif
    Light mainLight = GetMainLight(shadowCoord);//获取主光源信息
    Light light = LightApplied(_LightColor0.rgb, normalize(_CustomLightDir1.xyz));//自定义光源
    float shadowAtten = mainLight.shadowAttenuation * mainLight.distanceAttenuation;//光影相关

    //------------贴图的采样------------
    half4 GMA = SAMPLE_TEXTURE2D(_GMAMap, sampler_MainTex, input.uv);
    half3 SLD = SAMPLE_TEXTURE2D(_SLDMap, sampler_MainTex, input.uv).rgb;
    half4 albedo = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, input.uv);
    // albedo = half4(GammaToLinearSpace(albedo.rgb), albedo.a);
    half3 Emission_Var = SAMPLE_TEXTURE2D(_EmissionMap, sampler_MainTex, input.uv).rgb * _EmissionColor.rgb;
    // float3 worldNormal = GetNormalFromNormalTexture(_BumpMap, sampler_MainTex, input.uv, _BumpScale, TBN);
    float4 normalTexture = SAMPLE_TEXTURE2D(_BumpMap, sampler_MainTex, input.uv);
    // normalTexture.rgb = UnpackNormalScale(normalTexture, _BumpScale);
    normalTexture.rgb = UnpackNormalRG(normalTexture, _BumpScale);
    float3 worldNormal = normalize(mul(normalTexture.xyz, TBN));

    //------------粗糙度, 金属度, SSS厚度, 的计算和控制------------
    half Roughness = 1.0h - GMA.r * _Smoothness;
    half Metallic = GMA.g * _Metallic;

    //------------常用属性的计算------------
    float3 worldHalfDir = normalize(mainLight.direction + viewDirWS);
    #if defined(_CULLOFF_ON) 
        half NdotV = DotSafeCullOff(worldNormal, viewDirWS);
    #else
        half NdotV = DotSafe(worldNormal,viewDirWS);
    #endif
    half NdotH = DotSafe(worldNormal,worldHalfDir);
    half LdotH = DotSafe(mainLight.direction,worldHalfDir);
    // half NdotL = DotSafe(worldNormal,mainLight.direction);
    half NdotL = dot(worldNormal,mainLight.direction);
    half halfLambert = NdotL * _Hardness + (1.0 - _Hardness);
    // shadowAtten *= NdotL;
    
    //------------一个控制AO和辅光在AO中强度的参数------------
    half2 AO_col = half2(1.0, 1.0) - half2(_AOStrength, _BrightnessInOcclusion);
    AO_col = half2(_AOStrength * GMA.b, _BrightnessInOcclusion * SLD.g) + AO_col;
    half3 FinalAmbientCol = AO_col.x * _AmbientColor.rgb;

    //------------PBR计算------------
    #if defined(_LIGHTMODE_ON)
    half oneMinesReflectivity = LinearDielectricSpec.a;
    #else
    half oneMinesReflectivity = LinearDielectricSpec.a * (1.0h - Metallic);
    #endif

    half Roughness2 = Roughness * Roughness;
    float3 specColor = F0(albedo, Metallic);
    float3 diff = albedo.rgb * _Color.rgb * oneMinesReflectivity;
    float D = D_GGX_TRSimple(NdotH, Roughness2);
    float FV = 0.25f / (max(0.1f, LdotH * LdotH) * (Roughness + 0.5f));
    float specTerm = D * FV;
    //这部分等同于gi.indirect.specular.仿照unity的IBL部分.
    half surfaceReduction = 0.6h - 0.08h * Roughness;
    // surfaceReduction = 1.0h-pow(r,3.0h)*surfaceReduction;
    surfaceReduction = 1.0h - Roughness * Roughness * Roughness * surfaceReduction;
    half grazingTerm = saturate(2.0h - Roughness - oneMinesReflectivity);
    half3 FresnelLerp = FresnelLerpFast(specColor, grazingTerm, NdotV);

    //------------MatCap计算------------
    half lod = (-Roughness * 4.1999998 + 10.2) * Roughness;//MatCap贴图采样的lod计算
    float3 normalVS = TransformWorldToViewNormal(worldNormal);
    // float2 MatCapUV = GetBaseMatCapUV(normalVS);
    float2 MatCapUV = normalVS.xy * 0.5 + 0.5;
    float3 MatCap = SAMPLE_TEXTURE2D_LOD(_MatCapTex, sampler_LinearClamp, MatCapUV, lod).rgb;
    MatCap *= _MatCapColor.rgb;//MatCap颜色倾向
    // MatCap = GammaToLinearSpace(MatCap);
    MatCap *= AO_col.x;//AO控制MatCap强度
    
    //------------SSS部分的计算------------
    #ifdef _SSS_ON
    float3 SSS;
    SSS = LUT_SSS_GammaToLinear(_SSSMap, sampler_LinearClamp, SSS, NdotL, SLD.r, _SubSurface, shadowAtten);
    #endif

    //------------丝袜颜色计算------------
    #ifdef _DENIER_ON
    diff = DENIER_GammaToLinear(diff, _SkinColor, _StockingColor, NdotV, _Denier, _RimPower, SLD.b, oneMinesReflectivity);
    #endif
    
    //------------LOL各向异性高光，使用贴图控制高光方向------------
    #if defined (_ANISOTROPIC_ON) && !defined(_UVANISOTROPIC_ON)
        diff = AnisotropyByTex(_TangentNormalMap, _HairDataMap, sampler_LinearClamp, worldNormal, worldHalfDir, diff,
            _PrimarySpecularColor, _SecondarySpecularColor, input.uv, _PrimarySpecularShift, _SecondarySpecularShift, _PrimarySpecularExponent, _SecondarySpecularExponent, halfLambert, shadowAtten);
        specTerm = 0.0;
    #endif

    //------------LOL各向异性高光，使用UV控制控制高光方向------------
    #if defined (_UVANISOTROPIC_ON) && !defined(_ANISOTROPIC_ON)
        diff = AnisotropyByUV(_HairDataMap, sampler_LinearClamp, input.bitangentWS.xyz, worldNormal, worldHalfDir, diff,
            _PrimarySpecularColor, _SecondarySpecularColor, input.uv, _PrimarySpecularShift, _SecondarySpecularShift, _PrimarySpecularExponent, _SecondarySpecularExponent, halfLambert, shadowAtten);
        specTerm = 0.0;
    #endif

    //------------镭射效果------------
    #ifdef _LASER_ON
        diff = LUT_Laser_GammaToLinear(_LaserMap, sampler_LinearClamp, diff, NdotV, _LaserIntensity);
    #endif
    
    //------------混合计算------------
    #ifdef _SSS_ON
        float3 finalColor = (MatCap * surfaceReduction * FresnelLerp) + (diff + specTerm * specColor) * SSS * mainLight.color + (diff * FinalAmbientCol);
        //float3 finalColor = GetPBR(Roughness, Metallic, SSS, NdotH, NdotV, LdotH, oneMinesReflectivity, shadowAtten, MatCap, mainLight.color, _Color, albedo);
    #else
        float3 finalColor = (MatCap * surfaceReduction * FresnelLerp) + (diff + specTerm * specColor) * halfLambert * mainLight.color * shadowAtten + (diff * FinalAmbientCol);
        //float3 finalColor =  GetPBR(Roughness, Metallic, halfLambert, NdotH, NdotV, LdotH, oneMinesReflectivity, shadowAtten, MatCap, mainLight.color, _Color, albedo);
    #endif

    // finalColor = shadowAtten;
    //------------添加自发光------------
    half3 finalBRDF = finalColor + Emission_Var;

    //------------颜色处理------------
	finalBRDF *= _Brightness;
	half luminance = 0.2125 * finalBRDF.r + 0.7154 * finalBRDF.g + 0.0721 * finalBRDF.b;
	half3 luminanceColor = half3(luminance, luminance, luminance);
	finalBRDF = lerp(luminanceColor, finalBRDF, _Saturation);
    // finalBRDF = LinearToGammaSpace(finalBRDF);

    //------------侧光计算------------
    float RakingSoft = max(_CustomLightDir2Softness, 1.0);
    float pow = log2(1 - NdotV);
    pow = exp2(pow * RakingSoft);
    float shadow = _BrightnessInShadow * (1 - shadowAtten);//辅光在阴影区域内的强度
    shadow *= AO_col.y;
    float3 Raking = pow * _CustomLightDir2Color.rgb * shadow;
    half3 CustomLightDir2 = normalize(_CustomLightDir2.xyz);
    half CustomNdotL = DotSafe(worldNormal, CustomLightDir2);
    half3 CustomLight = Raking * CustomNdotL;
    finalBRDF += CustomLight;
	finalBRDF = saturate(finalBRDF);

    //------------透明计算------------
    #if defined(_ALPHABLEND_ON) || defined(_ALPHATEST_ON)
        half alpha = albedo.a * _Color.a;
    #else
        half alpha = 1.0h;
    #endif
    
    #ifdef _ALPHATEST_ON
        clip(alpha - _Cutoff);
    #endif

    half4 col = half4(finalBRDF, albedo.a);
    return col;
}

#endif

