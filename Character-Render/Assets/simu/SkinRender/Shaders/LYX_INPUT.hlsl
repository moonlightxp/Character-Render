#ifndef URP_SHADER_INCLUDE_LYX_INPUT
#define URP_SHADER_INCLUDE_LYX_INPUT

// 物体相关数据,只计算一次
struct ObjData
{
    float4 albedo; // 表面颜色

    float metallic; // 金属度
    
    float smoothness; // 光滑度
    float realRoughness; // 光滑度
    float roughness; // 粗糙度平方
    float roughness2; // 粗糙度 4 次方

    float AO; // 金属度

    float3 emission; // 自发光

    //------------------------------------
    float3 vertexNormalWS; // 顶点法线 (没有归一化)

    float3 positionWS; // 世界空间位置
    float4 positionCS; // 裁剪空间位置
    
    float3 normalWS; // 世界空间法线
    float3x3 tangentToWorldMatrix; // TBN
    
    float4 shadowCoord; // 阴影
    
    //------------------------------------
    float3 viewDirWS; // 视线角度
    float nv; // normal dot viewDir
    float3 f0; // 反射率
    float3 reflectDir; // 反射向量
};

// 灯光相关数据,每盏灯不同
struct LitData
{
    float3 halfDirWS;
    float nl;
    float remapNl;
    float lh;
    float nh;
    float nh2;
    float vh;

    float3 color;
    float3 dir;
};

// BRDF 数据
struct LitResultData
{
    float3 DirectDiffuse;
    float3 DirectSpecular;
    float3 InDirectDiffuse;
    float3 InDirectSpecular;
};

void SetObjData(Varyings input, float4 source, out ObjData objData)
{
    objData.albedo = source;

    objData.metallic = _Metallic * _MetallicTex.Sample(sampler_Linear_Clamp, input.uv.xy).r;
    objData.smoothness = _Smoothness * _SmoothnessTex.Sample(sampler_Linear_Clamp, input.uv.xy).r;
    
    objData.realRoughness = 1 - objData.smoothness;
    objData.roughness = max(objData.realRoughness * objData.realRoughness, HALF_MIN_SQRT);
    objData.roughness2 = max(objData.roughness * objData.roughness, HALF_MIN);

    objData.AO = _AOTex.Sample(sampler_Linear_Clamp, input.uv.xy).r * (1 - _AO) + _AO;

    float4 _bumpMap = _BumpMap.Sample(sampler_Linear_Repeat, input.uv.zw);
    _bumpMap.rgb = UnpackNormalScale(_bumpMap, _BumpScale);
    objData.vertexNormalWS = input.normalWS;
    objData.tangentToWorldMatrix = float3x3(input.tangentWS.xyz, input.bitangentWS, input.normalWS);
    objData.normalWS = normalize(mul(_bumpMap.rgb,  objData.tangentToWorldMatrix));

    objData.emission = 1;

    //-------------------------------------------------------------------------------------
    objData.positionCS = input.positionCS;
    objData.positionWS = input.positionWS;
    
    objData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);

    //-------------------------------------------------------------------------------------
    objData.viewDirWS = normalize(_WorldSpaceCameraPos.xyz - input.positionWS.xyz);
    objData.nv = ClampDot(objData.normalWS, objData.viewDirWS);
    objData.f0 = lerp(0.04, objData.albedo.rgb, objData.metallic);
    objData.reflectDir = reflect(-objData.viewDirWS, objData.normalWS);
}

void SetLitData(ObjData objData, Light light, out LitData litData)
{
    litData.halfDirWS = normalize(light.direction + objData.viewDirWS);
    litData.nl = ClampDot(objData.normalWS, light.direction);
    litData.remapNl = litData.nl * _HalfLambert + 1 - _HalfLambert;
    litData.lh = ClampDot(light.direction, litData.halfDirWS);
    litData.nh = ClampDot(objData.normalWS, litData.halfDirWS);
    litData.nh2 = P2(litData.nh);
    litData.vh = ClampDot(objData.viewDirWS, litData.halfDirWS);

    litData.color = light.color * light.distanceAttenuation * (1 - litData.nl * (1 - light.shadowAttenuation));
    litData.dir = light.direction;
}

#endif
