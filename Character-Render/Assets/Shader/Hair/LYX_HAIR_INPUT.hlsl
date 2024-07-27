#ifndef URP_SHADER_INCLUDE_LYX_HAIR_INPUT
#define URP_SHADER_INCLUDE_LYX_HAIR_INPUT

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// 物体相关数据,只计算一次
struct ObjData
{
    float4 albedo; // 表面颜色
    float specularMask; // 表面颜色
    float face;

    float3 AO; // AO
    
    //------------------------------------------------------------------------------------
    float3 vertexNormalWS; // 顶点法线 (没有归一化)
    float3 positionWS; // 世界空间位置
    float4 positionCS; // 裁剪空间位置
    float3 normalWS; // 世界空间法线
    float3 tangentWS; // 世界空间法线
    float3 bTangentWS; // 世界空间法线
    float3 bTangentWS1; // 世界空间法线
    float3 bTangentWS2; // 世界空间法线
    float3x3 tangentToWorldMatrix; // TBN
    float4 shadowCoord; // 阴影

    //------------------------------------------------------------------------------------
    float3 viewDirWS; // 视线角度
    float nv; // normal dot viewDir
};

// 灯光相关数据,每盏灯不同
struct LitData
{
    float3 halfDirWS;
    // float3 halfDirNoNormalizeWS;
    
    float nl;
    float remapNl;
    float vh;
    
    float nh;
    float th;
    float bh1;
    float bh2;

    float3 color;
    float3 diffuseColor;
    float3 specularColor1;
    float3 specularColor2;
    
    float3 dir;
    float shadowAtten;
};

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

void SetObjData(Varyings input, float4 source, float face, out ObjData objData)
{
    objData.albedo.rgb = source.r * _Color;
    objData.albedo.a = source.a;
    objData.AO = source.g;
    objData.AO = Max1(objData.AO + 1 - _AOColor.a); // _AOColor.a 控制 AO 强度
    objData.AO += (1 - objData.AO) * _AOColor.rgb; // 只改变黑色部分颜色
    objData.specularMask = source.b;
    
    objData.face = face;
    
    float4 _bumpMap = _BumpMap.Sample(sampler_Linear_Repeat, input.uv.xy);
    // _bumpMap.rgb = UnpackNormalScale(_bumpMap, _BumpScale);
    _bumpMap.rgb = UnpackNormalRG(_bumpMap, _BumpScale);
    objData.vertexNormalWS = input.normalWS;
    objData.tangentWS = input.tangentWS;
    objData.bTangentWS = input.bitangentWS;

    half offsetMask = _AnisoShiftMask.Sample(sampler_Linear_Repeat, input.uv.zw).r;
    objData.bTangentWS1 = input.bitangentWS + input.normalWS * (_Offset1 + offsetMask);
    objData.bTangentWS2 = input.bitangentWS + input.normalWS * (_Offset2 + offsetMask);
    
    objData.tangentToWorldMatrix = float3x3(input.tangentWS.xyz, input.bitangentWS, face > 0 ? input.normalWS : -input.normalWS);
    objData.normalWS = normalize(mul(_bumpMap.rgb, objData.tangentToWorldMatrix));
    
    //------------------------------------------------------------------------------------
    objData.positionCS = input.positionCS;
    objData.positionWS = input.positionWS;
    
    objData.shadowCoord = TransformWorldToShadowCoord(input.positionWS);

    //------------------------------------------------------------------------------------
    objData.viewDirWS = normalize(_WorldSpaceCameraPos.xyz - input.positionWS.xyz);
    objData.nv = ClampDot(objData.normalWS, objData.viewDirWS);
}

void SetLitData(ObjData objData, Light light, out LitData litData)
{
    litData.dir = light.direction;
    
    litData.halfDirWS = normalize(litData.dir + objData.viewDirWS);
    litData.nl = ClampDot(objData.normalWS, litData.dir);
    litData.remapNl = litData.nl * _HalfLambert + 1 - _HalfLambert;
    
    litData.vh = ClampDot(objData.viewDirWS, litData.halfDirWS);
    litData.nh = ClampDot(objData.normalWS, litData.halfDirWS);
    litData.th = dot(objData.tangentWS, litData.halfDirWS);
    litData.bh1 = dot(objData.bTangentWS1, litData.halfDirWS);
    litData.bh2 = dot(objData.bTangentWS2, litData.halfDirWS);
    
    litData.color = light.color * light.distanceAttenuation;
    litData.diffuseColor = litData.color;
    #if _SPECULAR_COLOR_TYPE_LIGHT
        litData.specularColor1 = litData.color;
        litData.specularColor2 = litData.color;
    #elif _SPECULAR_COLOR_TYPE_CUSTOM
        litData.specularColor1 = _SpecularColor.rgb;
        litData.specularColor2 = _SpecularColor.rgb;
    #elif _SPECULAR_COLOR_TYPE_MIX
        litData.specularColor1 = litData.color * _SpecularColor1.rgb;
        litData.specularColor2 = litData.color * _SpecularColor2.rgb;
    #endif
    litData.shadowAtten = 1 - litData.nl * (1 - light.shadowAttenuation);
}

#endif
