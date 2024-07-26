#ifndef URP_SHADER_INCLUDE_LYX_HAIR_INPUT
#define URP_SHADER_INCLUDE_LYX_HAIR_INPUT

struct Attributes
{
    float4 positionOS : POSITION;
    float2 uv : TEXCOORD0;
    float3 normalOS : NORMAL;
    float4 tangentOS : TANGENT;
};

struct Varyings
{
    float4 positionCS : SV_POSITION;
    float3 positionWS : TEXCOORD1;

    float3 normalWS : TEXCOORD2;
    float4 tangentWS : TEXCOORD3;
    float3 bitangentWS : TEXCOORD4;
    float3 bitangentWS2 : TEXCOORD5;

    float2 uv : TEXCOORD0;
    float fogCoord : TEXCOORD6;
};

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

// 物体相关数据,只计算一次
struct ObjData
{
    float4 albedo; // 表面颜色

    float smoothness; // 光滑度
    float roughness; // 粗糙度平方

    float3 AO; // AO

    float thickness; // 厚度
    
    //------------------------------------------------------------------------------------
    float3 vertexNormalWS; // 顶点法线 (没有归一化)
    float3 positionWS; // 世界空间位置
    float4 positionCS; // 裁剪空间位置
    float3 normalWS; // 世界空间法线
    float3 tangentWS; // 世界空间法线
    float3 bTangentWS; // 世界空间法线
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
    float3 halfDirNoNormalizeWS;
    float nl;
    float remapNl;
    float nh;
    float vh;

    float th;
    float bh;

    float3 color;
    float3 diffuseColor;
    float3 specularColor;
    float3 dir;

    float shadowAtten;
};

/*----------------------------------------------------------------------------------------------------------------------------------------------------------------*/

void SetObjData(Varyings input, float4 source, out ObjData objData)
{
    objData.albedo = source;

    objData.smoothness = _Smoothness * _SmoothnessTex.Sample(sampler_Linear_Clamp, input.uv.xy).r;
    objData.roughness = max(P2(1 - objData.smoothness), HALF_MIN_SQRT);
    
    objData.AO = _AOTex.Sample(sampler_Linear_Clamp, input.uv.xy).r;
    objData.AO = Max1(objData.AO + 1 - _AOColor.a);
    objData.AO += (1 - objData.AO) * _AOColor.rgb;

    float4 _bumpMap = _BumpMap.Sample(sampler_Linear_Repeat, input.uv);
    _bumpMap.rgb = UnpackNormalScale(_bumpMap, _BumpScale);
    objData.vertexNormalWS = input.normalWS;
    objData.tangentToWorldMatrix = float3x3(input.tangentWS.xyz, input.bitangentWS, input.normalWS);

    objData.normalWS = normalize(mul(_bumpMap.rgb,  objData.tangentToWorldMatrix));
    objData.tangentWS = input.tangentWS;
    objData.bTangentWS = input.bitangentWS2;

    objData.thickness = _ThicknessTex.Sample(sampler_Linear_Clamp, input.uv.xy).r * _Thickness;

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

    litData.halfDirNoNormalizeWS = litData.dir + objData.viewDirWS;
    litData.halfDirWS = normalize(litData.dir + objData.viewDirWS);
    litData.nl = ClampDot(objData.normalWS, litData.dir);
    litData.remapNl = litData.nl * _HalfLambert + 1 - _HalfLambert;
    
    litData.nh = ClampDot(objData.normalWS, litData.halfDirWS);
    litData.vh = ClampDot(objData.viewDirWS, litData.halfDirWS);

    litData.th = dot(objData.tangentWS, litData.halfDirWS);
    litData.bh = dot(objData.bTangentWS, litData.halfDirWS);
    
    litData.color = light.color * light.distanceAttenuation;
    litData.diffuseColor = litData.color;
    #if _SPECULAR_COLOR_TYPE_LIGHT
        litData.specularColor = litData.color;
    #elif _SPECULAR_COLOR_TYPE_CUSTOM
        litData.specularColor = _SpecularColor.rgb;
    #elif _SPECULAR_COLOR_TYPE_MIX
        litData.specularColor = litData.color * _SpecularColor.rgb;
    #endif
    litData.shadowAtten = 1 - litData.nl * (1 - light.shadowAttenuation);
}

#endif
